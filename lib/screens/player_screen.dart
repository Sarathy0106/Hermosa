import 'dart:ui';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../services/saavn_api.dart';
import '../services/theme_provider.dart';
import '../widgets/cover_image.dart';
import '../widgets/glass.dart';
import '../widgets/sleep_timer_sheet.dart';
import '../widgets/song_actions.dart';
import '../widgets/wave_slider.dart';

enum _PlayerTab { lyrics, about }

class _LyricLine {
  final Duration? timestamp;
  final String text;

  _LyricLine(this.timestamp, this.text);
}

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  _PlayerTab _currentTab = _PlayerTab.about;
  double _volume = 1.0;
  double? _dragValue;

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<PlayerService>();
    final library = context.watch<LibraryService>();
    final song = service.current;

    if (song == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.shrink(),
      );
    }

    final isFav = library.isFavorite(song.id);
    final isWide = MediaQuery.of(context).size.width >= 750;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A10),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Cinematic Blurred Artwork Background ──────────────────
          if (song.imageUrl.isNotEmpty)
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
              child: Transform.scale(
                scale: 1.15,
                child: CachedNetworkImage(
                  imageUrl: song.imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),

          // ── Atmospheric Gradient Overlay ─────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.65),
                  Colors.black.withValues(alpha: 0.45),
                  Colors.black.withValues(alpha: 0.85),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),

          // ── Main Full Screen Player UI ───────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                children: [
                  // ── 1. Top Navigation Bar ────────────────────────
                  _buildTopBar(context, song, isWide),

                  const SizedBox(height: 16),

                  // ── 2. Center Stage (Artwork & Synced Lyrics/About)
                  Expanded(
                    child: isWide
                        ? _buildDesktopStage(context, song, service)
                        : _buildMobileStage(context, song, service),
                  ),

                  const SizedBox(height: 12),

                  // ── 3. Bottom Master Control Bar ─────────────────
                  _buildBottomBar(
                    context,
                    song,
                    service,
                    library,
                    isFav,
                    isWide,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, Song song, bool isWide) {
    if (!isWide) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 32,
              color: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Minimize',
          ),
          IconButton(
            icon: const Icon(
              Icons.more_vert_rounded,
              size: 24,
              color: Colors.white,
            ),
            tooltip: 'More Options',
            onPressed: () => showSongActions(context, song),
          ),
        ],
      );
    }
    return Row(
      children: [
        // Collapse arrow + Now Playing header
        IconButton(
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 30,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Minimize',
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Now Playing',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                song.albumName.isNotEmpty
                    ? song.albumName
                    : 'From Your Library',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),

        // Segmented Tab Pill: [ Lyrics | About ]
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPillItem('Lyrics', _PlayerTab.lyrics),
              _buildPillItem('About', _PlayerTab.about),
            ],
          ),
        ),

        const SizedBox(width: 16),

        // Song options & Fullscreen Exit
        IconButton(
          icon: const Icon(
            Icons.more_vert_rounded,
            size: 22,
            color: Colors.white,
          ),
          tooltip: 'More Options',
          onPressed: () => showSongActions(context, song),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(
            Icons.crop_free_rounded,
            size: 22,
            color: Colors.white,
          ),
          tooltip: 'Exit Fullscreen',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildPillItem(String label, _PlayerTab tab) {
    final isSelected = _currentTab == tab;
    return GestureDetector(
      onTap: () => setState(() => _currentTab = tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.65),
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopStage(
    BuildContext context,
    Song song,
    PlayerService service,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left Column: Big Center Artwork Card
        Expanded(
          flex: 5,
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final dim = math.min(
                  constraints.maxWidth * 0.85,
                  constraints.maxHeight * 0.88,
                );
                return Container(
                  width: dim,
                  height: dim,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.65),
                        blurRadius: 40,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: CachedNetworkImage(
                      imageUrl: song.imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Container(
                        color: const Color(0xFF1B1B26),
                        child: const Icon(
                          Icons.music_note_rounded,
                          size: 64,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(width: 40),

        // Right Column: Synced Lyrics or About Info
        Expanded(
          flex: 6,
          child: _currentTab == _PlayerTab.lyrics
              ? _FullScreenLyricsView(
                  song: song,
                  totalDuration: Duration(seconds: song.durationSeconds),
                  playerService: service,
                )
              : _buildAboutView(context, song),
        ),
      ],
    );
  }

  Widget _buildMobileStage(
    BuildContext context,
    Song song,
    PlayerService service,
  ) {
    if (_currentTab == _PlayerTab.lyrics) {
      return Stack(
        children: [
          _FullScreenLyricsView(
            song: song,
            totalDuration: Duration(seconds: song.durationSeconds),
            playerService: service,
          ),
          Positioned(
            top: 4,
            right: 4,
            child: FilledButton.tonalIcon(
              onPressed: () => setState(() => _currentTab = _PlayerTab.about),
              icon: const Icon(Icons.album_rounded, size: 16),
              label: const Text('Artwork', style: TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
            ),
          ),
        ],
      );
    }
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = math.min(
            constraints.maxWidth * 0.92,
            constraints.maxHeight * 0.94,
          );
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 36,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: CachedNetworkImage(
                imageUrl: song.imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => Container(
                  color: const Color(0xFF1B1B26),
                  child: const Icon(
                    Icons.music_note_rounded,
                    size: 72,
                    color: Colors.white38,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAboutView(BuildContext context, Song song) {
    return Glass(
      borderRadius: BorderRadius.circular(24),
      tint: Colors.black.withValues(alpha: 0.35),
      padding: const EdgeInsets.all(28),
      child: ListView(
        children: [
          Text(
            song.title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            song.artists,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.75),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white12),
          const SizedBox(height: 16),
          _aboutRow(
            'Album',
            song.albumName.isNotEmpty ? song.albumName : 'Single',
          ),
          _aboutRow('Duration', song.durationLabel),
          _aboutRow('Quality', '320kbps HD Audio'),
          if (song.raw['year'] != null)
            _aboutRow('Released', song.raw['year'].toString()),
          if (song.raw['language'] != null)
            _aboutRow(
              'Language',
              song.raw['language'].toString().toUpperCase(),
            ),
          if (song.raw['copyright_text'] != null)
            _aboutRow('Copyright', song.raw['copyright_text'].toString()),
          const SizedBox(height: 24),
          Text(
            'Artist Credits',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            song.artists,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.65),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _aboutRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    Song song,
    PlayerService service,
    LibraryService library,
    bool isFav,
    bool isWide,
  ) {
    if (!isWide) {
      return _buildMobileControls(context, song, service, library, isFav);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Timeline Seekbar with Timestamps ───────────────────────
          StreamBuilder<Duration>(
            stream: service.player.positionStream,
            builder: (context, posSnap) {
              final pos = posSnap.data ?? Duration.zero;
              final total =
                  service.player.duration ??
                  Duration(seconds: song.durationSeconds);
              final totalMs = total.inMilliseconds;
              final currentVal =
                  _dragValue ??
                  (totalMs > 0
                      ? (pos.inMilliseconds / totalMs).clamp(0.0, 1.0)
                      : 0.0);

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  M3WavySlider(
                    value: currentVal,
                    isPlaying: service.player.playing,
                    activeColor: const Color(0xFFC9B8FF),
                    thumbColor: const Color(0xFFC9B8FF),
                    inactiveColor: Colors.white.withValues(alpha: 0.20),
                    onChanged: (v) => setState(() => _dragValue = v),
                    onChangeEnd: (v) {
                      service.player.seek(
                        Duration(milliseconds: (totalMs * v).round()),
                      );
                      setState(() => _dragValue = null);
                    },
                  ),

                  // Timestamps Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _fmt(pos),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _fmt(total),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 8),

          // ── Three-Part Bottom Controls ────────────────────────────
          Row(
            children: [
              // ── Left: Song Title + Artist + Favorite ──────────────
              Expanded(
                flex: isWide ? 3 : 4,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            song.artists,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isFav
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isFav
                            ? const Color(0xFFEF4444)
                            : Colors.white.withValues(alpha: 0.7),
                        size: 22,
                      ),
                      onPressed: () => library.toggleFavorite(song),
                    ),
                  ],
                ),
              ),

              // ── Center: Transport Controls ────────────────────────
              Expanded(
                flex: isWide ? 4 : 5,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.shuffle_rounded,
                        size: 20,
                        color: service.player.shuffleModeEnabled
                            ? const Color(0xFFE5A855)
                            : Colors.white.withValues(alpha: 0.6),
                      ),
                      onPressed: service.toggleShuffle,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.skip_previous_rounded,
                        size: 28,
                        color: Colors.white,
                      ),
                      onPressed: service.previous,
                    ),
                    const SizedBox(width: 6),
                    StreamBuilder<PlayerState>(
                      stream: service.player.playerStateStream,
                      builder: (context, snap) {
                        final playing = snap.data?.playing ?? false;
                        final processing = snap.data?.processingState;
                        final busy =
                            processing == ProcessingState.loading ||
                            processing == ProcessingState.buffering;

                        return GestureDetector(
                          onTap: service.togglePlay,
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: busy
                                ? const Padding(
                                    padding: EdgeInsets.all(14),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.black,
                                    ),
                                  )
                                : Icon(
                                    playing
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: Colors.black,
                                    size: 30,
                                  ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(
                        Icons.skip_next_rounded,
                        size: 28,
                        color: Colors.white,
                      ),
                      onPressed: service.next,
                    ),
                    IconButton(
                      icon: Icon(
                        service.player.loopMode == LoopMode.one
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                        size: 20,
                        color: service.player.loopMode != LoopMode.off
                            ? const Color(0xFFE5A855)
                            : Colors.white.withValues(alpha: 0.6),
                      ),
                      onPressed: service.cycleRepeat,
                    ),
                  ],
                ),
              ),

              // ── Right: Queue, Lyrics toggle, Volume ───────────────
              if (isWide)
                Expanded(
                  flex: 3,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 20,
                          color: _currentTab == _PlayerTab.lyrics
                              ? const Color(0xFFE5A855)
                              : Colors.white.withValues(alpha: 0.7),
                        ),
                        tooltip: 'Toggle Lyrics',
                        onPressed: () => setState(() {
                          _currentTab = _currentTab == _PlayerTab.lyrics
                              ? _PlayerTab.about
                              : _PlayerTab.lyrics;
                        }),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.queue_music_rounded,
                          size: 22,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        tooltip: 'Up Next Queue',
                        onPressed: () => _showQueue(context),
                      ),
                      Icon(
                        _volume == 0
                            ? Icons.volume_off_rounded
                            : (_volume < 0.5
                                  ? Icons.volume_down_rounded
                                  : Icons.volume_up_rounded),
                        size: 20,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      SizedBox(
                        width: 90,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 4,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 8,
                            ),
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white.withValues(
                              alpha: 0.18,
                            ),
                            thumbColor: Colors.white,
                          ),
                          child: Slider(
                            value: _volume,
                            onChanged: (v) {
                              setState(() => _volume = v);
                              service.player.setVolume(v);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                IconButton(
                  icon: const Icon(
                    Icons.queue_music_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () => _showQueue(context),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileControls(
    BuildContext context,
    Song song,
    PlayerService service,
    LibraryService library,
    bool isFav,
  ) {
    const primaryColor = Color(0xFFC9B8FF);
    const primaryContainerColor = Color(0xFF5A4880);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 1. Song Title + Subtitle + Heart Icon ──────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Song • ${song.artists}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: isFav ? 'Remove from favorites' : 'Add to favorites',
                onPressed: () => library.toggleFavorite(song),
                icon: Icon(
                  isFav
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isFav
                      ? const Color(0xFFFF5252)
                      : Colors.white.withValues(alpha: 0.8),
                  size: 26,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ── 2. Squiggly Wavy Seek Bar + Timestamps ─────────────
        StreamBuilder<Duration>(
          stream: service.player.positionStream,
          builder: (context, snapshot) {
            final position = snapshot.data ?? Duration.zero;
            final total = service.player.duration ??
                Duration(seconds: song.durationSeconds);
            final totalMs = total.inMilliseconds;
            final currentVal = _dragValue ??
                (totalMs > 0
                    ? (position.inMilliseconds / totalMs).clamp(0.0, 1.0)
                    : 0.0);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                M3WavySlider(
                  value: currentVal,
                  isPlaying: service.player.playing,
                  activeColor: primaryColor,
                  thumbColor: primaryColor,
                  inactiveColor: Colors.white.withValues(alpha: 0.20),
                  onChanged: (v) => setState(() => _dragValue = v),
                  onChangeEnd: (v) {
                    service.player.seek(
                      Duration(milliseconds: (totalMs * v).round()),
                    );
                    setState(() => _dragValue = null);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _fmt(position),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.60),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _fmt(total),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.60),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 18),

        // ── 3. Transport Controls (Previous, Stadium Play/Pause, Next) ──
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Previous track button (Circular tonal button)
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF282534),
              ),
              child: IconButton(
                iconSize: 28,
                tooltip: 'Previous',
                onPressed: service.previous,
                icon: const Icon(
                  Icons.skip_previous_rounded,
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(width: 20),

            // Play / Pause stadium/pill button
            StreamBuilder<PlayerState>(
              stream: service.player.playerStateStream,
              builder: (context, snapshot) {
                final state = snapshot.data;
                final playing = state?.playing ?? false;
                final busy =
                    state?.processingState == ProcessingState.loading ||
                    state?.processingState == ProcessingState.buffering;

                return GestureDetector(
                  onTap: busy ? null : service.togglePlay,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 104,
                    height: 64,
                    decoration: BoxDecoration(
                      color: primaryContainerColor,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: primaryContainerColor.withValues(alpha: 0.45),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: busy
                          ? const SizedBox.square(
                              dimension: 26,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 38,
                              color: Colors.white,
                            ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(width: 20),

            // Next track button (Circular tonal button)
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF282534),
              ),
              child: IconButton(
                iconSize: 28,
                tooltip: 'Next',
                onPressed: service.next,
                icon: const Icon(
                  Icons.skip_next_rounded,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ── 4. Bottom 5-Icon Action Bar ────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // 1. Repeat
            IconButton(
              tooltip: 'Repeat',
              onPressed: service.cycleRepeat,
              icon: Icon(
                service.player.loopMode == LoopMode.one
                    ? Icons.repeat_one_rounded
                    : Icons.repeat_rounded,
                size: 22,
                color: service.player.loopMode != LoopMode.off
                    ? primaryColor
                    : Colors.white.withValues(alpha: 0.65),
              ),
            ),

            // 2. Shuffle
            IconButton(
              tooltip: 'Shuffle',
              onPressed: service.toggleShuffle,
              icon: Icon(
                Icons.shuffle_rounded,
                size: 22,
                color: service.player.shuffleModeEnabled
                    ? primaryColor
                    : Colors.white.withValues(alpha: 0.65),
              ),
            ),

            // 3. Lyrics
            IconButton(
              tooltip: 'Lyrics',
              onPressed: () => setState(
                () => _currentTab = _currentTab == _PlayerTab.lyrics
                    ? _PlayerTab.about
                    : _PlayerTab.lyrics,
              ),
              icon: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 22,
                color: _currentTab == _PlayerTab.lyrics
                    ? primaryColor
                    : Colors.white.withValues(alpha: 0.65),
              ),
            ),

            // 4. Queue
            IconButton(
              tooltip: 'Queue',
              onPressed: () => _showQueue(context),
              icon: Icon(
                Icons.queue_music_rounded,
                size: 22,
                color: Colors.white.withValues(alpha: 0.65),
              ),
            ),

            // 5. Sleep Timer
            IconButton(
              tooltip: 'Sleep Timer',
              onPressed: () => showSleepTimerSheet(context),
              icon: Icon(
                Icons.nights_stay_rounded,
                size: 22,
                color: Colors.white.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showQueue(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              maxChildSize: 0.9,
              builder: (ctx, scrollController) {
                final service = ctx.watch<PlayerService>();
                final queue = service.queue;
                final h = ctx.hermosa;
                return Glass(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  tint: const Color(0xD912121C),
                  blur: 28,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Up next (${queue.length})',
                                    style: Theme.of(ctx).textTheme.titleLarge,
                                  ),
                                  if (service.autoplay)
                                    Text(
                                      service.fetchingAutoplay
                                          ? 'Fetching smart recommendations...'
                                          : 'Smart Autoplay active',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: h.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                backgroundColor: service.autoplay
                                    ? h.primary.withValues(alpha: 0.15)
                                    : Colors.white.withValues(alpha: 0.06),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                              ),
                              onPressed: service.toggleAutoplay,
                              icon: Icon(
                                Icons.all_inclusive_rounded,
                                size: 18,
                                color: service.autoplay
                                    ? h.primary
                                    : h.textSecondary,
                              ),
                              label: Text(
                                'Autoplay',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: service.autoplay
                                      ? h.primary
                                      : h.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: queue.length,
                          itemBuilder: (ctx2, i) {
                            final s = queue[i];
                            final isCurrent = service.current?.id == s.id;
                            return ListTile(
                              leading: CoverImage(url: s.imageUrl, size: 44),
                              title: Text(
                                s.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isCurrent ? h.primary : h.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                s.artists,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: h.textSecondary,
                                ),
                              ),
                              trailing: isCurrent
                                  ? Icon(
                                      Icons.graphic_eq_rounded,
                                      color: h.primary,
                                    )
                                  : IconButton(
                                      icon: Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                        color: h.textSecondary,
                                      ),
                                      onPressed: () =>
                                          service.removeFromQueue(i),
                                    ),
                              onTap: () => service.skipTo(i),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// Dynamic Synchronized Lyrics Component for Fullscreen mode
class _FullScreenLyricsView extends StatefulWidget {
  final Song song;
  final Duration totalDuration;
  final PlayerService playerService;

  const _FullScreenLyricsView({
    required this.song,
    required this.totalDuration,
    required this.playerService,
  });

  @override
  State<_FullScreenLyricsView> createState() => _FullScreenLyricsViewState();
}

class _FullScreenLyricsViewState extends State<_FullScreenLyricsView> {
  List<_LyricLine> _lines = [];
  bool _hasTimestamps = false;
  bool _loading = true;
  String? _error;
  final _scrollController = ScrollController();
  int _lastActiveIndex = -1;

  @override
  void initState() {
    super.initState();
    _fetchLyrics();
  }

  @override
  void didUpdateWidget(_FullScreenLyricsView old) {
    super.didUpdateWidget(old);
    if (old.song.id != widget.song.id) {
      _fetchLyrics();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchLyrics() async {
    setState(() {
      _loading = true;
      _error = null;
      _lines = [];
      _hasTimestamps = false;
      _lastActiveIndex = -1;
    });
    try {
      final api = context.read<SaavnApi>();
      final raw = await api.fetchLyrics(
        widget.song.id,
        title: widget.song.title,
        artist: widget.song.artists,
        duration: widget.totalDuration.inSeconds,
      );
      if (!mounted) return;
      if (raw == null || raw.trim().isEmpty) {
        setState(() {
          _loading = false;
          _error = 'Lyrics not available for this song';
        });
        return;
      }
      _parseLyrics(raw);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load lyrics';
        });
      }
    }
  }

  void _parseLyrics(String raw) {
    final tagPattern = RegExp(r'\[(\d{1,2}):(\d{2})(?:[\.:](\d{1,3}))?\]');
    final stripPattern = RegExp(r'\[\d{1,2}:\d{2}(?:[\.:]\d{1,3})?\]');
    final metadataPattern = RegExp(
      r'^\[(ti|ar|al|au|by|offset|length|re|ve):.*\]',
      caseSensitive: false,
    );

    final rawLines = raw
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final parsed = <_LyricLine>[];
    var hasTimestamps = false;

    for (final line in rawLines) {
      if (metadataPattern.hasMatch(line)) continue;

      final matches = tagPattern.allMatches(line);
      final cleanText = line.replaceAll(stripPattern, '').trim();

      if (matches.isNotEmpty) {
        hasTimestamps = true;
        final displayText = cleanText.isNotEmpty ? cleanText : '♪';
        for (final match in matches) {
          final mins = int.parse(match.group(1)!);
          final secs = int.parse(match.group(2)!);
          final msRaw = match.group(3);
          var ms = 0;
          if (msRaw != null) {
            if (msRaw.length == 1) {
              ms = int.parse(msRaw) * 100;
            } else if (msRaw.length == 2) {
              ms = int.parse(msRaw) * 10;
            } else {
              ms = int.parse(msRaw.substring(0, 3));
            }
          }
          final time = Duration(milliseconds: mins * 60000 + secs * 1000 + ms);
          parsed.add(_LyricLine(time, displayText));
        }
      } else if (cleanText.isNotEmpty) {
        parsed.add(_LyricLine(null, cleanText));
      }
    }

    if (hasTimestamps) {
      parsed.sort(
        (a, b) => (a.timestamp ?? Duration.zero).compareTo(
          b.timestamp ?? Duration.zero,
        ),
      );
    }

    setState(() {
      _lines = parsed;
      _hasTimestamps = hasTimestamps;
      _loading = false;
    });
  }

  int _getActiveIndex(Duration position) {
    if (_lines.isEmpty || !_hasTimestamps) return 0;
    final posMs = position.inMilliseconds;
    var active = 0;
    for (var i = 0; i < _lines.length; i++) {
      final ts = _lines[i].timestamp;
      if (ts != null) {
        if (posMs >= ts.inMilliseconds) {
          active = i;
        } else {
          break;
        }
      }
    }
    return active;
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients ||
        index < 0 ||
        index >= _lines.length ||
        !_hasTimestamps) {
      return;
    }
    final viewportHeight = _scrollController.position.viewportDimension;
    final targetOffset = (index * 58.0) - (viewportHeight * 0.36);
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white70),
      );
    }

    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 16,
          ),
        ),
      );
    }

    if (_lines.isEmpty) {
      return Center(
        child: Text(
          'No lyrics found',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 16,
          ),
        ),
      );
    }

    return StreamBuilder<Duration>(
      stream: widget.playerService.player.positionStream,
      builder: (context, snap) {
        final pos = snap.data ?? Duration.zero;
        final currentIndex = _getActiveIndex(pos);

        if (_hasTimestamps && currentIndex != _lastActiveIndex) {
          _lastActiveIndex = currentIndex;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToIndex(currentIndex);
          });
        }

        return ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0.0, 0.08, 0.90, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: ListView.builder(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 16),
            itemCount: _lines.length,
            itemBuilder: (context, i) {
              final line = _lines[i];
              final isCurrent = _hasTimestamps && i == currentIndex;

              return GestureDetector(
                onTap: () {
                  if (line.timestamp != null) {
                    widget.playerService.player.seek(line.timestamp!);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    line.text,
                    style: TextStyle(
                      fontSize: _hasTimestamps ? (isCurrent ? 28 : 20) : 21,
                      fontWeight: _hasTimestamps
                          ? (isCurrent ? FontWeight.w800 : FontWeight.w500)
                          : FontWeight.w500,
                      color: _hasTimestamps
                          ? (isCurrent
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.38))
                          : Colors.white.withValues(alpha: 0.85),
                      height: 1.5,
                      letterSpacing: isCurrent ? -0.3 : 0,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
