import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../theme.dart';
import 'cover_image.dart';
import 'song_actions.dart';

class SongTile extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  final Widget? trailing;
  final int? index;

  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.trailing,
    this.index,
  });

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final library = context.watch<LibraryService>();
    final isCurrent = player.current?.id == song.id;
    final isPlaying = isCurrent && player.player.playing;
    final isFav = library.isFavorite(song.id);

    return InkWell(
      onTap: onTap,
      onLongPress: () => showSongActions(context, song),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isCurrent
              ? AppColors.primaryContainer.withValues(alpha: 0.35)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrent
                ? AppColors.primary.withValues(alpha: 0.35)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            if (index != null)
              SizedBox(
                width: 28,
                child: Text(
                  '$index',
                  style: TextStyle(
                    color: isCurrent ? AppColors.primary : AppColors.textTertiary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

            // Artwork with playing overlay
            Stack(
              alignment: Alignment.center,
              children: [
                CoverImage(url: song.imageUrl, size: 50, radius: 12),
                if (isCurrent)
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.black.withValues(alpha: 0.45),
                    ),
                    child: Center(
                      child: Icon(
                        isPlaying
                            ? Icons.graphic_eq_rounded
                            : Icons.play_arrow_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 14),

            // Title & Artist
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 14,
                      color: isCurrent ? AppColors.primary : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${song.artists} • ${song.durationLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrent
                          ? Colors.white.withValues(alpha: 0.8)
                          : AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Quick favorite heart
            IconButton(
              icon: Icon(
                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isFav ? const Color(0xFFFF5252) : Colors.white38,
                size: 20,
              ),
              onPressed: () => library.toggleFavorite(song),
            ),

            // More options or custom trailing
            trailing ??
                IconButton(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white60,
                    size: 20,
                  ),
                  onPressed: () => showSongActions(context, song),
                ),
          ],
        ),
      ),
    );
  }
}
