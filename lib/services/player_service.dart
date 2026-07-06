import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models.dart';

/// Owns the [AudioPlayer] and the play queue.
///
/// just_audio_background picks up the [MediaItem] tags attached to each
/// source and renders the system media notification / lock-screen controls.
class PlayerService extends ChangeNotifier {
  final AudioPlayer player = AudioPlayer();

  List<Song> _queue = [];
  List<Song> get queue => List.unmodifiable(_queue);

  Song? get current {
    final i = player.currentIndex;
    if (i == null || i < 0 || i >= _queue.length) return null;
    return _queue[i];
  }

  PlayerService() {
    player.currentIndexStream.listen((_) => notifyListeners());
    player.playbackEventStream.listen(
      (_) {},
      onError: (Object e, StackTrace st) {
        debugPrint('Playback error: $e');
      },
    );
  }

  AudioSource _source(Song s) => AudioSource.uri(
        Uri.parse(s.streamUrl),
        tag: MediaItem(
          id: s.id,
          title: s.title,
          artist: s.artists,
          album: s.albumName,
          duration: Duration(seconds: s.durationSeconds),
          artUri: s.imageUrl.isEmpty ? null : Uri.parse(s.imageUrl),
        ),
      );

  /// Replaces the queue with [songs] and starts playing at [startIndex].
  Future<void> playAll(List<Song> songs, {int startIndex = 0}) async {
    final playable = songs.where((s) => s.playable).toList();
    if (playable.isEmpty) return;
    // Recompute the start index against the filtered list.
    var index = 0;
    if (startIndex >= 0 && startIndex < songs.length) {
      final target = songs[startIndex];
      index = playable.indexWhere((s) => s.id == target.id);
      if (index < 0) index = 0;
    }
    _queue = playable;
    notifyListeners();
    await player.setAudioSources(
      playable.map(_source).toList(),
      initialIndex: index,
    );
    player.play();
  }

  Future<void> playSong(Song song) => playAll([song]);

  Future<void> playNext(Song song) async {
    if (_queue.isEmpty) return playAll([song]);
    final at = (player.currentIndex ?? 0) + 1;
    _queue.insert(at, song);
    await player.insertAudioSource(at, _source(song));
    notifyListeners();
  }

  Future<void> addToQueue(Song song) async {
    if (_queue.isEmpty) return playAll([song]);
    _queue.add(song);
    await player.addAudioSource(_source(song));
    notifyListeners();
  }

  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _queue.removeAt(index);
    await player.removeAudioSourceAt(index);
    notifyListeners();
  }

  Future<void> skipTo(int index) async {
    await player.seek(Duration.zero, index: index);
    player.play();
  }

  void togglePlay() => player.playing ? player.pause() : player.play();

  Future<void> next() => player.seekToNext();

  Future<void> previous() async {
    if (player.position.inSeconds > 3 || !player.hasPrevious) {
      await player.seek(Duration.zero);
    } else {
      await player.seekToPrevious();
    }
  }

  Future<void> toggleShuffle() async {
    final enable = !player.shuffleModeEnabled;
    if (enable) await player.shuffle();
    await player.setShuffleModeEnabled(enable);
    notifyListeners();
  }

  Future<void> cycleRepeat() async {
    const order = [LoopMode.off, LoopMode.all, LoopMode.one];
    final next = order[(order.indexOf(player.loopMode) + 1) % order.length];
    await player.setLoopMode(next);
    notifyListeners();
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }
}
