import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../services/saavn_api.dart';
import 'cover_image.dart';
import 'lyrics_viewer.dart';
import 'song_actions.dart';

class DesktopHeroStage extends StatefulWidget {
  final Song song;

  const DesktopHeroStage({super.key, required this.song});

  @override
  State<DesktopHeroStage> createState() => _DesktopHeroStageState();
}

class _DesktopHeroStageState extends State<DesktopHeroStage> {
  int _activeTab = 0; // 0 = Lyrics, 1 = About
  String? _lyrics;
  bool _loadingLyrics = false;
  double? _dragValue;

  @override
  void initState() {
    super.initState();
    _fetchLyrics();
  }

  @override
  void didUpdateWidget(DesktopHeroStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id) {
      _fetchLyrics();
    }
  }

  Future<void> _fetchLyrics() async {
    setState(() {
      _loadingLyrics = true;
      _lyrics = null;
    });
    try {
      final api = context.read<SaavnApi>();
      final l = await api.fetchLyrics(
        widget.song.id,
        title: widget.song.title,
        artist: widget.song.artists,
        duration: widget.song.durationSeconds,
      );
      if (mounted) {
        setState(() {
          _lyrics = l;
          _loadingLyrics = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingLyrics = false);
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<PlayerService>();
    final library = context.watch<LibraryService>();
    final song = widget.song;
    final fav = library.isFavorite(song.id);
    final queue = service.queue;
    final currentIndex = service.player.currentIndex ?? 0;
    final upNextList = queue.skip(currentIndex + 1).take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Main Hero Card Stage ────────────────────────────────────
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(28, 12, 28, 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // Ambient blurred artwork background
                if (song.imageUrl.isNotEmpty)
                  Positioned.fill(
                    child: ImageFiltered(
                      imageFilter: const ColorFilter.mode(
                        Colors.transparent,
                        BlendMode.src,
                      ),
                      child: CachedNetworkImage(
                        imageUrl: song.imageUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                // Warm ambient gradient tint matching the reference
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xEB1A120B),
                          const Color(0xF214101E),
                          const Color(0xFA0B0B12),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                // Content Row
                Padding(
                  padding: const EdgeInsets.all(28),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left: Large Album Cover
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: CoverImage(
                          url: song.imageUrl,
                          size: 280,
                          radius: 20,
                        ),
                      ),
                      const SizedBox(width: 32),
                      // Right: Song Metadata, Controls & Lyrics Card
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title + Favorite & 3-dots
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        song.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        song.artists,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.6),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: fav
                                        ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                                        : Colors.white.withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                      color: fav ? const Color(0xFFEF4444) : Colors.white,
                                      size: 20,
                                    ),
                                    onPressed: () => library.toggleFavorite(song),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.more_vert_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    onPressed: () => showSongActions(context, song),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Progress Slider
                            StreamBuilder<Duration>(
                              stream: service.player.positionStream,
                              builder: (context, posSnap) {
                                final pos = posSnap.data ?? Duration.zero;
                                final total = service.player.duration ??
                                    Duration(seconds: song.durationSeconds);
                                final totalMs = total.inMilliseconds;
                                final currentVal = _dragValue ??
                                    (totalMs > 0
                                        ? (pos.inMilliseconds / totalMs).clamp(0.0, 1.0)
                                        : 0.0);

                                return Column(
                                  children: [
                                    SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackHeight: 3,
                                        thumbShape: const RoundSliderThumbShape(
                                            enabledThumbRadius: 5),
                                        overlayShape: const RoundSliderOverlayShape(
                                            overlayRadius: 10),
                                        activeTrackColor: const Color(0xFFE5A855),
                                        inactiveTrackColor:
                                            Colors.white.withValues(alpha: 0.15),
                                        thumbColor: Colors.white,
                                      ),
                                      child: Slider(
                                        value: currentVal,
                                        onChanged: (v) => setState(() => _dragValue = v),
                                        onChangeEnd: (v) {
                                          service.player.seek(Duration(
                                              milliseconds: (totalMs * v).round()));
                                          setState(() => _dragValue = null);
                                        },
                                      ),
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _fmt(pos),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white.withValues(alpha: 0.45),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          _fmt(total),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white.withValues(alpha: 0.45),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),

                            const SizedBox(height: 10),

                            // Transport Controls
                            Row(
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
                                const SizedBox(width: 20),
                                IconButton(
                                  icon: const Icon(
                                    Icons.skip_previous_rounded,
                                    size: 28,
                                    color: Colors.white,
                                  ),
                                  onPressed: service.previous,
                                ),
                                const SizedBox(width: 20),
                                StreamBuilder<PlayerState>(
                                  stream: service.player.playerStateStream,
                                  builder: (context, snap) {
                                    final playing = snap.data?.playing ?? false;
                                    return GestureDetector(
                                      onTap: service.togglePlay,
                                      child: Container(
                                        width: 52,
                                        height: 52,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white,
                                        ),
                                        child: Icon(
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
                                const SizedBox(width: 20),
                                IconButton(
                                  icon: const Icon(
                                    Icons.skip_next_rounded,
                                    size: 28,
                                    color: Colors.white,
                                  ),
                                  onPressed: service.next,
                                ),
                                const SizedBox(width: 20),
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

                            const SizedBox(height: 14),

                            // ── Glass Lyrics / About Card ─────────────────
                            Container(
                              height: 120,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.28),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      // Lyrics Tab
                                      GestureDetector(
                                        onTap: () => setState(() => _activeTab = 0),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _activeTab == 0
                                                ? Colors.white.withValues(alpha: 0.15)
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'Lyrics',
                                            style: TextStyle(
                                              color: _activeTab == 0
                                                  ? Colors.white
                                                  : Colors.white
                                                      .withValues(alpha: 0.5),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // About Tab
                                      GestureDetector(
                                        onTap: () => setState(() => _activeTab = 1),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _activeTab == 1
                                                ? Colors.white.withValues(alpha: 0.15)
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'About',
                                            style: TextStyle(
                                              color: _activeTab == 1
                                                  ? Colors.white
                                                  : Colors.white
                                                      .withValues(alpha: 0.5),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      InkWell(
                                        onTap: () => showLyricsOverlay(
                                          context,
                                          song.id,
                                          Duration(seconds: song.durationSeconds),
                                          title: song.title,
                                          artist: song.artists,
                                        ),
                                        child: Icon(
                                          Icons.open_in_full_rounded,
                                          size: 14,
                                          color: Colors.white.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: _activeTab == 0
                                        ? _buildLyricsPreview()
                                        : _buildAboutPreview(song),
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
              ],
            ),
          ),
        ),

        // ── "Up Next" Section ─────────────────────────────────────────
        if (upNextList.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Up Next',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Open queue full view
                      },
                      child: Row(
                        children: [
                          Text(
                            'See Queue',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: upNextList.length,
                    separatorBuilder: (_, _) => Divider(
                      color: Colors.white.withValues(alpha: 0.04),
                      height: 1,
                    ),
                    itemBuilder: (ctx, i) {
                      final s = upNextList[i];
                      final trackIndex = currentIndex + 2 + i;
                      return InkWell(
                        onTap: () => service.skipTo(currentIndex + 1 + i),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                child: Text(
                                  '$trackIndex',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              CoverImage(url: s.imageUrl, size: 40, radius: 8),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  s.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  s.artists,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Text(
                                s.durationLabel,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: Icon(
                                  Icons.add_circle_outline_rounded,
                                  size: 18,
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                                onPressed: () => showSongActions(context, s),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildLyricsPreview() {
    if (_loadingLyrics) {
      return Center(
        child: Text(
          'Loading lyrics...',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
        ),
      );
    }
    if (_lyrics == null || _lyrics!.isEmpty) {
      return Center(
        child: Text(
          'No lyrics available for this song',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
        ),
      );
    }
    final timestampRegex = RegExp(r'\[\d{1,2}:\d{2}(?:\.\d+)?\]');
    final lines = _lyrics!
        .split('\n')
        .map((l) => l.replaceAll(timestampRegex, '').trim())
        .where((l) => l.isNotEmpty)
        .take(3)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (lines.isNotEmpty)
          Text(
            lines[0],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        if (lines.length > 1) ...[
          const SizedBox(height: 3),
          Text(
            lines[1],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
        ],
        if (lines.length > 2) ...[
          const SizedBox(height: 2),
          Text(
            lines[2],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAboutPreview(Song song) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Album: ${song.albumName.isEmpty ? "Single" : song.albumName}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          'Duration: ${song.durationLabel} • Released on JioSaavn',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
        ),
      ],
    );
  }
}
