import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/library_service.dart';
import '../services/player_service.dart';
import '../theme.dart';
import '../widgets/song_actions.dart';
import '../widgets/song_tile.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryService>();
    final favorites = library.favorites;
    final playlists = library.playlistNames;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 160),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text('Your library',
                      style: Theme.of(context).textTheme.headlineMedium),
                ),
                IconButton(
                  icon: const Icon(Icons.add_rounded,
                      color: AppColors.primary, size: 28),
                  onPressed: () async {
                    final name = await promptPlaylistName(context);
                    if (name != null && context.mounted) {
                      final ok = context
                          .read<LibraryService>()
                          .createPlaylist(name);
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Playlist already exists')));
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          // Favourites card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const _FavoritesScreen()),
              ),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: .30),
                      AppColors.accent.withValues(alpha: .16),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: AppColors.heroGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.favorite_rounded,
                          color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Favourites',
                              style:
                                  Theme.of(context).textTheme.titleLarge),
                          Text('${favorites.length} songs',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (playlists.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 32, 20, 0),
              child: Center(
                child: Text(
                  'No playlists yet.\nTap + to create one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          ...playlists.map((name) {
            final songs = library.playlistSongs(name);
            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              leading: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.queue_music_rounded,
                    color: AppColors.primary),
              ),
              title: Text(name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${songs.length} songs',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.textSecondary),
                onPressed: () => showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    title: Text('Delete "$name"?'),
                    content:
                        const Text('This playlist will be removed.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel')),
                      FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.danger),
                        onPressed: () {
                          context
                              .read<LibraryService>()
                              .deletePlaylist(name);
                          Navigator.pop(ctx);
                        },
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                ),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => _UserPlaylistScreen(name: name)),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _FavoritesScreen extends StatelessWidget {
  const _FavoritesScreen();

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<LibraryService>().favorites;
    return Scaffold(
      appBar: AppBar(title: const Text('Favourites')),
      body: favorites.isEmpty
          ? const Center(
              child: Text('Songs you like will appear here',
                  style: TextStyle(color: AppColors.textSecondary)))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Row(
                    children: [
                      Text('${favorites.length} songs',
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13)),
                      const Spacer(),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black),
                        onPressed: () => context
                            .read<PlayerService>()
                            .playAll(favorites),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Play all'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 160),
                    itemCount: favorites.length,
                    itemBuilder: (context, i) => SongTile(
                      song: favorites[i],
                      onTap: () => context
                          .read<PlayerService>()
                          .playAll(favorites, startIndex: i),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _UserPlaylistScreen extends StatelessWidget {
  final String name;

  const _UserPlaylistScreen({required this.name});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryService>();
    final songs = library.playlistSongs(name);
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: songs.isEmpty
          ? const Center(
              child: Text(
                  'Empty playlist.\nAdd songs from the ⋮ menu on any track.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary)))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Row(
                    children: [
                      Text('${songs.length} songs',
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13)),
                      const Spacer(),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black),
                        onPressed: () =>
                            context.read<PlayerService>().playAll(songs),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Play all'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 160),
                    itemCount: songs.length,
                    itemBuilder: (context, i) => SongTile(
                      song: songs[i],
                      onTap: () => context
                          .read<PlayerService>()
                          .playAll(songs, startIndex: i),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded,
                            color: AppColors.textSecondary),
                        onPressed: () => context
                            .read<LibraryService>()
                            .removeFromPlaylist(name, songs[i].id),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
