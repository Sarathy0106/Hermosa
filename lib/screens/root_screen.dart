import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/bottom_player_bar.dart';
import '../widgets/desktop_sidebar.dart';
import '../widgets/mini_player.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'search_screen.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 840;

        if (isDesktop) {
          // ── Desktop Studio Layout matching reference ──────────────
          return Scaffold(
            backgroundColor: AppColors.bg,
            body: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      DesktopSidebar(
                        selectedIndex: _index,
                        onSelectTab: (i) => setState(() => _index = i),
                      ),
                      Expanded(
                        child: IndexedStack(
                          index: _index,
                          children: [
                            HomeScreen(
                              onSearch: (query) {
                                setState(() {
                                  _searchQuery = query;
                                  _index = 1;
                                });
                              },
                            ),
                            SearchScreen(
                              key: ValueKey(_searchQuery),
                              initialQuery: _searchQuery,
                            ),
                            const LibraryScreen(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const BottomPlayerBar(),
              ],
            ),
          );
        }

        // ── Mobile Compact Layout ───────────────────────────────────
        return Scaffold(
          extendBody: false,
          body: IndexedStack(
            index: _index,
            children: const [HomeScreen(), SearchScreen(), LibraryScreen()],
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MiniPlayer(),
              NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (value) =>
                    setState(() => _index = value),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.search_rounded),
                    selectedIcon: Icon(Icons.manage_search_rounded),
                    label: 'Search',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.library_music_outlined),
                    selectedIcon: Icon(Icons.library_music_rounded),
                    label: 'Library',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
