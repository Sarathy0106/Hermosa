import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../screens/player_screen.dart';
import '../services/player_service.dart';
import '../theme.dart';
import 'cover_image.dart';

/// Docked bar above the bottom navigation showing the current song.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<PlayerService>();
    final song = service.current;
    if (song == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => const PlayerScreen(),
          transitionsBuilder: (_, anim, _, child) => SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                .animate(CurvedAnimation(
                    parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 320),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .45),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh.withValues(alpha: .82),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: Colors.white.withValues(alpha: .06)),
              ),
              child: _MiniPlayerBody(service: service, song: song),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniPlayerBody extends StatelessWidget {
  final PlayerService service;
  final Song song;

  const _MiniPlayerBody({required this.service, required this.song});

  @override
  Widget build(BuildContext context) {
    return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CoverImage(url: song.imageUrl, size: 44, radius: 10),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(song.artists,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                StreamBuilder<PlayerState>(
                  stream: service.player.playerStateStream,
                  builder: (context, snap) {
                    final state = snap.data;
                    final processing = state?.processingState;
                    final playing = state?.playing ?? false;
                    if (processing == ProcessingState.loading ||
                        processing == ProcessingState.buffering) {
                      return const SizedBox(
                        width: 40,
                        height: 40,
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary),
                        ),
                      );
                    }
                    return IconButton(
                      icon: Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 30,
                      ),
                      onPressed: service.togglePlay,
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded, size: 28),
                  onPressed: service.next,
                ),
              ],
            ),
            const SizedBox(height: 6),
            StreamBuilder<Duration>(
              stream: service.player.positionStream,
              builder: (context, snap) {
                final pos = snap.data ?? Duration.zero;
                final total = service.player.duration ?? Duration.zero;
                final value = total.inMilliseconds == 0
                    ? 0.0
                    : (pos.inMilliseconds / total.inMilliseconds)
                        .clamp(0.0, 1.0);
                return ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: ShaderMask(
                    shaderCallback: (rect) => const LinearGradient(
                      colors: [AppColors.primary, AppColors.accent],
                    ).createShader(rect),
                    blendMode: BlendMode.srcATop,
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 3,
                      backgroundColor:
                          Colors.white.withValues(alpha: .08),
                      valueColor:
                          const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                );
              },
            ),
      ],
    );
  }
}
