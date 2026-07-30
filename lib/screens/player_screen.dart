import 'dart:ui';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../services/library_service.dart';
import '../services/player_service.dart';
import '../services/room_service.dart';
import '../services/theme_provider.dart';
import '../widgets/cover_image.dart';
import '../widgets/glass.dart';
import '../widgets/lyrics_viewer.dart';
import '../widgets/room_sheet.dart';
import '../widgets/sleep_timer_sheet.dart';
import '../widgets/song_actions.dart';
import '../widgets/wave_slider.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<PlayerService>();
    final library = context.watch<LibraryService>();
    final h = context.hermosa;
    final song = service.current;
    if (song == null) {
      // Queue ended or cleared while this screen was open.
      return const Scaffold(body: SizedBox.shrink());
    }
    final fav = library.isFavorite(song.id);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Blurred artwork backdrop
          if (song.imageUrl.isNotEmpty)
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: CachedNetworkImage(
                  imageUrl: song.imageUrl, fit: BoxFit.cover),
            ),
          Container(color: h.bg.withValues(alpha: .72)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Center(
                          child: Text('NOW PLAYING',
                              style: TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 3,
                                  color: h.textSecondary,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.lyrics_rounded),
                        onPressed: () => showLyricsOverlay(
                          context,
                          song.id,
                          Duration(seconds: song.durationSeconds),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert_rounded),
                        onPressed: () => showSongActions(context, song),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Artwork
                  Flexible(
                    child: Center(
                      child: LayoutBuilder(builder: (context, constraints) {
                        final widthBasedSize =
                            MediaQuery.of(context).size.width - 72;
                        final size = math.min(
                          widthBasedSize,
                          constraints.maxHeight,
                        );
                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .55),
                                blurRadius: 44,
                                offset: const Offset(0, 18),
                              ),
                            ],
                          ),
                          child: CoverImage(
                            url: song.imageUrl,
                            size: size,
                            radius: 28,
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Glass panel: song info + waveform + transport controls
                  Glass(
                    borderRadius: BorderRadius.circular(28),
                    tint: Colors.white.withValues(alpha: .05),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                  // Title / artist + favourite
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall),
                            const SizedBox(height: 4),
                            Text(song.artists,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
style: TextStyle(
                                     color: h.textSecondary,
                                     fontSize: 15)),
                          ],
                        ),
                      ),
                      IconButton(
                        iconSize: 26,
                        icon: Icon(
                          fav
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: fav
                              ? h.danger
                              : h.textPrimary,
                        ),
                        onPressed: () => library.toggleFavorite(song),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Seek bar
                  StreamBuilder<Duration>(
                    stream: service.player.positionStream,
                    builder: (context, posSnap) {
                      final pos = posSnap.data ?? Duration.zero;
                      final total = service.player.duration ??
                          Duration(seconds: song.durationSeconds);
                      return StreamBuilder<Duration>(
                        stream: service.player.bufferedPositionStream,
                        builder: (context, bufSnap) {
                          return Column(
                            children: [
                              WaveformSeekBar(
                                seed: song.id,
                                position: pos,
                                buffered: bufSnap.data ?? Duration.zero,
                                total: total,
                                onSeek: service.player.seek,
                              ),
                              const SizedBox(height: 6),
Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_fmt(pos),
                                        style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                h.textSecondary)),
                                    Text(_fmt(total),
                                        style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                h.textSecondary)),
                                  ],
                                ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  // Transport controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _RoundIcon(
                        icon: Icons.shuffle_rounded,
                        size: 40,
                        iconSize: 18,
                        active: service.player.shuffleModeEnabled,
                        onTap: service.toggleShuffle,
                      ),
                      _RoundIcon(
                        icon: Icons.skip_previous_rounded,
                        size: 52,
                        iconSize: 28,
                        onTap: service.previous,
                      ),
                      StreamBuilder<PlayerState>(
                        stream: service.player.playerStateStream,
                        builder: (context, snap) {
                          final state = snap.data;
                          final playing = state?.playing ?? false;
                          final processing = state?.processingState;
                          final busy = processing ==
                                  ProcessingState.loading ||
                              processing == ProcessingState.buffering;
                          return GestureDetector(
                            onTap: service.togglePlay,
                            child: Container(
                              width: 66,
                              height: 66,
decoration: BoxDecoration(
                                 shape: BoxShape.circle,
                                 gradient: h.heroGradient,
                               ),
                              child: busy
                                  ? const Padding(
                                      padding: EdgeInsets.all(20),
                                      child: CircularProgressIndicator(
                                          strokeWidth: 3,
                                          color: Colors.white),
                                    )
                                  : Icon(
                                      playing
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      size: 36,
                                      color: Colors.white,
                                    ),
                            ),
                          );
                        },
                      ),
                      _RoundIcon(
                        icon: Icons.skip_next_rounded,
                        size: 52,
                        iconSize: 28,
                        onTap: service.next,
                      ),
                      _RoundIcon(
                        icon: service.player.loopMode == LoopMode.one
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                        size: 40,
                        iconSize: 18,
                        active: service.player.loopMode != LoopMode.off,
                        onTap: service.cycleRepeat,
                      ),
                    ],
                  ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Queue & Sleep Timer
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => _showQueue(context),
                          icon: Icon(Icons.queue_music_rounded,
                              size: 20, color: h.textSecondary),
                          label: Text('Up next',
                              style: TextStyle(
                                  color: h.textSecondary)),
                        ),
                      ),
                      Expanded(
                        child: _SpeedButton(service: service),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => showRoomSheet(context),
                          icon: Icon(Icons.group_rounded,
                              size: 20, color: h.textSecondary),
                          label: Text('Room',
                              style: TextStyle(
                                  color: h.textSecondary)),
                        ),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => showSleepTimerSheet(context),
                          icon: Icon(Icons.bedtime_rounded,
                              size: 20, color: h.textSecondary),
                          label: Text('Sleep',
                              style: TextStyle(
                                  color: h.textSecondary)),
                        ),
                      ),
                    ],
                  ),
                  _RoomIndicator(),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showQueue(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (ctx, scrollController) {
            final service = ctx.watch<PlayerService>();
            final queue = service.queue;
            final currentIndex = service.player.currentIndex ?? 0;
            final h = ctx.hermosa;
            return Glass(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              tint: const Color(0xD912121C),
              blur: 28,
              child: Column(
                children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('Up next (${queue.length})',
                      style: Theme.of(ctx).textTheme.titleLarge),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: queue.length,
                    itemBuilder: (ctx2, i) {
                      final s = queue[i];
                      final isCurrent = i == currentIndex;
                      return ListTile(
leading: CoverImage(url: s.imageUrl, size: 44),
                        title: Text(s.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isCurrent
                                    ? h.primary
                                    : h.textPrimary)),
                        subtitle: Text(s.artists,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color: h.textSecondary)),
                        trailing: isCurrent
                            ? Icon(Icons.graphic_eq_rounded,
                                color: h.primary)
                            : IconButton(
                                icon: Icon(Icons.close_rounded,
                                    size: 18,
                                    color: h.textSecondary),
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
        );
      },
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final bool active;
  final VoidCallback onTap;

  const _RoundIcon({
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final h = context.hermosa;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active
              ? h.accent.withValues(alpha: .16)
              : Colors.white.withValues(alpha: .07),
          border: Border.all(
            color: active
                ? h.accent.withValues(alpha: .45)
                : Colors.white.withValues(alpha: .08),
          ),
        ),
        child: Icon(icon,
            size: iconSize,
            color: active ? h.accent : h.textPrimary),
      ),
    );
  }
}

