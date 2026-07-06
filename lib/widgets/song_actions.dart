import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../theme.dart';
import 'cover_image.dart';
import 'glass.dart';

void showSongActions(BuildContext context, Song song) {
  showGlassSheet(
    context: context,
    builder: (sheetCtx) {
      final library = sheetCtx.watch<LibraryService>();
      final player = sheetCtx.read<PlayerService>();
      final fav = library.isFavorite(song.id);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  CoverImage(url: song.imageUrl, size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(sheetCtx).textTheme.titleMedium),
                        Text(song.artists,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.surfaceHigh, height: 20),
            ListTile(
              leading: Icon(
                fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: fav ? AppColors.danger : AppColors.textPrimary,
              ),
              title: Text(fav ? 'Remove from favourites' : 'Add to favourites'),
              onTap: () {
                library.toggleFavorite(song);
                Navigator.pop(sheetCtx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add_rounded),
              title: const Text('Add to playlist'),
              onTap: () {
                Navigator.pop(sheetCtx);
                showAddToPlaylist(context, song);
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_play_next_rounded),
              title: const Text('Play next'),
              onTap: () {
                player.playNext(song);
                Navigator.pop(sheetCtx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_to_queue_rounded),
              title: const Text('Add to queue'),
              onTap: () {
                player.addToQueue(song);
                Navigator.pop(sheetCtx);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

void showAddToPlaylist(BuildContext context, Song song) {
  showGlassSheet(
    context: context,
    builder: (sheetCtx) {
      final library = sheetCtx.watch<LibraryService>();
      final names = library.playlistNames;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text('Add to playlist',
                      style: Theme.of(sheetCtx).textTheme.titleLarge),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      final name = await promptPlaylistName(context);
                      if (name != null && sheetCtx.mounted) {
                        sheetCtx.read<LibraryService>().createPlaylist(name);
                      }
                    },
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('New'),
                  ),
                ],
              ),
            ),
            if (names.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 32),
                child: Text('No playlists yet — create one!',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            ...names.map(
              (name) => ListTile(
                leading: const Icon(Icons.queue_music_rounded,
                    color: AppColors.primary),
                title: Text(name),
                subtitle: Text('${library.playlistSongs(name).length} songs',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
                onTap: () {
                  final added = library.addToPlaylist(name, song);
                  Navigator.pop(sheetCtx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(added
                        ? 'Added to "$name"'
                        : 'Already in "$name"'),
                  ));
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

Future<String?> promptPlaylistName(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('New playlist'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Playlist name'),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: const Text('Create'),
        ),
      ],
    ),
  ).then((v) => (v == null || v.isEmpty) ? null : v);
}
