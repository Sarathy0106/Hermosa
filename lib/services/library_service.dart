import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models.dart';

/// Local library: favorites, user playlists and listening history.
/// Songs are stored as their raw API json so they can be re-hydrated fully.
class LibraryService extends ChangeNotifier {
  static const _favBox = 'favorites';
  static const _playlistBox = 'playlists';
  static const _historyBox = 'history';
  static const _historyLimit = 20;

  late final Box _favorites;
  late final Box _playlists;
  late final Box _history;

  static Future<LibraryService> init() async {
    await Hive.initFlutter();
    final s = LibraryService();
    s._favorites = await Hive.openBox(_favBox);
    s._playlists = await Hive.openBox(_playlistBox);
    s._history = await Hive.openBox(_historyBox);
    return s;
  }

  Song _decode(String json) =>
      Song.fromJson(jsonDecode(json) as Map<String, dynamic>);

  // ---- Favorites ----

  bool isFavorite(String songId) => _favorites.containsKey(songId);

  List<Song> get favorites =>
      _favorites.values.map((v) => _decode(v as String)).toList().reversed.toList();

  void toggleFavorite(Song song) {
    if (isFavorite(song.id)) {
      _favorites.delete(song.id);
    } else {
      _favorites.put(song.id, jsonEncode(song.raw));
    }
    notifyListeners();
  }

  // ---- Playlists ----

  List<String> get playlistNames => _playlists.keys.cast<String>().toList();

  List<Song> playlistSongs(String name) {
    final list = (_playlists.get(name) as List?) ?? const [];
    return list.map((v) => _decode(v as String)).toList();
  }

  bool createPlaylist(String name) {
    if (name.trim().isEmpty || _playlists.containsKey(name)) return false;
    _playlists.put(name, <String>[]);
    notifyListeners();
    return true;
  }

  void deletePlaylist(String name) {
    _playlists.delete(name);
    notifyListeners();
  }

  /// Returns false if the song is already in the playlist.
  bool addToPlaylist(String name, Song song) {
    final list =
        ((_playlists.get(name) as List?) ?? const []).cast<String>().toList();
    if (list.any((v) => _decode(v).id == song.id)) return false;
    list.add(jsonEncode(song.raw));
    _playlists.put(name, list);
    notifyListeners();
    return true;
  }

  void removeFromPlaylist(String name, String songId) {
    final list =
        ((_playlists.get(name) as List?) ?? const []).cast<String>().toList();
    list.removeWhere((v) => _decode(v).id == songId);
    _playlists.put(name, list);
    notifyListeners();
  }

  // ---- History ----

  List<Song> get history =>
      _history.values.map((v) => _decode(v as String)).toList().reversed.toList();

  void addHistory(Song song) {
    // Deduplicate by song id, keep most recent last.
    final entries = _history.toMap();
    for (final e in entries.entries) {
      if (_decode(e.value as String).id == song.id) {
        _history.delete(e.key);
      }
    }
    _history.add(jsonEncode(song.raw));
    while (_history.length > _historyLimit) {
      _history.deleteAt(0);
    }
    notifyListeners();
  }

  void clearHistory() {
    _history.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _favorites.close();
    _playlists.close();
    _history.close();
    super.dispose();
  }
}