class _RoomIndicator extends StatelessWidget {
  const _RoomIndicator();

  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomService>();
    if (!room.inRoom) return const SizedBox.shrink();

    final h = context.hermosa;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.group_rounded, size: 14, color: h.primary),
          const SizedBox(width: 4),
          Text(room.roomCode ?? '',
              style: TextStyle(fontSize: 12, color: h.primary, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: h.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('${room.members.length}',
                style: TextStyle(fontSize: 11, color: h.primary)),
          ),
        ],
      ),
    );
  }
}

class _SpeedButton extends StatelessWidget {
  final PlayerService service;
  const _SpeedButton({required this.service});

  @override
  Widget build(BuildContext context) {
    final h = context.hermosa;
    final currentSpeed = service.player.speed;

    return PopupMenuButton<double>(
      offset: const Offset(0, -240),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: h.surface,
      elevation: 8,
      onSelected: (speed) => service.player.setSpeed(speed),
      itemBuilder: (_) => [
        for (final speed in [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0])
          PopupMenuItem(
            value: speed,
            child: Row(
              children: [
                Icon(
                  speed == currentSpeed ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: 18,
                  color: speed == currentSpeed ? h.primary : h.textSecondary,
                ),
                const SizedBox(width: 12),
                Text(
                  speed == 1.0 ? 'Normal' : '${speed}x',
                  style: TextStyle(
                    fontWeight: speed == currentSpeed ? FontWeight.w600 : FontWeight.w400,
                    color: speed == currentSpeed ? h.primary : h.textPrimary,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.speed_rounded, size: 18, color: h.textSecondary),
              const SizedBox(width: 4),
              Text(
                currentSpeed == 1.0 ? '1x' : '${currentSpeed}x',
                style: TextStyle(fontSize: 12, color: h.textSecondary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
