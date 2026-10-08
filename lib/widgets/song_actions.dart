import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/download_service.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../services/recommendation_service.dart';
import '../theme.dart';
import 'cover_image.dart';
import 'glass.dart';

void showSongActions(BuildContext context, Song song) {
  showGlassSheet(
    context: context,
    builder: (sheetCtx) {
      final library = sheetCtx.watch<LibraryService>();
      final player = sheetCtx.read<PlayerService>();
      final downloads = sheetCtx.watch<DownloadService>();
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
            StreamBuilder<DownloadProgress>(
              stream: downloads.downloadStream(song.id),
              builder: (ctx, snap) {
                final downloaded = downloads.isDownloaded(song.id);
                final inProgress = snap.hasData && !snap.data!.done && snap.data!.error == null;
                final error = snap.data?.error;

                if (error != null) {
                  return ListTile(
                    leading: const Icon(Icons.error_outline_rounded, color: AppColors.danger),
                    title: const Text('Download failed'),
                    subtitle: Text(error, style: const TextStyle(fontSize: 11)),
                  );
                }

                if (inProgress) {
                  final p = snap.data!;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        ),
                        const SizedBox(width: 16),
                        Text('Downloading ${(p.fraction * 100).round()}%'),
                      ],
                    ),
                  );
                }

                return ListTile(
                  leading: Icon(
                    downloaded ? Icons.cloud_done_rounded : Icons.download_rounded,
                    color: downloaded ? AppColors.primary : AppColors.textPrimary,
                  ),
                  title: Text(downloaded ? 'Remove download' : 'Download'),
                  onTap: () {
                    if (downloaded) {
                      downloads.deleteDownload(song.id);
                    } else {
                      downloads.download(song);
                    }
                    Navigator.pop(sheetCtx);
                  },
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.radio_rounded, color: AppColors.primary),
              title: const Text('Start song radio'),
              subtitle: const Text('Play smart recommendations for this song',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              onTap: () async {
                Navigator.pop(sheetCtx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Starting ${song.title} Radio...'),
                  duration: const Duration(seconds: 1),
                ));
                final recommender = context.read<RecommendationService>();
                final radioSongs = await recommender.getSongRadio(song);
                if (context.mounted && radioSongs.isNotEmpty) {
                  context.read<PlayerService>().playAll(radioSongs);
                }
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
