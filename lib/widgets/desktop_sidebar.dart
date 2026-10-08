import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/library_service.dart';
import '../services/room_service.dart';
import '../theme.dart';
import 'room_sheet.dart';
import 'song_actions.dart';

class DesktopSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelectTab;

  const DesktopSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelectTab,
  });

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryService>();
    final room = context.watch<RoomService>();
    final favCount = library.favorites.length;
    final playlistNames = library.playlistNames;

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          right: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── App Brand Header ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD0BCFF), Color(0xFF70F3DE)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD0BCFF).withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.graphic_eq_rounded,
                    color: Color(0xFF13111A),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hermosa',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    Text(
                      'Music Studio',
                      style: TextStyle(
                        color: AppColors.primary.withValues(alpha: 0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Primary Navigation ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                _NavTile(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  selected: selectedIndex == 0,
                  onTap: () => onSelectTab(0),
                ),
                const SizedBox(height: 4),
                _NavTile(
                  icon: Icons.search_rounded,
                  label: 'Search & Explore',
                  selected: selectedIndex == 1,
                  onTap: () => onSelectTab(1),
                ),
                const SizedBox(height: 4),
                _NavTile(
                  icon: Icons.library_music_rounded,
                  label: 'Your Library',
                  selected: selectedIndex == 2,
                  onTap: () => onSelectTab(2),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Listen Together / Live Room Banner ────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: InkWell(
              onTap: () => showRoomSheet(context),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: room.inRoom
                      ? const Color(0xFF5A4880).withValues(alpha: 0.35)
                      : Colors.white.withValues(alpha: 0.04),
                  border: Border.all(
                    color: room.inRoom
                        ? AppColors.primary.withValues(alpha: 0.4)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: room.inRoom
                            ? AppColors.primary
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                      child: Icon(
                        Icons.group_rounded,
                        size: 16,
                        color: room.inRoom ? Colors.black : Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            room.inRoom ? 'Room: ${room.roomCode}' : 'Listen Together',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            room.inRoom ? '${room.members.length} listening' : 'Sync with friends',
                            style: TextStyle(
                              color: room.inRoom ? AppColors.primary : Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Playlists Header ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'PLAYLISTS',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                InkWell(
                  onTap: () async {
                    final name = await promptPlaylistName(context);
                    if (name != null && context.mounted) {
                      context.read<LibraryService>().createPlaylist(name);
                    }
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.add_circle_outline_rounded,
                      color: AppColors.primary.withValues(alpha: 0.8),
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Playlists List ────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                // Liked Songs
                _PlaylistTile(
                  iconWidget: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF5A4880), Color(0xFFC9B8FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  title: 'Liked Songs',
                  subtitle: '$favCount tracks',
                  onTap: () {
                    onSelectTab(2);
                  },
                ),

                const SizedBox(height: 4),

                // User Custom Playlists
                for (final name in playlistNames)
                  _PlaylistTile(
                    iconWidget: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: AppColors.surfaceHigh,
                      ),
                      child: const Icon(
                        Icons.queue_music_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    title: name,
                    subtitle: 'Custom Playlist',
                    onTap: () {
                      onSelectTab(2);
                    },
                  ),
                if (playlistNames.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Text(
                      'Tap + to create your own playlists.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .35),
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected
              ? AppColors.primaryContainer.withValues(alpha: 0.65)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.25)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  final Widget iconWidget;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PlaylistTile({
    required this.iconWidget,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            iconWidget,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
