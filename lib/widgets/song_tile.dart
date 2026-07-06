import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/player_service.dart';
import '../theme.dart';
import 'cover_image.dart';
import 'song_actions.dart';

class SongTile extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  final Widget? trailing;

  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrent =
        context.watch<PlayerService>().current?.id == song.id;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: CoverImage(url: song.imageUrl, size: 52),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: isCurrent ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        '${song.artists} · ${song.durationLabel}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
      trailing: trailing ??
          IconButton(
            icon: const Icon(Icons.more_vert_rounded,
                color: AppColors.textSecondary),
            onPressed: () => showSongActions(context, song),
          ),
      onTap: onTap,
      onLongPress: () => showSongActions(context, song),
    );
  }
}
