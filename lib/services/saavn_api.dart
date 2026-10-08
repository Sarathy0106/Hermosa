import 'dart:async';
import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

import '../models.dart';

class RateLimitedException implements Exception {
  @override
  String toString() => 'Rate limited';
}

/// Client for our self-hosted jiosaavn-api instance
/// (https://github.com/sumitkolhe/jiosaavn-api deployed on Vercel).
///
/// Requests run in parallel (it's our own server — no shared rate limit),
/// every successful response is cached in Hive, and cached data (even
/// stale) is served when the service errors out.
class SaavnApi {
  static const _defaultBaseUrl = 'https://resona-saavn-api.vercel.app/api';
  static const _configuredBaseUrl = String.fromEnvironment(
    'SAAVN_API_URL',
    defaultValue: _defaultBaseUrl,
  );
  static const httpApiBaseUrl = String.fromEnvironment(
    'HERMOSA_API_URL',
    defaultValue: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: String.fromEnvironment(
        'API_URL',
        defaultValue: 'https://server-ebon-one-95.vercel.app',
      ),
    ),
  );
  static const _cacheTtl = Duration(hours: 6);

  final Box _cache;
  final http.Client _client = http.Client();

  SaavnApi._(this._cache);

  static Future<SaavnApi> init() async {
    final box = await Hive.openBox('api_cache');
    return SaavnApi._(box);
  }

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, String> params,
  ) async {
    final base = Uri.parse(_configuredBaseUrl);
    final uri = base.replace(
      path: '${base.path.replaceFirst(RegExp(r'/$'), '')}$path',
      queryParameters: params,
    );
    final key = uri.toString();

    // Fresh cache hit — no network at all.
    final cached = _cache.get(key);
    if (cached != null) {
      final entry = jsonDecode(cached as String) as Map<String, dynamic>;
      final age = DateTime.now().millisecondsSinceEpoch - (entry['t'] as int);
      if (age < _cacheTtl.inMilliseconds) {
        return entry['data'] as Map<String, dynamic>;
      }
    }

    try {
      final data = await _fetch(uri);
      await _cache.put(
        key,
        jsonEncode({'t': DateTime.now().millisecondsSinceEpoch, 'data': data}),
      );
      return data;
    } catch (e) {
      // Network/rate-limit failure: fall back to stale cache if we have it.
      if (cached != null) {
        final entry = jsonDecode(cached as String) as Map<String, dynamic>;
        return entry['data'] as Map<String, dynamic>;
      }
      rethrow;
    }
  }

  Future<dynamic> _fetch(Uri uri) async {
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      if (attempt > 0) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      try {
        final res = await _client.get(uri).timeout(const Duration(seconds: 12));
        if (res.statusCode == 429) {
          lastError = RateLimitedException();
          continue;
        }
        if (res.statusCode < 200 || res.statusCode >= 300) {
          lastError = Exception('API request failed (${res.statusCode})');
          continue;
        }
        final decoded = jsonDecode(res.body);
        if (decoded is! Map<String, dynamic>) {
          lastError = const FormatException('Invalid API response');
          continue;
        }
        final body = decoded;
        if (body['success'] != true) {
          lastError = Exception(body['message'] ?? 'API error');
          continue;
        }
        return body['data'];
      } on RateLimitedException {
        rethrow;
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('API error');
  }

  Future<List<Song>> searchSongs(
    String query, {
    int page = 0,
    int limit = 25,
  }) async {
    final data = await _get('/search/songs', {
      'query': query,
      'page': '$page',
      'limit': '$limit',
    });
    return ((data['results'] as List?) ?? const [])
        .map((j) => Song.fromJson((j as Map).cast<String, dynamic>()))
        .where((s) => s.playable)
        .toList();
  }

  Future<List<PlaylistSummary>> searchPlaylists(
    String query, {
    int limit = 20,
  }) async {
    final data = await _get('/search/playlists', {
      'query': query,
      'limit': '$limit',
    });
    return ((data['results'] as List?) ?? const [])
        .map(
          (j) => PlaylistSummary.fromJson((j as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  Future<List<AlbumSummary>> searchAlbums(
    String query, {
    int limit = 20,
  }) async {
    final data = await _get('/search/albums', {
      'query': query,
      'limit': '$limit',
    });
    return ((data['results'] as List?) ?? const [])
        .map((j) => AlbumSummary.fromJson((j as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<ArtistSummary>> searchArtists(
    String query, {
    int limit = 20,
  }) async {
    final data = await _get('/search/artists', {
      'query': query,
      'limit': '$limit',
    });
    return ((data['results'] as List?) ?? const [])
        .map((j) => ArtistSummary.fromJson((j as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Returns (playlist name, image, songs).
  Future<(String, String, List<Song>)> playlistSongs(
    String id, {
    int limit = 100,
  }) async {
    final data = await _get('/playlists', {'id': id, 'limit': '$limit'});
    return (
      data['name'] as String? ?? 'Playlist',
      _bigImage(data['image']),
      _songList(data['songs']),
    );
  }

  Future<(String, String, List<Song>)> albumSongs(String id) async {
    final data = await _get('/albums', {'id': id});
    return (
      data['name'] as String? ?? 'Album',
      _bigImage(data['image']),
      _songList(data['songs']),
    );
  }

  Future<List<Song>> artistSongs(String id, {int page = 0}) async {
    final data = await _get('/artists/$id/songs', {'page': '$page'});
    return _songList(data['songs']);
  }

  Future<List<Song>> songSuggestions(String id) async {
    try {
      final uri = _apiUri('/songs/$id/suggestions');
      final data = await _fetch(uri);
      return _songList(data);
    } catch (_) {
      return const [];
    }
  }

  Future<Song?> songDetails(String id) async {
    try {
      final uri = _apiUri('/songs/$id');
      final data = await _fetch(uri);
      final list = _songList(data);
      return list.isNotEmpty ? list.first : null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> fetchLyrics(
    String songId, {
    String? title,
    String? artist,
    int? duration,
  }) async {
    // Route lyrics queries through Hermosa Lyrics Server (which cleanly handles missing lyrics without 404 console errors)
    try {
      final uri = httpApiUri('/api/lyrics').replace(
        queryParameters: {
          'id': songId,
          if (title != null && title.isNotEmpty) 'title': title,
          if (artist != null && artist.isNotEmpty) 'artist': artist,
          if (duration != null && duration > 0) 'duration': duration.toString(),
        },
      );
      final res = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        if (body['success'] == true && body['lyrics'] != null) {
          return body['lyrics'] as String;
        }
      }
    } catch (_) {}

    return null;
  }

  List<Song> _songList(dynamic list) => ((list as List?) ?? const [])
      .map((j) => Song.fromJson((j as Map).cast<String, dynamic>()))
      .where((s) => s.playable)
      .toList();

  String _bigImage(dynamic image) {
    if (image is List && image.isNotEmpty) {
      return ((image.last as Map)['url'] ?? '').toString();
    }
    if (image is String) return image;
    return '';
  }

  Uri _apiUri(String path) {
    final base = Uri.parse(_configuredBaseUrl);
    return base.replace(
      path: '${base.path.replaceFirst(RegExp(r'/$'), '')}$path',
      queryParameters: null,
    );
  }

  static Uri httpApiUri(String path) {
    final base = Uri.parse(httpApiBaseUrl);
    return base.replace(
      path: '${base.path.replaceFirst(RegExp(r'/$'), '')}$path',
      queryParameters: null,
    );
  }

  void dispose() {
    _client.close();
    _cache.close();
  }
}
