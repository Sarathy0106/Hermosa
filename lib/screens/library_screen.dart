import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/download_service.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../theme.dart';
import '../widgets/song_actions.dart';
import '../widgets/song_tile.dart';
import 'theme_builder_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _tabIndex = 0; // 0=Favorites, 1=Playlists, 2=History, 3=Downloads

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryService>();
    final downloads = context.watch<DownloadService>();
    final player = context.watch<PlayerService>();

    final favorites = library.favorites;
    final playlists = library.playlistNames;
    final history = library.history;
    final downloaded = downloads.downloadedSongs;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header Row ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Your Library',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ThemeBuilderScreen(),
                          ),
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surfaceHigh,
                        ),
                        tooltip: 'Customize Theme',
                        icon: const Icon(
                          Icons.palette_rounded,
                          size: 20,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: () => _createPlaylistDialog(context),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: const Color(0xFF13111A),
                        ),
                        tooltip: 'New Playlist',
                        icon: const Icon(Icons.add_rounded, size: 22),
                      ),
                    ],
                  ),
                ),

                // ── Segmented Category Filter Bar ───────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterPill(
                          index: 0,
                          icon: Icons.favorite_rounded,
                          label: 'Liked (${favorites.length})',
                        ),
                        const SizedBox(width: 8),
                        _buildFilterPill(
                          index: 1,
                          icon: Icons.queue_music_rounded,
                          label: 'Playlists (${playlists.length})',
                        ),
                        const SizedBox(width: 8),
                        _buildFilterPill(
                          index: 2,
                          icon: Icons.history_rounded,
                          label: 'History (${history.length})',
                        ),
                        const SizedBox(width: 8),
                        _buildFilterPill(
                          index: 3,
                          icon: Icons.download_done_rounded,
                          label: 'Downloads (${downloaded.length})',
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ── Tab Content ─────────────────────────────────────
                Expanded(
                  child: IndexedStack(
                    index: _tabIndex,
                    children: [
                      // 0: Favorites
                      _buildFavoritesView(favorites, player),

                      // 1: Playlists
                      _buildPlaylistsView(library, playlists),

                      // 2: History
                      _buildHistoryView(library, history, player),

                      // 3: Downloads
                      _buildDownloadsView(downloads, downloaded, player),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPill({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryContainer : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesView(List<dynamic> favorites, PlayerService player) {
    if (favorites.isEmpty) {
      return _buildEmptyState(
        icon: Icons.favorite_border_rounded,
        title: 'No liked songs yet',
        subtitle: 'Tap the heart icon on any track to save it here.',
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Row(
            children: [
              Text(
                '${favorites.length} saved songs',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: const Color(0xFF13111A),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  minimumSize: const Size(0, 36),
                ),
                onPressed: () => player.playAll(favorites.cast()),
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: const Text('Play All', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 120),
            itemCount: favorites.length,
            itemBuilder: (context, i) => SongTile(
              song: favorites[i],
              onTap: () => player.playAll(favorites.cast(), startIndex: i),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaylistsView(LibraryService library, List<String> playlists) {
    if (playlists.isEmpty) {
      return _buildEmptyState(
        icon: Icons.queue_music_rounded,
        title: 'No custom playlists yet',
        subtitle: 'Create a playlist to organize your favorite tunes.',
        actionLabel: 'Create Playlist',
        onAction: () => _createPlaylistDialog(context),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
      itemCount: playlists.length,
      itemBuilder: (context, i) {
        final name = playlists[i];
        final songs = library.playlistSongs(name);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5A4880), Color(0xFFC9B8FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.queue_music_rounded, color: Colors.white, size: 22),
            ),
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: Text(
              '${songs.length} tracks',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            trailing: PopupMenuButton(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white60),
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  child: const Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 18),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: AppColors.danger)),
                    ],
                  ),
                  onTap: () => library.deletePlaylist(name),
                ),
              ],
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _UserPlaylistScreen(name: name),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryView(
    LibraryService library,
    List<dynamic> history,
    PlayerService player,
  ) {
    if (history.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history_rounded,
        title: 'Listening history is clear',
        subtitle: 'Songs you stream will automatically appear here.',
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Row(
            children: [
              Text(
                '${history.length} recently played tracks',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => library.clearHistory(),
                icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                label: const Text('Clear', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 120),
            itemCount: history.length,
            itemBuilder: (context, i) => SongTile(
              song: history[i],
              onTap: () => player.playAll(history.cast(), startIndex: i),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadsView(
    DownloadService downloads,
    List<dynamic> downloaded,
    PlayerService player,
  ) {
    if (downloaded.isEmpty) {
      return _buildEmptyState(
        icon: Icons.download_for_offline_rounded,
        title: 'No downloaded tracks',
        subtitle: 'Download songs for offline listening from any track menu.',
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Row(
            children: [
              Text(
                '${downloaded.length} offline tracks',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: const Color(0xFF13111A),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  minimumSize: const Size(0, 36),
                ),
                onPressed: () => player.playAll(downloaded.cast()),
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: const Text('Play All', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 120),
            itemCount: downloaded.length,
            itemBuilder: (context, i) => SongTile(
              song: downloaded[i],
              onTap: () => player.playAll(downloaded.cast(), startIndex: i),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.white54),
                onPressed: () => downloads.deleteDownload(downloaded[i].id),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: Colors.white24),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _createPlaylistDialog(BuildContext context) async {
    final name = await promptPlaylistName(context);
    if (name != null && context.mounted) {
      final ok = context.read<LibraryService>().createPlaylist(name);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Playlist already exists')),
        );
      }
    }
  }
}

class _UserPlaylistScreen extends StatelessWidget {
  final String name;

  const _UserPlaylistScreen({required this.name});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryService>();
    final player = context.watch<PlayerService>();
    final songs = library.playlistSongs(name);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(name)),
      body: songs.isEmpty
          ? const Center(
              child: Text(
                'Empty playlist.\nAdd tracks using the ⋮ menu on any song.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Row(
                    children: [
                      Text(
                        '${songs.length} tracks',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: const Color(0xFF13111A),
                        ),
                        onPressed: () => player.playAll(songs),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Play All'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 120),
                    itemCount: songs.length,
                    itemBuilder: (context, i) => SongTile(
                      song: songs[i],
                      onTap: () => player.playAll(songs, startIndex: i),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline_rounded,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => library.removeFromPlaylist(name, songs[i].id),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
