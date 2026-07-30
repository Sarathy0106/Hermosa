import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models.dart';
import 'player_service.dart';

class RoomMember {
  final String id;
  RoomMember({required this.id});
}

enum RoomConnectionState { disconnected, connecting, connected, error }

class RoomService extends ChangeNotifier {
  static const _boxName = 'room_prefs';
  static const _serverUrlKey = 'server_url';
  static const defaultServerUrl = 'wss://hermosa-om9v.onrender.com';

  final PlayerService _player;
  late final Box _prefs;

  WebSocketChannel? _channel;
  String? _memberId;
  String? _roomCode;
  List<RoomMember> _members = [];
  RoomConnectionState _state = RoomConnectionState.disconnected;
  String? _error;
  StreamSubscription? _sub;

  Timer? _positionTimer;
  StreamSubscription? _playerSub;

  RoomService(this._player) : _prefs = Hive.box(_boxName) {
    _playerSub = _player.player.currentIndexStream.listen((_) {
      if (inRoom && isHost) {
        final song = _player.current;
        syncState(
          song,
          _player.queue,
          _player.player.currentIndex ?? 0,
          _player.player.playing,
        );
      }
    });
  }

  RoomConnectionState get state => _state;
  String? get roomCode => _roomCode;
  String? get memberId => _memberId;
  List<RoomMember> get members => _members;
  bool get isHost => _memberId != null && _members.isNotEmpty && _memberId == _members.first.id;
  bool get inRoom => _state == RoomConnectionState.connected && _roomCode != null;
  String? get error => _error;

  String get serverUrl =>
      _prefs.get(_serverUrlKey, defaultValue: defaultServerUrl) as String;

  Future<void> setServer(String url) async {
    await _prefs.put(_serverUrlKey, url);
    notifyListeners();
  }

  Future<void> connect([String? url]) async {
    _cleanup();
    final serverUrl = url ?? this.serverUrl;
    _setState(RoomConnectionState.connecting);
    _error = null;

    try {
      final uri = Uri.parse(serverUrl);
      if (uri.scheme != 'ws' && uri.scheme != 'wss') {
        throw Exception('Invalid URL scheme "${uri.scheme}". Use ws:// or wss://');
      }
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready.timeout(const Duration(seconds: 10));

      _sub = _channel!.stream.listen(
        _onMessage,
        onError: (Object e) {
          _error = e.toString();
          _setState(RoomConnectionState.error);
        },
        onDone: () {
          _cleanup();
          _setState(RoomConnectionState.disconnected);
        },
      );

      _setState(RoomConnectionState.connected);
    } on TimeoutException {
      _cleanup();
      _error = 'Connection timed out. Check the server URL and try again.';
      _setState(RoomConnectionState.error);
    } catch (e) {
      _cleanup();
      _error = e.toString();
      _setState(RoomConnectionState.error);
    }
  }

  void _send(Map<String, dynamic> msg) {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode(msg));
  }

  void _onMessage(dynamic raw) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    switch (msg['type'] as String?) {
      case 'room_created':
        _memberId = msg['memberId'] as String;
        _roomCode = msg['code'] as String;
        _members = [RoomMember(id: _memberId!)];
        _startPositionSync();
        _setState(RoomConnectionState.connected);
        break;

      case 'room_joined':
        _memberId = msg['memberId'] as String;
        _roomCode = msg['code'] as String;
        _members = (msg['members'] as List)
            .map((m) => RoomMember(id: (m as Map)['id'] as String))
            .toList();
        _startPositionSync();
        _setState(RoomConnectionState.connected);
        break;

      case 'member_joined':
        _members = (msg['members'] as List)
            .map((m) => RoomMember(id: (m as Map)['id'] as String))
            .toList();
        notifyListeners();
        break;

      case 'member_left':
        _members = (msg['members'] as List)
            .map((m) => RoomMember(id: (m as Map)['id'] as String))
            .toList();
        notifyListeners();
        break;

      case 'room_left':
        _cleanup();
        _setState(RoomConnectionState.disconnected);
        break;

      case 'state_update':
        _applySyncState(msg['state'] as Map<String, dynamic>?);
        break;

      case 'position_update':
        _applySyncPosition(
          msg['positionMs'] as num,
          msg['playing'] as bool,
        );
        break;

      case 'error':
        _error = msg['message'] as String?;
        notifyListeners();
        break;
    }
  }

  void createRoom() {
    _send({'type': 'create_room'});
  }

  void joinRoom(String code) {
    _send({'type': 'join_room', 'code': code.toUpperCase()});
  }

  void leaveRoom() {
    _positionTimer?.cancel();
    _send({'type': 'leave_room'});
  }

  /// Called by the host when the current song or queue changes.
  void syncState(Song? song, List<Song> queue, int currentIndex, bool playing) {
    if (!inRoom || !isHost) return;
    _send({
      'type': 'sync_state',
      'state': {
        if (song != null) ...{
          'song': song.raw,
          'queue': queue.map((s) => s.raw).toList(),
          'currentIndex': currentIndex,
          'playing': playing,
        },
      },
    });
  }

  /// Called periodically (or on seek) by the host to sync playback position.
  void syncPosition(int positionMs, bool playing) {
    if (!inRoom || !isHost) return;
    _send({
      'type': 'sync_position',
      'positionMs': positionMs,
      'playing': playing,
    });
  }

  void _applySyncState(Map<String, dynamic>? state) {
    if (state == null || isHost) return;
    try {
      final songRaw = state['song'] as Map<String, dynamic>?;
      final queueRaw = state['queue'] as List?;
      final currentIndex = state['currentIndex'] as int? ?? 0;
      final playing = state['playing'] as bool? ?? false;

      if (songRaw != null && queueRaw != null) {
        final songs = queueRaw
            .map((j) => Song.fromJson((j as Map).cast<String, dynamic>()))
            .toList();
        _player.playAll(songs, startIndex: currentIndex);
        if (playing) {
          _player.player.play();
        } else {
          _player.player.pause();
        }
      }
    } catch (_) {}
  }

  void _applySyncPosition(num positionMs, bool playing) {
    if (isHost) return;
    _player.player.seek(Duration(milliseconds: positionMs.toInt()));
    if (playing) {
      _player.player.play();
    } else {
      _player.player.pause();
    }
  }

  void _startPositionSync() {
    _positionTimer?.cancel();
    if (!isHost) return;
    _positionTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      final playing = _player.player.playing;
      final pos = _player.player.position.inMilliseconds;
      syncPosition(pos, playing);
    });
  }

  void _setState(RoomConnectionState s) {
    _state = s;
    notifyListeners();
  }

  void _cleanup() {
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
    _memberId = null;
    _roomCode = null;
    _members = [];
    _positionTimer?.cancel();
    _positionTimer = null;
    _error = null;
  }

  @override
  void dispose() {
    _playerSub?.cancel();
    _cleanup();
    super.dispose();
  }
}
