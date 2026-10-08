// Data models for the Saavn API (https://resona-saavn-api.vercel.app/api).

String _decodeEntities(String s) => s
    .replaceAll('&quot;', '"')
    .replaceAll('&amp;', '&')
    .replaceAll('&#039;', "'")
    .replaceAll('&apos;', "'");

String _string(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  return value is String ? value : value.toString();
}

int _integer(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(_string(value)) ?? 0;
}

/// Picks the URL for the wanted quality from a list of {quality, url} maps,
/// falling back to the last (usually highest) entry.
String _pick(dynamic list, String quality) {
  String sanitize(dynamic value) {
    final u = _string(value).trim();
    return u.startsWith('http://') ? 'https://${u.substring(7)}' : u;
  }

  if (list is String) return sanitize(list);
  if (list is! List || list.isEmpty) return '';
  for (final item in list) {
    if (item is Map && item['quality'] == quality) {
      final u = item['url'] ?? item['link'];
      return sanitize(u);
    }
  }
  final last = list.last;
  if (last is Map) {
    final u = last['url'] ?? last['link'];
    return sanitize(u);
  }
  return '';
}

class Song {
  final String id;
  final String title;
  final String artists;
  final String albumName;
  final String? albumId;
  final int durationSeconds;
  final String imageUrl;
  final String streamUrl;

  /// Raw API json, kept so favorites/playlists can be persisted losslessly.
  final Map<String, dynamic> raw;

  Song({
    required this.id,
    required this.title,
    required this.artists,
    required this.albumName,
    required this.albumId,
    required this.durationSeconds,
    required this.imageUrl,
    required this.streamUrl,
    required this.raw,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    final artists = json['artists'];
    final primaryArtists = artists is Map ? artists['primary'] as List? : null;
    final artistList = primaryArtists != null && primaryArtists.isNotEmpty
        ? primaryArtists
        : (artists is Map ? artists['all'] as List? ?? const [] : const []);
    var names = artistList
        .whereType<Map>()
        .map((a) => _decodeEntities(_string(a['name'])))
        .where((n) => n.isNotEmpty)
        .join(', ');
    names = names.isNotEmpty
        ? names
        : _decodeEntities(_string(json['primaryArtists'] ?? json['artist']));
    final album = json['album'];
    return Song(
      id: _string(json['id']),
      title: _decodeEntities(_string(json['name'] ?? json['title'], 'Unknown')),
      artists: names.isEmpty ? 'Unknown artist' : names,
      albumName: _decodeEntities(
        album is Map ? _string(album['name']) : _string(album),
      ),
      albumId: album is Map ? _string(album['id']).nullIfEmpty : null,
      durationSeconds: _integer(json['duration']),
      imageUrl: _pick(json['image'], '500x500'),
      streamUrl: _pick(json['downloadUrl'], '320kbps'),
      raw: json,
    );
  }

  bool get playable => streamUrl.isNotEmpty;

  String get durationLabel {
    final d = Duration(seconds: durationSeconds);
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}

class PlaylistSummary {
  final String id;
  final String name;
  final String imageUrl;
  final int? songCount;

  PlaylistSummary({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.songCount,
  });

  factory PlaylistSummary.fromJson(Map<String, dynamic> json) =>
      PlaylistSummary(
        id: _string(json['id']),
        name: _decodeEntities(_string(json['name'] ?? json['title'])),
        imageUrl: _pick(json['image'], '500x500'),
        songCount: json['songCount'] == null
            ? null
            : _integer(json['songCount']),
      );
}

class AlbumSummary {
  final String id;
  final String name;
  final String artists;
  final String imageUrl;
  final int? year;

  AlbumSummary({
    required this.id,
    required this.name,
    required this.artists,
    required this.imageUrl,
    this.year,
  });

  factory AlbumSummary.fromJson(Map<String, dynamic> json) {
    final artists = json['artists'];
    final artistList = artists is Map
        ? (artists['primary'] as List? ?? const [])
        : const [];
    return AlbumSummary(
      id: _string(json['id']),
      name: _decodeEntities(_string(json['name'] ?? json['title'])),
      artists:
          artistList
              .whereType<Map>()
              .map((a) => _decodeEntities(_string(a['name'])))
              .join(', ')
              .nullIfEmpty ??
          _decodeEntities(_string(json['primaryArtists'])),
      imageUrl: _pick(json['image'], '500x500'),
      year: json['year'] == null ? null : _integer(json['year']),
    );
  }
}

class ArtistSummary {
  final String id;
  final String name;
  final String imageUrl;

  ArtistSummary({required this.id, required this.name, required this.imageUrl});

  factory ArtistSummary.fromJson(Map<String, dynamic> json) => ArtistSummary(
    id: _string(json['id']),
    name: _decodeEntities(_string(json['name'])),
    imageUrl: _pick(json['image'], '500x500'),
  );
}
