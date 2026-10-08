import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models.dart';

class DownloadProgress {
  final String songId;
  final double fraction;
  final bool done;
  final String? error;

  const DownloadProgress({
    required this.songId,
    required this.fraction,
    this.done = false,
    this.error,
  });
}

class DownloadService extends ChangeNotifier {
  static const _boxName = 'downloads';

  late final Box _box;
  late final String _dir;
  final Map<String, StreamController<DownloadProgress>> _controllers = {};

  static Future<DownloadService> init() async {
    final box = await Hive.openBox(_boxName);
    if (kIsWeb) {
      return DownloadService._(box, '');
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${dir.path}/audio');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      return DownloadService._(box, downloadsDir.path);
    } catch (_) {
      return DownloadService._(box, '');
    }
  }

  DownloadService._(this._box, this._dir);

  String _filePath(String songId) => '$_dir/$songId.mp3';

  bool isDownloaded(String songId) => _box.containsKey(songId);

  Set<String> get downloadedIds => _box.keys.cast<String>().toSet();

  List<Song> get downloadedSongs => _box.values
      .map(
        (v) => Song.fromJson(
          (jsonDecode(v as String) as Map).cast<String, dynamic>(),
        ),
      )
      .toList();

  String? localPath(String songId) {
    if (!isDownloaded(songId)) return null;
    final path = _filePath(songId);
    return _dir.isNotEmpty && File(path).existsSync() ? path : null;
  }

  Stream<DownloadProgress>? downloadStream(String songId) =>
      _controllers[songId]?.stream;

  Stream<DownloadProgress> download(Song song) {
    if (_controllers.containsKey(song.id)) {
      return _controllers[song.id]!.stream;
    }

    final ctrl = StreamController<DownloadProgress>.broadcast();
    _controllers[song.id] = ctrl;

    if (kIsWeb || _dir.isEmpty) {
      scheduleMicrotask(() async {
        ctrl.add(
          DownloadProgress(
            songId: song.id,
            fraction: 0,
            done: true,
            error: 'Downloads are not available on this platform.',
          ),
        );
        await ctrl.close();
        _controllers.remove(song.id);
      });
      return ctrl.stream;
    }

    _doDownload(song, ctrl);

    return ctrl.stream;
  }

  Future<void> _doDownload(
    Song song,
    StreamController<DownloadProgress> ctrl,
  ) async {
    http.Client? client;
    try {
      final path = _filePath(song.id);
      client = http.Client();
      final req = await client.send(
        http.Request('GET', Uri.parse(song.streamUrl)),
      );
      if (req.statusCode < 200 || req.statusCode >= 300) {
        throw HttpException('Download failed (${req.statusCode})');
      }
      final total = req.contentLength ?? -1;
      final file = File(path);
      final sink = file.openWrite();
      var received = 0;

      await for (final chunk in req.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          ctrl.add(
            DownloadProgress(songId: song.id, fraction: received / total),
          );
        }
      }
      await sink.close();

      await _box.put(song.id, jsonEncode(song.raw));
      ctrl.add(DownloadProgress(songId: song.id, fraction: 1.0, done: true));
      notifyListeners();
    } catch (e) {
      ctrl.add(
        DownloadProgress(
          songId: song.id,
          fraction: 0,
          done: true,
          error: e.toString(),
        ),
      );
    } finally {
      client?.close();
      await ctrl.close();
      _controllers.remove(song.id);
    }
  }

  Future<void> deleteDownload(String songId) async {
    _controllers[songId]?.close();
    _controllers.remove(songId);
    final file = File(_filePath(songId));
    if (await file.exists()) await file.delete();
    await _box.delete(songId);
    notifyListeners();
  }

  @override
  void dispose() {
    for (final ctrl in _controllers.values) {
      ctrl.close();
    }
    _box.close();
    super.dispose();
  }
}
