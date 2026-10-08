import 'package:flutter_test/flutter_test.dart';
import 'package:hermosa/models.dart';

void main() {
  group('Saavn client models', () {
    test('parses numeric strings and alternate metadata shapes', () {
      final song = Song.fromJson({
        'id': 42,
        'title': 'Rock &amp; Roll',
        'primaryArtists': 'Artist &amp; Guest',
        'album': 'Single',
        'duration': '187',
        'image': 'http://cdn.example/cover.jpg',
        'downloadUrl': [
          {'quality': '320kbps', 'link': 'http://cdn.example/song.mp3'},
        ],
      });

      expect(song.id, '42');
      expect(song.title, 'Rock & Roll');
      expect(song.artists, 'Artist & Guest');
      expect(song.albumName, 'Single');
      expect(song.durationSeconds, 187);
      expect(song.durationLabel, '3:07');
      expect(song.imageUrl, 'https://cdn.example/cover.jpg');
      expect(song.streamUrl, 'https://cdn.example/song.mp3');
      expect(song.playable, isTrue);
    });

    test('uses all artists and highest available media fallback', () {
      final song = Song.fromJson({
        'id': 'track',
        'name': 'Track',
        'artists': {
          'primary': <Object>[],
          'all': [
            {'name': 'One'},
            {'name': 'Two'},
          ],
        },
        'album': {'id': 99, 'name': 'Album'},
        'image': [
          {'quality': '50x50', 'url': 'https://cdn.example/small.jpg'},
          {'quality': '150x150', 'url': 'https://cdn.example/large.jpg'},
        ],
        'downloadUrl': [
          {'quality': '96kbps', 'url': 'https://cdn.example/audio.mp3'},
        ],
      });

      expect(song.artists, 'One, Two');
      expect(song.albumId, '99');
      expect(song.imageUrl, 'https://cdn.example/large.jpg');
      expect(song.streamUrl, 'https://cdn.example/audio.mp3');
    });

    test('parses search summary string counts and years', () {
      final playlist = PlaylistSummary.fromJson({
        'id': 7,
        'title': 'Mix',
        'songCount': '12',
        'image': 'https://cdn.example/mix.jpg',
      });
      final album = AlbumSummary.fromJson({
        'id': 8,
        'name': 'Record',
        'primaryArtists': 'Singer',
        'year': '2025',
        'image': 'https://cdn.example/record.jpg',
      });

      expect(playlist.id, '7');
      expect(playlist.songCount, 12);
      expect(album.artists, 'Singer');
      expect(album.year, 2025);
    });
  });
}
