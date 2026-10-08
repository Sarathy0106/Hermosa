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
  final String initialQuery;

  const SearchScreen({super.key, this.initialQuery = ''});

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
  String? _error;
  int _pending = 0;
  int _failures = 0;

  static const _quickTrends = [
    '🔥 Top Hits',
    '⚡ Bollywood',
    '🎧 Pop',
    '🌙 Lo-Fi Chill',
    '🎸 Tamil Hits',
    '💃 Punjabi Party',
    '☕ Acoustic',
    '🚀 Synthwave',
  ];

  static const _browseCategories = [
    ('Pop & Hits', [Color(0xFF8B5CF6), Color(0xFF6366F1)], 'pop hits'),
    ('Bollywood Magic', [Color(0xFFEC4899), Color(0xFFF43F5E)], 'bollywood hits'),
    ('Hip Hop & Rap', [Color(0xFFF59E0B), Color(0xFFD97706)], 'hip hop beats'),
    ('Lo-Fi & Study', [Color(0xFF10B981), Color(0xFF059669)], 'lofi chill study'),
    ('Indie & Folk', [Color(0xFF06B6D4), Color(0xFF0284C7)], 'indie acoustic'),
    ('Party & EDM', [Color(0xFF6366F1), Color(0xFF3B82F6)], 'dance edm party'),
    ('Soul & R&B', [Color(0xFFA855F7), Color(0xFF7E22CE)], 'r&b soul'),
    ('Rock & Metal', [Color(0xFFEF4444), Color(0xFFB91C1C)], 'rock classics'),
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuery.trim();
    if (initial.isNotEmpty) {
      _controller.text = initial;
      _query = initial;
      WidgetsBinding.instance.addPostFrameCallback((_) => _search(initial));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _tabs.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final q = value.trim();
      if (q == _query) return;
      _query = q;
      if (q.isEmpty) {
        setState(() {
          _songs = [];
          _playlists = [];
          _albums = [];
          _artists = [];
          _loading = false;
          _error = null;
        });
        return;
      }
      _search(q);
    });
  }

  Future<void> _search(String q) async {
    final api = context.read<SaavnApi>();
    setState(() {
      _loading = true;
      _error = null;
      _pending = 4;
      _failures = 0;
      _songs = [];
      _playlists = [];
      _albums = [];
      _artists = [];
    });

    void apply(void Function() update, {bool failed = false}) {
      if (!mounted || q != _query) return;
      setState(() {
        update();
        if (failed) _failures++;
        _pending--;
        _loading = _pending > 0;
        if (_pending == 0 &&
            _failures > 0 &&
            _songs.isEmpty &&
            _playlists.isEmpty &&
            _albums.isEmpty &&
            _artists.isEmpty) {
          _error = 'Search is temporarily unavailable. Please try again.';
        }
      });
    }

    api
        .searchSongs(q, limit: 30)
        .then((r) => apply(() => _songs = r))
        .catchError((_) => apply(() {}, failed: true));
    api
        .searchPlaylists(q)
        .then((r) => apply(() => _playlists = r))
        .catchError((_) => apply(() {}, failed: true));
    api
        .searchAlbums(q)
        .then((r) => apply(() => _albums = r))
        .catchError((_) => apply(() {}, failed: true));
    api
        .searchArtists(q)
        .then((r) => apply(() => _artists = r))
        .catchError((_) => apply(() {}, failed: true));
  }

  void _performSearch(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    _query = query;
    _search(query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header & Material 3 Search Bar ─────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Search & Explore',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _controller,
                          onChanged: (value) {
                            _onChanged(value);
                            setState(() {});
                          },
                          onSubmitted: (value) {
                            _debounce?.cancel();
                            _query = value.trim();
                            if (_query.isNotEmpty) _search(_query);
                          },
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Songs, artists, albums, playlists...',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 14,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                            suffixIcon: _controller.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.cancel_rounded,
                                      color: Colors.white60,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      _controller.clear();
                                      _onChanged('');
                                      setState(() {});
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Segmented Result Tabs (When query is present) ────
                if (_query.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: TabBar(
                        controller: _tabs,
                        dividerColor: Colors.transparent,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: AppColors.textSecondary,
                        labelStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        tabs: const [
                          Tab(text: 'Songs'),
                          Tab(text: 'Playlists'),
                          Tab(text: 'Albums'),
                          Tab(text: 'Artists'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],

                // ── Body: Categories Landing or Search Results ───────
                Expanded(
                  child: _query.isEmpty
                      ? _SearchBrowseLanding(
                          quickTrends: _quickTrends,
                          categories: _browseCategories,
                          onSelectQuery: _performSearch,
                        )
                      : _loading &&
                              _songs.isEmpty &&
                              _playlists.isEmpty &&
                              _albums.isEmpty &&
                              _artists.isEmpty
                          ? const Center(
                              child: CircularProgressIndicator(color: AppColors.primary),
                            )
                          : _error != null
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.search_off_rounded,
                                        size: 48,
                                        color: Colors.white38,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        _error!,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(color: Colors.white70),
                                      ),
                                      const SizedBox(height: 16),
                                      FilledButton.tonal(
                                        onPressed: () => _search(_query),
                                        child: const Text('Try Again'),
                                      ),
                                    ],
                                  ),
                                )
                              : TabBarView(
                                  controller: _tabs,
                                  children: [
                                    _buildSongsList(),
                                    _buildPlaylistsList(),
                                    _buildAlbumsList(),
                                    _buildArtistsList(),
                                  ],
                                ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState(String label, IconData icon) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: Colors.white24),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );

  Widget _buildSongsList() {
    if (_songs.isEmpty) return _emptyState('No songs found', Icons.music_off_rounded);
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120, top: 4),
      itemCount: _songs.length,
      itemBuilder: (context, i) => SongTile(
        song: _songs[i],
        onTap: () => context.read<PlayerService>().playAll(_songs, startIndex: i),
      ),
    );
  }

  Widget _buildPlaylistsList() {
    if (_playlists.isEmpty) return _emptyState('No playlists found', Icons.queue_music_rounded);
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120, top: 4),
      itemCount: _playlists.length,
      itemBuilder: (context, i) {
        final p = _playlists[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: CoverImage(url: p.imageUrl, size: 54, radius: 12),
          title: Text(
            p.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            p.songCount != null ? '${p.songCount} songs' : 'Playlist',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
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

  Widget _buildAlbumsList() {
    if (_albums.isEmpty) return _emptyState('No albums found', Icons.album_rounded);
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120, top: 4),
      itemCount: _albums.length,
      itemBuilder: (context, i) {
        final a = _albums[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: CoverImage(url: a.imageUrl, size: 54, radius: 12),
          title: Text(
            a.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            [a.artists, if (a.year != null) '${a.year}'].where((s) => s.isNotEmpty).join(' • '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
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

  Widget _buildArtistsList() {
    if (_artists.isEmpty) return _emptyState('No artists found', Icons.person_off_rounded);
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120, top: 4),
      itemCount: _artists.length,
      itemBuilder: (context, i) {
        final a = _artists[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: ClipOval(
            child: CoverImage(url: a.imageUrl, size: 54, radius: 27),
          ),
          title: Text(
            a.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: const Text(
            'Artist',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
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

/// Browse Landing view with trending chips and colorful Category Cards
class _SearchBrowseLanding extends StatelessWidget {
  final List<String> quickTrends;
  final List<(String, List<Color>, String)> categories;
  final ValueChanged<String> onSelectQuery;

  const _SearchBrowseLanding({
    required this.quickTrends,
    required this.categories,
    required this.onSelectQuery,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
      children: [
        // Trending Chips
        const Text(
          'Trending Searches',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: quickTrends.map((trend) {
            return ActionChip(
              label: Text(trend),
              backgroundColor: AppColors.surfaceHigh,
              labelStyle: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              onPressed: () {
                final clean = trend.replaceAll(RegExp(r'^[^\w\s]+'), '').trim();
                onSelectQuery(clean);
              },
            );
          }).toList(),
        ),

        const SizedBox(height: 24),

        // Browse Categories Grid
        const Text(
          'Browse Genres & Moods',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 600;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: categories.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isWide ? 4 : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.8,
              ),
              itemBuilder: (context, i) {
                final item = categories[i];
                final name = item.$1;
                final colors = item.$2;
                final query = item.$3;

                return InkWell(
                  onTap: () => onSelectQuery(query),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.first.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          shadows: [
                            Shadow(color: Colors.black45, blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
