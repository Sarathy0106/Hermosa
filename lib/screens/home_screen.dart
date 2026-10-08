import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../services/recommendation_service.dart';
import '../services/room_service.dart';
import '../services/saavn_api.dart';
import '../theme.dart';
import '../widgets/cover_image.dart';
import '../widgets/desktop_top_bar.dart';
import '../widgets/room_sheet.dart';
import '../widgets/song_actions.dart';
import 'collection_screen.dart';

class _HomeSection {
  final String title;
  final String query;
  final String category;
  List<Song> songs = [];
  _HomeSection(this.title, this.query, {this.category = 'Trending'});
}

class HomeScreen extends StatefulWidget {
  final ValueChanged<String>? onSearch;

  const HomeScreen({super.key, this.onSearch});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _sections = [
    _HomeSection('Trending Top Hits', 'top hits 2026', category: 'Trending'),
    _HomeSection('Global Pop Anthems', 'english pop hits', category: 'Pop'),
    _HomeSection('Bollywood Essentials', 'bollywood hits', category: 'Bollywood'),
    _HomeSection('Lo-Fi Chill & Focus', 'lofi chill beats', category: 'Lo-Fi'),
    _HomeSection('Punjabi Party Beats', 'punjabi hits', category: 'Beats'),
    _HomeSection('Indie & Acoustic Vibes', 'indie acoustic', category: 'Indie'),
  ];

  final List<String> _filters = [
    '✨ All',
    '🔥 Trending',
    '💜 For You',
    '🎧 Pop',
    '⚡ Bollywood',
    '🌙 Lo-Fi',
    '🥁 Beats',
  ];
  String _selectedFilter = '✨ All';

  List<PlaylistSummary> _playlists = [];
  List<Song> _recommendedSongs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<SaavnApi>();
    final recommender = context.read<RecommendationService>();
    final library = context.read<LibraryService>();

    setState(() {
      _loading = true;
      _error = null;
    });

    var rateLimited = false;
    final futures = <Future<void>>[
      recommender
          .getPersonalizedMix(
            history: library.history,
            favorites: library.favorites,
            limit: 12,
          )
          .then((recs) {
            _recommendedSongs = recs;
            if (mounted && recs.isNotEmpty) setState(() => _loading = false);
          })
          .catchError((_) {}),

      for (final s in _sections)
        api
            .searchSongs(s.query, limit: 12)
            .then((songs) {
              s.songs = songs;
              if (mounted && songs.isNotEmpty) setState(() => _loading = false);
            })
            .catchError((Object e) {
              if (e is RateLimitedException) rateLimited = true;
            }),

      api
          .searchPlaylists('top hits', limit: 10)
          .then((p) {
            _playlists = p;
            if (mounted && p.isNotEmpty) setState(() => _loading = false);
          })
          .catchError((Object e) {
            if (e is RateLimitedException) rateLimited = true;
          }),
    ];

