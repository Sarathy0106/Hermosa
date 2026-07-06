import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/glass.dart';
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

  static const _tabs = [
    (Icons.home_outlined, Icons.home_rounded),
    (Icons.search_rounded, Icons.search_rounded),
    (Icons.library_music_outlined, Icons.library_music_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: const [HomeScreen(), SearchScreen(), LibraryScreen()],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MiniPlayer(),
            // Slim floating frosted-glass nav pill.
            Padding(
              padding: const EdgeInsets.fromLTRB(56, 2, 56, 10),
              child: Glass(
                borderRadius: BorderRadius.circular(27),
                tint: const Color(0xB30B0B12),
                blur: 26,
                child: SizedBox(
                  height: 54,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (var i = 0; i < _tabs.length; i++)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _index = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _index == i
                                  ? AppColors.primary
                                      .withValues(alpha: .20)
                                  : Colors.transparent,
                            ),
                            child: Icon(
                              _index == i ? _tabs[i].$2 : _tabs[i].$1,
                              size: 23,
                              color: _index == i
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
