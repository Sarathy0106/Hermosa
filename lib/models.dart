// Data models for the Saavn API (https://resona-saavn-api.vercel.app/api).

String _decodeEntities(String s) => s
    .replaceAll('&quot;', '"')
    .replaceAll('&amp;', '&')
    .replaceAll('&#039;', "'")
    .replaceAll('&apos;', "'");

/// Picks the URL for the wanted quality from a list of {quality, url} maps,
/// falling back to the last (usually highest) entry.
String _pick(dynamic list, String quality) {
  if (list is! List || list.isEmpty) return '';
  for (final item in list) {
    if (item is Map && item['quality'] == quality) {
      return (item['url'] ?? item['link'] ?? '') as String;
    }
  }
  final last = list.last;
  if (last is Map) return (last['url'] ?? last['link'] ?? '') as String;
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
    final artistList =
        ((json['artists'] as Map?)?['primary'] as List?) ?? const [];
    final names = artistList
        .map((a) => _decodeEntities((a as Map)['name'] as String? ?? ''))
        .where((n) => n.isNotEmpty)
        .join(', ');
    final album = json['album'] as Map?;
    return Song(
      id: json['id'] as String? ?? '',
      title: _decodeEntities(json['name'] as String? ?? 'Unknown'),
      artists: names.isEmpty ? 'Unknown artist' : names,
      albumName: _decodeEntities((album?['name'] as String?) ?? ''),
      albumId: album?['id'] as String?,
      durationSeconds: (json['duration'] as num?)?.toInt() ?? 0,
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

class PlaylistSummary {
  final String id;
  final String name;
  final String imageUrl;
  final int? songCount;

  PlaylistSummary(
      {required this.id,
      required this.name,
      required this.imageUrl,
      this.songCount});

  factory PlaylistSummary.fromJson(Map<String, dynamic> json) =>
      PlaylistSummary(
        id: json['id'].toString(),
        name: _decodeEntities(json['name'] as String? ?? ''),
        imageUrl: _pick(json['image'], '500x500'),
        songCount: (json['songCount'] as num?)?.toInt(),
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
    final artistList =
        ((json['artists'] as Map?)?['primary'] as List?) ?? const [];
    return AlbumSummary(
      id: json['id'].toString(),
      name: _decodeEntities(json['name'] as String? ?? ''),
      artists: artistList
          .map((a) => _decodeEntities((a as Map)['name'] as String? ?? ''))
          .join(', '),
      imageUrl: _pick(json['image'], '500x500'),
      year: (json['year'] as num?)?.toInt(),
    );
  }
}

class ArtistSummary {
  final String id;
  final String name;
  final String imageUrl;

  ArtistSummary({required this.id, required this.name, required this.imageUrl});

  factory ArtistSummary.fromJson(Map<String, dynamic> json) => ArtistSummary(
        id: json['id'].toString(),
        name: _decodeEntities(json['name'] as String? ?? ''),
        imageUrl: _pick(json['image'], '500x500'),
      );
}
