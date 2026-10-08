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
  static const defaultServerUrl = String.fromEnvironment(
    'ROOM_SERVER_URL',
    defaultValue: 'wss://hermosa-om9v.onrender.com',
  );
  static const _driftTolerance = Duration(milliseconds: 750);

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
  Future<void> _remoteApply = Future.value();
  int _connectionId = 0;

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
  bool get isHost =>
      _memberId != null &&
      _members.isNotEmpty &&
      _memberId == _members.first.id;
  bool get inRoom =>
      _state == RoomConnectionState.connected && _roomCode != null;
  String? get error => _error;

  String get serverUrl =>
      _prefs.get(_serverUrlKey, defaultValue: defaultServerUrl) as String;

  Future<void> setServer(String url) async {
    await _prefs.put(_serverUrlKey, url);
    notifyListeners();
  }

  Future<void> connect([String? url]) async {
    _cleanup();
    final connectionId = ++_connectionId;
    final serverUrl = url ?? this.serverUrl;
    _setState(RoomConnectionState.connecting);
    _error = null;

    try {
      final uri = Uri.parse(serverUrl);
      if (uri.scheme != 'ws' && uri.scheme != 'wss') {
        throw Exception(
          'Invalid URL scheme "${uri.scheme}". Use ws:// or wss://',
        );
      }
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready.timeout(const Duration(seconds: 10));
      if (connectionId != _connectionId) return;

      _sub = _channel!.stream.listen(
        _onMessage,
        onError: (Object e) {
          if (connectionId != _connectionId) return;
          _error = e.toString();
          _setState(RoomConnectionState.error);
        },
        onDone: () {
          if (connectionId != _connectionId) return;
          _cleanup();
          _setState(RoomConnectionState.disconnected);
        },
      );

      _setState(RoomConnectionState.connected);
    } on TimeoutException {
      if (connectionId != _connectionId) return;
      _cleanup();
      _error = 'Connection timed out. Check the server URL and try again.';
      _setState(RoomConnectionState.error);
    } catch (e) {
      if (connectionId != _connectionId) return;
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
        syncState(
          _player.current,
          _player.queue,
          _player.player.currentIndex ?? 0,
          _player.player.playing,
        );
        break;

      case 'room_joined':
        _memberId = msg['memberId'] as String;
        _roomCode = msg['code'] as String;
        _replaceMembers(msg['members']);
        _setState(RoomConnectionState.connected);
        _enqueueRemoteState(msg['state']);
        break;

      case 'member_joined':
        _replaceMembers(msg['members']);
        break;

      case 'member_left':
        _replaceMembers(msg['members']);
        break;

      case 'room_left':
        _cleanup();
        _setState(RoomConnectionState.disconnected);
        break;

      case 'state_update':
        _enqueueRemoteState(msg['state']);
        break;

      case 'position_update':
        final position = msg['positionMs'];
        final playing = msg['playing'];
        if (position is num && playing is bool) {
          _enqueueRemote(() => _applySyncPosition(position, playing));
        }
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
        'song': song?.raw,
        'queue': queue.map((s) => s.raw).toList(),
        'currentIndex': currentIndex,
        'playing': playing,
        'positionMs': _player.player.position.inMilliseconds,
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

  void _enqueueRemoteState(dynamic value) {
    if (value is! Map) return;
    final state = value.cast<String, dynamic>();
    _enqueueRemote(() => _applySyncState(state));
  }

  void _enqueueRemote(Future<void> Function() operation) {
    final connectionId = _connectionId;
    final roomCode = _roomCode;
    _remoteApply = _remoteApply.then((_) async {
      if (connectionId != _connectionId || roomCode != _roomCode || !inRoom) {
        return;
      }
      await operation();
    }).catchError((Object e) {
      debugPrint('[RoomService] playback sync error: $e');
    });
  }

  Future<void> _applySyncState(Map<String, dynamic>? state) async {
    if (state == null || isHost) return;
    try {
      final songRaw = state['song'] as Map<String, dynamic>?;
      final queueRaw = state['queue'] as List?;
      final currentIndex = (state['currentIndex'] as num?)?.toInt() ?? 0;
      final playing = state['playing'] as bool? ?? false;
      final positionMs = (state['positionMs'] as num?)?.toInt() ?? 0;

      if (songRaw != null && queueRaw != null) {
        final songs = queueRaw
            .map((j) => Song.fromJson((j as Map).cast<String, dynamic>()))
            .toList();
        await _player.playAll(
          songs,
          startIndex: currentIndex,
          initialPosition: Duration(milliseconds: positionMs),
          play: playing,
        );
      }
    } catch (e) {
      debugPrint('[RoomService] state sync error: $e');
    }
  }

  Future<void> _applySyncPosition(num positionMs, bool playing) async {
    if (isHost) return;
    final target = Duration(milliseconds: positionMs.toInt());
    final drift = (_player.player.position - target).abs();
    if (drift > _driftTolerance) {
      await _player.player.seek(target);
    }
    if (playing) {
      if (!_player.player.playing) {
        unawaited(
          _player.player.play().catchError((Object e) {
            debugPrint('[RoomService] playback start error: $e');
          }),
        );
      }
    } else {
      if (_player.player.playing) await _player.player.pause();
    }
  }

  void _replaceMembers(dynamic value) {
    final wasHost = isHost;
    final list = value is List ? value : const [];
    _members = list
        .whereType<Map>()
        .map((m) => RoomMember(id: (m['id'] ?? '').toString()))
        .where((m) => m.id.isNotEmpty)
        .toList();
    final nowHost = isHost;
    if (wasHost != nowHost) {
      _startPositionSync();
      if (nowHost) {
        syncState(
          _player.current,
          _player.queue,
          _player.player.currentIndex ?? 0,
          _player.player.playing,
        );
      }
    }
    notifyListeners();
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
    _connectionId++;
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
