import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../screens/player_screen.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import 'cover_image.dart';
import 'lyrics_viewer.dart';
import 'wave_slider.dart';

class BottomPlayerBar extends StatefulWidget {
  final VoidCallback? onToggleQueue;

  const BottomPlayerBar({super.key, this.onToggleQueue});

  @override
  State<BottomPlayerBar> createState() => _BottomPlayerBarState();
}

class _BottomPlayerBarState extends State<BottomPlayerBar> {
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
    if (song == null) return const SizedBox.shrink();

    final fav = library.isFavorite(song.id);
    const primaryColor = Color(0xFFC9B8FF);
    const primaryContainerColor = Color(0xFF5A4880);

    return Container(
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F16),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Left: Song Info ───────────────────────────────────────
          Expanded(
            flex: 3,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _openFullScreen(context),
                  child: CoverImage(url: song.imageUrl, size: 52, radius: 12),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => _openFullScreen(context),
                        child: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        song.artists,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    fav
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: fav
                        ? const Color(0xFFFF5252)
                        : Colors.white.withValues(alpha: 0.6),
                    size: 20,
                  ),
                  onPressed: () => library.toggleFavorite(song),
                ),
              ],
            ),
          ),

          // ── Center: Transport Controls & Seekbar ──────────────────
          Expanded(
            flex: 5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Button Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.shuffle_rounded,
                        size: 18,
                        color: service.player.shuffleModeEnabled
                            ? primaryColor
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                      onPressed: service.toggleShuffle,
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.skip_previous_rounded,
                        size: 22,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                      onPressed: service.previous,
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 8),
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
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 52,
                            height: 36,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: primaryContainerColor,
                              boxShadow: [
                                BoxShadow(
                                  color: primaryContainerColor.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: busy
                                ? const Padding(
                                    padding: EdgeInsets.all(9),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    playing
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.skip_next_rounded,
                        size: 22,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                      onPressed: service.next,
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        service.player.loopMode == LoopMode.one
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                        size: 18,
                        color: service.player.loopMode != LoopMode.off
                            ? primaryColor
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                      onPressed: service.cycleRepeat,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                // Timeline Progress Row with M3WavySlider
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

                    return Row(
                      children: [
                        Text(
                          _fmt(pos),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: M3WavySlider(
                            value: currentVal,
                            height: 24,
                            waveAmplitude: 3.0,
                            waveLength: 20.0,
                            trackThickness: 3.0,
                            thumbRadius: 5.5,
                            isPlaying: service.player.playing,
                            activeColor: primaryColor,
                            thumbColor: primaryColor,
                            inactiveColor: Colors.white.withValues(alpha: 0.16),
                            onChanged: (v) => setState(() => _dragValue = v),
                            onChangeEnd: (v) {
                              service.player.seek(
                                Duration(milliseconds: (totalMs * v).round()),
                              );
                              setState(() => _dragValue = null);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _fmt(total),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // ── Right: Queue, Lyrics, Volume, Expand ───────────────────
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.queue_music_rounded,
                    size: 20,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  tooltip: 'Queue',
                  onPressed:
                      widget.onToggleQueue ?? () => _openFullScreen(context),
                ),
                IconButton(
                  icon: Icon(
                    Icons.lyrics_rounded,
                    size: 20,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  tooltip: 'Lyrics',
                  onPressed: () => showLyricsOverlay(
                    context,
                    song.id,
                    Duration(seconds: song.durationSeconds),
                    title: song.title,
                    artist: song.artists,
                  ),
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
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
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
                IconButton(
                  icon: Icon(
                    Icons.fullscreen_rounded,
                    size: 22,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  tooltip: 'Fullscreen Player',
                  onPressed: () => _openFullScreen(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openFullScreen(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const PlayerScreen(),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }
}