    await Future.wait(futures);
    if (!mounted) return;
    final empty =
        _sections.every((s) => s.songs.isEmpty) &&
        _playlists.isEmpty &&
        _recommendedSongs.isEmpty;
    setState(() {
      _loading = false;
      _error = !empty
          ? null
          : rateLimited
          ? 'Music service rate limited. Pull down to retry in a minute.'
          : 'Could not reach music servers. Pull down to retry.';
    });
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 5) return 'Late Night Listening';
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Song? _getFeaturedSong(PlayerService player) {
    if (player.current != null) return player.current;
    if (_recommendedSongs.isNotEmpty) return _recommendedSongs.first;
    for (final s in _sections) {
      if (s.songs.isNotEmpty) return s.songs.first;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<LibraryService>().history;
    final player = context.watch<PlayerService>();
    final room = context.watch<RoomService>();
    final featuredSong = _getFeaturedSong(player);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;

        return Scaffold(
          backgroundColor: AppColors.bg,
          body: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── Desktop Top Bar ─────────────────────────────────
                if (isDesktop)
                  SliverToBoxAdapter(
                    child: DesktopTopBar(onSearch: widget.onSearch),
                  ),

                // ── Mobile Header Bar ───────────────────────────────
                if (!isDesktop)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _greeting,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                ShaderMask(
                                  shaderCallback: (r) =>
                                      AppColors.heroGradient.createShader(r),
                                  child: const Text(
                                    'Hermosa',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Live room button
                          IconButton.filledTonal(
                            onPressed: () => showRoomSheet(context),
                            style: IconButton.styleFrom(
                              backgroundColor: room.inRoom
                                  ? AppColors.primaryContainer
                                  : AppColors.surfaceHigh,
                            ),
                            icon: Icon(
                              Icons.group_rounded,
                              size: 20,
                              color: room.inRoom ? AppColors.primary : Colors.white70,
                            ),
                            tooltip: 'Listen Together',
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── Filter Chips Bar ────────────────────────────────
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: _filters.map((filter) {
                        final isSelected = _selectedFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(filter),
                            selected: isSelected,
                            onSelected: (_) => setState(() => _selectedFilter = filter),
                            backgroundColor: AppColors.surfaceHigh,
                            selectedColor: AppColors.primaryContainer,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.primary.withValues(alpha: 0.4)
                                    : Colors.white.withValues(alpha: 0.06),
                              ),
                            ),
                            showCheckmark: false,
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // ── Modern Hero Feature Stage ───────────────────────
                if (featuredSong != null && (_selectedFilter == '✨ All' || _selectedFilter == '💜 For You'))
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                      child: _HeroBanner(
                        song: featuredSong,
                        isDesktop: isDesktop,
                        allRecommendations: _recommendedSongs,
                      ),
                    ),
                  ),

                // ── Loading or Error State ──────────────────────────
                if (_loading && featuredSong == null)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  )
                else if (_error != null && featuredSong == null)
                  SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.wifi_off_rounded,
                              size: 48,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.tonalIcon(
                              onPressed: _load,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else ...[
                  // ── Quick Mood Picks (2x3 Grid on Mobile, Row on Desktop)
                  if ((_selectedFilter == '✨ All' || _selectedFilter == '💜 For You'))
                    () {
                      final quickSongs = _recommendedSongs.isNotEmpty
                          ? _recommendedSongs.take(6).toList()
                          : (_sections.isNotEmpty && _sections.first.songs.isNotEmpty
                              ? _sections.first.songs.take(6).toList()
                              : <Song>[]);
                      if (quickSongs.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                      return SliverToBoxAdapter(
                        child: _QuickMixGrid(songs: quickSongs),
                      );
                    }(),

                  // ── Made For You Row ──────────────────────────────
                  if (_recommendedSongs.isNotEmpty && (_selectedFilter == '✨ All' || _selectedFilter == '💜 For You'))
                    SliverToBoxAdapter(
                      child: _SongSection(
                        title: 'Made For You',
                        subtitle: 'Curated mix based on your taste',
                        badge: 'PERSONALIZED',
                        songs: _recommendedSongs,
                      ),
                    ),

                  // ── Recently Played ───────────────────────────────
                  if (history.isNotEmpty && (_selectedFilter == '✨ All' || _selectedFilter == '💜 For You'))
                    SliverToBoxAdapter(
                      child: _SongSection(
                        title: 'Recently Played',
                        subtitle: 'Pick up where you left off',
                        songs: history,
                      ),
                    ),

                  // ── Curated Sections ──────────────────────────────
                  for (final s in _sections)
                    if (s.songs.isNotEmpty &&
                        (_selectedFilter == '✨ All' ||
                            _selectedFilter.contains(s.category)))
                      SliverToBoxAdapter(
                        child: _SongSection(
                          title: s.title,
                          subtitle: 'Top charts & hot releases',
                          songs: s.songs,
                        ),
                      ),

                  // ── Featured Playlists Row ────────────────────────
                  if (_playlists.isNotEmpty && (_selectedFilter == '✨ All' || _selectedFilter == '🔥 Trending'))
                    SliverToBoxAdapter(
                      child: _PlaylistSection(playlists: _playlists),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 110)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Dynamic Hero Banner Card with glowing background & quick actions
class _HeroBanner extends StatelessWidget {
  final Song song;
  final bool isDesktop;
  final List<Song> allRecommendations;

  const _HeroBanner({
    required this.song,
    required this.isDesktop,
    required this.allRecommendations,
  });

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final isPlayingThis = player.current?.id == song.id && player.player.playing;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF2B1F4D), Color(0xFF13111C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.20),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2B1F4D).withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Background ambient blur circle
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.15),
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.all(isDesktop ? 24 : 18),
              child: Row(
                children: [
                  // Cover Image
                  Hero(
                    tag: 'hero-${song.id}',
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: CoverImage(
                        url: song.imageUrl,
                        size: isDesktop ? 130 : 100,
                        radius: 20,
                      ),
                    ),
                  ),

                  const SizedBox(width: 18),

                  // Details + Actions
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'FEATURED TRACK',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isDesktop ? 20 : 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          song.artists,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            FilledButton.icon(
                              onPressed: () {
                                final queue = allRecommendations.isNotEmpty
                                    ? allRecommendations
                                    : [song];
                                player.playAll(queue);
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: isPlayingThis
                                    ? AppColors.primaryContainer
                                    : AppColors.primary,
                                foregroundColor: isPlayingThis
                                    ? Colors.white
                                    : const Color(0xFF13111A),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 10,
                                ),
                                minimumSize: const Size(0, 38),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              icon: Icon(
                                isPlayingThis
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                size: 20,
                              ),
                              label: Text(
                                isPlayingThis ? 'Playing' : 'Play Mix',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              onPressed: () => player.addToQueue(song),
                              tooltip: 'Add to Queue',
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withValues(alpha: 0.1),
                                minimumSize: const Size(38, 38),
                              ),
                              icon: const Icon(
                                Icons.queue_music_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 2-column Quick Mix grid for fast listening
class _QuickMixGrid extends StatelessWidget {
  final List<Song> songs;
  const _QuickMixGrid({required this.songs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 700;
          final crossAxisCount = isWide ? 3 : 2;

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: math.min(songs.length, crossAxisCount * 2),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: isWide ? 3.8 : 2.7,
            ),
            itemBuilder: (context, index) {
              final song = songs[index];
              final player = context.watch<PlayerService>();
              final isCurrent = player.current?.id == song.id;

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => player.playAll(songs, startIndex: index),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? AppColors.primaryContainer.withValues(alpha: 0.35)
                          : AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCurrent
                            ? AppColors.primary.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Row(
                      children: [
                        AspectRatio(
                          aspectRatio: 1.0,
                          child: CoverImage(
                            url: song.imageUrl,
                            radius: 0,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isCurrent ? AppColors.primary : Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                song.artists,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(
                            isCurrent && player.player.playing
                                ? Icons.graphic_eq_rounded
                                : Icons.play_arrow_rounded,
                            color: isCurrent
                                ? AppColors.primary
                                : Colors.white.withValues(alpha: 0.4),
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Horizontal Song Section with cards & hover play
class _SongSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? badge;
  final List<Song> songs;

  const _SongSection({
    required this.title,
    required this.subtitle,
    this.badge,
    required this.songs,
  });

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerService>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              badge!,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.play_circle_fill_rounded,
                  color: AppColors.primary,
                  size: 32,
                ),
                tooltip: 'Play All',
                onPressed: () => player.playAll(songs),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: songs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final song = songs[i];
              return _SongCard(
                song: song,
                onTap: () => player.playAll(songs, startIndex: i),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SongCard extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;

  const _SongCard({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final isPlayingThis = player.current?.id == song.id;

    return GestureDetector(
      onTap: onTap,
      onLongPress: () => showSongActions(context, song),
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.transparent,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: CoverImage(
                    url: song.imageUrl,
                    size: 140,
                    radius: 18,
                  ),
                ),
                if (isPlayingThis)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: Colors.black.withValues(alpha: 0.45),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.graphic_eq_rounded,
                          color: AppColors.primary,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isPlayingThis ? AppColors.primary : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              song.artists,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Playlist Section Carousel
class _PlaylistSection extends StatelessWidget {
  final List<PlaylistSummary> playlists;
  const _PlaylistSection({required this.playlists});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Text(
            'Featured Playlists',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
        ),
        SizedBox(
          height: 195,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: playlists.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final p = playlists[i];
              return InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CollectionScreen(playlist: p),
                  ),
                ),
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  width: 140,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: CoverImage(
                          url: p.imageUrl,
                          size: 140,
                          radius: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${p.songCount} songs',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
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
