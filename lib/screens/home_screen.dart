import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../services/saavn_api.dart';
import '../theme.dart';
import '../widgets/cover_image.dart';
import '../widgets/song_actions.dart';
import 'collection_screen.dart';

class _HomeSection {
  final String title;
  final String query;
  List<Song> songs = [];
  _HomeSection(this.title, this.query);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _sections = [
    _HomeSection('Trending now', 'top hits 2026'),
    _HomeSection('Bollywood essentials', 'bollywood hits'),
    _HomeSection('English pop', 'english pop hits'),
    _HomeSection('Punjabi beats', 'punjabi hits'),
    _HomeSection('Lo-fi & chill', 'lofi chill'),
  ];
  List<PlaylistSummary> _playlists = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<SaavnApi>();
    setState(() {
      _loading = true;
      _error = null;
    });
    // Sections load in parallel and render as they arrive — one failing
    // must not blank the whole page.
    var rateLimited = false;
    final futures = <Future<void>>[
      for (final s in _sections)
        api.searchSongs(s.query, limit: 12).then((songs) {
          s.songs = songs;
          if (mounted && songs.isNotEmpty) setState(() => _loading = false);
        }).catchError((Object e) {
          if (e is RateLimitedException) rateLimited = true;
        }),
      api.searchPlaylists('top hits', limit: 12).then((p) {
        _playlists = p;
        if (mounted && p.isNotEmpty) setState(() => _loading = false);
      }).catchError((Object e) {
        if (e is RateLimitedException) rateLimited = true;
      }),
    ];
    await Future.wait(futures);
    if (!mounted) return;
    final empty =
        _sections.every((s) => s.songs.isEmpty) && _playlists.isEmpty;
    setState(() {
      _loading = false;
      _error = !empty
          ? null
          : rateLimited
              ? 'The music service is busy right now (rate limited).\nPull down to retry in a minute.'
              : 'Could not reach the music service.\nPull to retry.';
    });
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 5) return 'Up late?';
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<LibraryService>().history;
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_greeting,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 14)),
                    const SizedBox(height: 2),
                    ShaderMask(
                      shaderCallback: (r) =>
                          AppColors.heroGradient.createShader(r),
                      child: Text('Hermosa',
                          style: Theme.of(context)
                              .textTheme
                              .headlineLarge
                              ?.copyWith(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primary)),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Text(_error!,
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: AppColors.textSecondary)),
                ),
              )
            else ...[
              if (history.isNotEmpty)
                SliverToBoxAdapter(
                    child: _SongRow(title: 'Recently played', songs: history)),
              for (final s in _sections)
                if (s.songs.isNotEmpty)
                  SliverToBoxAdapter(
                      child: _SongRow(title: s.title, songs: s.songs)),
              if (_playlists.isNotEmpty)
                SliverToBoxAdapter(child: _PlaylistRow(playlists: _playlists)),
              const SliverToBoxAdapter(child: SizedBox(height: 160)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SongRow extends StatelessWidget {
  final String title;
  final List<Song> songs;

  const _SongRow({required this.title, required this.songs});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(title,
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.play_circle_fill_rounded,
                    color: AppColors.primary, size: 28),
                onPressed: () =>
                    context.read<PlayerService>().playAll(songs),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: songs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final song = songs[i];
              return GestureDetector(
                onTap: () => context
                    .read<PlayerService>()
                    .playAll(songs, startIndex: i),
                onLongPress: () => showSongActions(context, song),
                child: SizedBox(
                  width: 130,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CoverImage(url: song.imageUrl, size: 130, radius: 16),
                      const SizedBox(height: 8),
                      Text(song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(song.artists,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PlaylistRow extends StatelessWidget {
  final List<PlaylistSummary> playlists;

  const _PlaylistRow({required this.playlists});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text('Editorial playlists',
              style: Theme.of(context).textTheme.titleLarge),
        ),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: playlists.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final p = playlists[i];
              return GestureDetector(
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
                child: SizedBox(
                  width: 150,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CoverImage(url: p.imageUrl, size: 150, radius: 16),
                      const SizedBox(height: 8),
                      Text(p.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
