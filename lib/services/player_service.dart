import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models.dart';
import 'download_service.dart';
import 'library_service.dart';
import 'recommendation_service.dart';

/// Owns the [AudioPlayer] and the play queue with Smart Autoplay & Recommendation engine.
class PlayerService extends ChangeNotifier {
  static const _boxName = 'player_prefs';
  static const _autoplayKey = 'smart_autoplay';

  final AudioPlayer player = AudioPlayer();
  final DownloadService? _downloads;
  final RecommendationService? _recommender;
  final LibraryService? _library;

  List<Song> _queue = [];
  List<Song> get queue => List.unmodifiable(_queue);

  bool _autoplay = true;
  bool get autoplay => _autoplay;

  bool _fetchingAutoplay = false;
  int _queueRevision = 0;
  bool get fetchingAutoplay => _fetchingAutoplay;

  Song? get current {
    final tag = player.sequenceState.currentSource?.tag;
    if (tag is MediaItem) {
      for (final s in _queue) {
        if (s.id == tag.id) return s;
      }
    }
    final i = player.currentIndex;
    if (i != null && i >= 0 && i < _queue.length) {
      return _queue[i];
    }
    return _queue.isNotEmpty ? _queue.first : null;
  }

  PlayerService({
    DownloadService? downloads,
    RecommendationService? recommender,
    LibraryService? library,
  }) : _downloads = downloads,
       _recommender = recommender,
       _library = library {
    _loadPrefs();

    player.currentIndexStream.listen((_) {
      notifyListeners();
      _checkAutoplay();
    });

    player.sequenceStateStream.listen((_) {
      notifyListeners();
    });

    player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && _autoplay) {
        _checkAutoplay();
      }
      notifyListeners();
    });

    player.speedStream.listen((_) => notifyListeners());
  }

  Future<void> _loadPrefs() async {
    try {
      final box = await Hive.openBox(_boxName);
      _autoplay = box.get(_autoplayKey, defaultValue: true) as bool;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> toggleAutoplay() async {
    _autoplay = !_autoplay;
    try {
      final box = await Hive.openBox(_boxName);
      await box.put(_autoplayKey, _autoplay);
    } catch (_) {}
    notifyListeners();
    if (_autoplay) {
      _checkAutoplay();
    }
  }

  Future<void> setAutoplay(bool enable) async {
    _autoplay = enable;
    try {
      final box = await Hive.openBox(_boxName);
      await box.put(_autoplayKey, _autoplay);
    } catch (_) {}
    notifyListeners();
    if (_autoplay) {
      _checkAutoplay();
    }
  }

  AudioSource _source(Song s) {
    final local = !kIsWeb ? _downloads?.localPath(s.id) : null;
    final uri = local != null ? Uri.file(local) : Uri.parse(s.streamUrl);
    final artUri = s.imageUrl.isEmpty ? null : Uri.tryParse(s.imageUrl);
    return AudioSource.uri(
      uri,
      tag: MediaItem(
        id: s.id,
        title: s.title,
        artist: s.artists,
        album: s.albumName,
        duration: Duration(seconds: s.durationSeconds),
        artUri: artUri,
      ),
    );
  }

  void _startPlayback() {
    unawaited(
      player.play().catchError((Object e) {
        debugPrint('[PlayerService] playback error: $e');
      }),
    );
  }

  /// Replaces the queue with [songs] and starts playing at [startIndex].
  Future<void> playAll(
    List<Song> songs, {
    int startIndex = 0,
    Duration initialPosition = Duration.zero,
    bool play = true,
  }) async {
    final playable = songs.where((s) => s.playable).toList();
    if (playable.isEmpty) return;
    final revision = ++_queueRevision;

    // Recompute the start index against the filtered list.
    var index = 0;
    if (startIndex >= 0 && startIndex < songs.length) {
      final target = songs[startIndex];
      index = playable.indexWhere((s) => s.id == target.id);
      if (index < 0) index = 0;
    }
    _queue = playable;
    notifyListeners();

    try {
      await player.setAudioSources(
        playable.map(_source).toList(),
        initialIndex: index,
        initialPosition: initialPosition,
      );
      if (revision != _queueRevision) return;
      if (play) {
        // This future completes only when playback pauses or finishes.
        _startPlayback();
      } else {
        await player.pause();
      }
    } catch (e) {
      debugPrint('[PlayerService] playAll error: $e');
    }

    // If only 1 song was queued or queue is short, prefetch recommendations
    if (_autoplay && _queue.length <= 2) {
      _checkAutoplay();
    }
  }

  Future<void> playSong(Song song) => playAll([song]);

  Future<void> playNext(Song song) async {
    if (_queue.isEmpty) return playAll([song]);
    final at = (player.currentIndex ?? 0) + 1;
    _queue.insert(at, song);
    try {
      await player.insertAudioSource(at, _source(song));
    } catch (e) {
      debugPrint('[PlayerService] playNext error: $e');
    }
    notifyListeners();
  }

  Future<void> addToQueue(Song song) async {
    if (_queue.isEmpty) return playAll([song]);
    _queue.add(song);
    try {
      await player.addAudioSource(_source(song));
    } catch (e) {
      debugPrint('[PlayerService] addToQueue error: $e');
    }
    notifyListeners();
  }

  Future<void> appendRecommendations(List<Song> songs) async {
    final playable = songs
        .where((s) => s.playable && !_queue.any((q) => q.id == s.id))
        .toList();
    if (playable.isEmpty) return;
    _queue.addAll(playable);
    for (final s in playable) {
      try {
        await player.addAudioSource(_source(s));
      } catch (e) {
        debugPrint('[PlayerService] appendRecommendations add error: $e');
      }
    }
    notifyListeners();
  }

  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _queue.removeAt(index);
    try {
      await player.removeAudioSourceAt(index);
    } catch (e) {
      debugPrint('[PlayerService] removeFromQueue error: $e');
    }
    notifyListeners();
  }

  Future<void> skipTo(int index) async {
    if (index < 0 || index >= _queue.length) return;
    try {
      await player.seek(Duration.zero, index: index);
      _startPlayback();
    } catch (e) {
      debugPrint('[PlayerService] skipTo error: $e');
    }
  }

  Future<void> togglePlay() async {
    try {
      if (player.playing) {
        await player.pause();
      } else {
        _startPlayback();
      }
    } catch (e) {
      debugPrint('[PlayerService] togglePlay error: $e');
    }
  }

  Future<void> next() async {
    try {
      await player.seekToNext();
    } catch (e) {
      debugPrint('[PlayerService] next error: $e');
    }
  }

  Future<void> previous() async {
    try {
      if (player.position.inSeconds > 3 || !player.hasPrevious) {
        await player.seek(Duration.zero);
      } else {
        await player.seekToPrevious();
      }
    } catch (e) {
      debugPrint('[PlayerService] previous error: $e');
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

  /// Automatically fetch and append recommendations when nearing end of queue
  Future<void> _checkAutoplay() async {
    if (!_autoplay ||
        _fetchingAutoplay ||
        _queue.isEmpty ||
        _recommender == null) {
      return;
    }
    final curr = current;
    final idx = player.currentIndex;
    if (curr == null || idx == null) return;

    if (idx >= _queue.length - 2) {
      _fetchingAutoplay = true;
      notifyListeners();
      try {
        final recs = await _recommender.getRecommendations(
          curr,
          history: _library?.history,
          favorites: _library?.favorites,
          excludeIds: _queue.map((s) => s.id).toList(),
          limit: 10,
        );
        if (recs.isNotEmpty) {
          await appendRecommendations(recs);
        }
      } catch (e) {
        debugPrint('[PlayerService] Smart Autoplay error: $e');
      } finally {
        _fetchingAutoplay = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }
}
