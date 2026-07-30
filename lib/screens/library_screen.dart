import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/download_service.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../theme.dart';
import '../widgets/song_actions.dart';
import '../widgets/song_tile.dart';
import 'theme_builder_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryService>();
    final downloads = context.watch<DownloadService>();
    final favorites = library.favorites;
    final playlists = library.playlistNames;
    final downloadedSongs = downloads.downloadedSongs;

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
                  tooltip: 'New playlist',
                ),
              ],
            ),
          ),
          // Collection cards row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(child: _CollectionCard(
                  icon: Icons.favorite_rounded,
                  label: 'Favourites',
                  count: favorites.length,
                  color: AppColors.primary,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const _FavoritesScreen())),
                )),
                const SizedBox(width: 12),
                Expanded(child: _CollectionCard(
                  icon: Icons.download_rounded,
                  label: 'Downloads',
                  count: downloadedSongs.length,
                  color: AppColors.accent,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const _DownloadsScreen())),
                )),
              ],
            ),
          ),
          // Playlists section
          const SizedBox(height: 28),
          _SectionHeader(
            icon: Icons.queue_music_rounded,
            title: 'Playlists',
            trailing: TextButton.icon(
              onPressed: () async {
                final name = await promptPlaylistName(context);
                if (name != null && context.mounted) {
                  final ok = context.read<LibraryService>().createPlaylist(name);
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Playlist already exists')));
                  }
                }
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('New'),
            ),
          ),
          if (playlists.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.queue_music_rounded, size: 48, color: AppColors.textSecondary),
                    SizedBox(height: 12),
                    Text('No playlists yet',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                    SizedBox(height: 4),
                    Text('Tap + to create your first playlist',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ...playlists.map((name) {
            final songs = library.playlistSongs(name);
            return _PlaylistTile(
              name: name,
              count: songs.length,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => _UserPlaylistScreen(name: name))),
              onDelete: () => showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppColors.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Text('Delete "$name"?'),
                  content: const Text('This playlist will be removed.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                      onPressed: () {
                        context.read<LibraryService>().deletePlaylist(name);
                        Navigator.pop(ctx);
                      },
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ),
            );
          }),
          // Settings
          const SizedBox(height: 20),
          _SectionHeader(
            icon: Icons.settings_rounded,
            title: 'Settings',
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ThemeBuilderScreen()),
              ),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.palette_rounded, color: AppColors.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text('Theme, colors, density & typography',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;

  const _SectionHeader({
    required this.icon,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title,
                style: Theme.of(context).textTheme.titleLarge),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;

  const _CollectionCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: .25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: .6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 14),
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text('$count songs',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  final String name;
  final int count;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PlaylistTile({
    required this.name,
    required this.count,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 54, height: 54,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.queue_music_rounded, color: AppColors.primary),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('$count songs',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.textSecondary),
        onPressed: onDelete,
      ),
      onTap: onTap,
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

class _DownloadsScreen extends StatelessWidget {
  const _DownloadsScreen();

  @override
  Widget build(BuildContext context) {
    final downloads = context.watch<DownloadService>();
    final songs = downloads.downloadedSongs;
    return Scaffold(
      appBar: AppBar(title: const Text('Downloads')),
      body: songs.isEmpty
          ? const Center(
              child: Text('Downloaded songs will appear here',
                  style: TextStyle(color: AppColors.textSecondary)))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Row(
                    children: [
                      Text('${songs.length} songs',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
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
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: AppColors.textSecondary),
                        onPressed: () => downloads.deleteDownload(songs[i].id),
                      ),
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
