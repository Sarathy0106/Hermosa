import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/player_service.dart';
import '../services/saavn_api.dart';
import '../theme.dart';
import '../widgets/cover_image.dart';
import '../widgets/song_tile.dart';
import 'collection_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  late final TabController _tabs = TabController(length: 4, vsync: this);
  Timer? _debounce;
  String _query = '';

  List<Song> _songs = [];
  List<PlaylistSummary> _playlists = [];
  List<AlbumSummary> _albums = [];
  List<ArtistSummary> _artists = [];
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _tabs.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final q = value.trim();
      if (q == _query) return;
      _query = q;
      if (q.isEmpty) {
        setState(() {
          _songs = [];
          _playlists = [];
          _albums = [];
          _artists = [];
        });
        return;
      }
      _search(q);
    });
  }

  Future<void> _search(String q) async {
    final api = context.read<SaavnApi>();
    setState(() => _loading = true);
    // All four verticals run in parallel; each one renders as soon as it
    // lands. Songs (the default tab) usually arrive first — the user sees
    // results without waiting for the slowest request.
    void apply(void Function() update) {
      if (!mounted || q != _query) return;
      setState(() {
        update();
        _loading = false;
      });
    }

    api
        .searchSongs(q, limit: 30)
        .then((r) => apply(() => _songs = r))
        .catchError((_) => apply(() {}));
    api
        .searchPlaylists(q)
        .then((r) => apply(() => _playlists = r))
        .catchError((_) => apply(() {}));
    api
        .searchAlbums(q)
        .then((r) => apply(() => _albums = r))
        .catchError((_) => apply(() {}));
    api
        .searchArtists(q)
        .then((r) => apply(() => _artists = r))
        .catchError((_) => apply(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Songs, artists, albums…',
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textSecondary),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: AppColors.textSecondary),
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),
          TabBar(
            controller: _tabs,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'Songs'),
              Tab(text: 'Playlists'),
              Tab(text: 'Albums'),
              Tab(text: 'Artists'),
            ],
          ),
          Expanded(
            child: _query.isEmpty
                ? const Center(
                    child: Text('Search millions of songs',
                        style: TextStyle(color: AppColors.textSecondary)))
                : _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary))
                    : TabBarView(
                        controller: _tabs,
                        children: [
                          _songList(),
                          _playlistList(),
                          _albumList(),
                          _artistList(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _empty(String label) => Center(
      child:
          Text(label, style: const TextStyle(color: AppColors.textSecondary)));

  Widget _songList() {
    if (_songs.isEmpty) return _empty('No songs found');
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 160),
      itemCount: _songs.length,
      itemBuilder: (context, i) => SongTile(
        song: _songs[i],
        onTap: () =>
            context.read<PlayerService>().playAll(_songs, startIndex: i),
      ),
    );
  }

  Widget _playlistList() {
    if (_playlists.isEmpty) return _empty('No playlists found');
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 160),
      itemCount: _playlists.length,
      itemBuilder: (context, i) {
        final p = _playlists[i];
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          leading: CoverImage(url: p.imageUrl, size: 52),
          title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
              p.songCount != null ? '${p.songCount} songs' : 'Playlist',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CollectionScreen(
                title: p.name,
                imageUrl: p.imageUrl,
                loader: (api) async {
                  final (_, _, songs) = await api.playlistSongs(p.id);
                  return songs;
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _albumList() {
    if (_albums.isEmpty) return _empty('No albums found');
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 160),
      itemCount: _albums.length,
      itemBuilder: (context, i) {
        final a = _albums[i];
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          leading: CoverImage(url: a.imageUrl, size: 52),
          title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
              [a.artists, if (a.year != null) '${a.year}']
                  .where((s) => s.isNotEmpty)
                  .join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CollectionScreen(
                title: a.name,
                imageUrl: a.imageUrl,
                loader: (api) async {
                  final (_, _, songs) = await api.albumSongs(a.id);
                  return songs;
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _artistList() {
    if (_artists.isEmpty) return _empty('No artists found');
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 160),
      itemCount: _artists.length,
      itemBuilder: (context, i) {
        final a = _artists[i];
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          leading: ClipOval(
            child: CoverImage(url: a.imageUrl, size: 52, radius: 26),
          ),
          title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: const Text('Artist',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CollectionScreen(
                title: a.name,
                imageUrl: a.imageUrl,
                loader: (api) => api.artistSongs(a.id),
              ),
            ),
          ),
        );
      },
    );
  }
}
