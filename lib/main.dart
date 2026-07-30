import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';

import 'screens/root_screen.dart';
import 'services/download_service.dart';
import 'services/library_service.dart';
import 'services/player_service.dart';
import 'services/room_service.dart';
import 'services/saavn_api.dart';
import 'services/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Media notification + lock-screen controls + background playback.
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.sarathy.hermosa.channel.audio',
    androidNotificationChannelName: 'Hermosa playback',
    androidNotificationOngoing: true,
    androidNotificationIcon: 'drawable/ic_stat_hermosa',
    notificationColor: const Color(0xFF9B7BFF),
    preloadArtwork: true,
  );

  final library = await LibraryService.init();
  final api = await SaavnApi.init();
  final downloads = await DownloadService.init();
  final player = PlayerService(downloads: downloads);
  await Hive.openBox('room_prefs');
  final room = RoomService(player);
  final theme = ThemeProvider();
  await theme.init();

  // Record listening history as tracks change.
  player.player.currentIndexStream.listen((i) {
    final song = player.current;
    if (song != null) library.addHistory(song);
  });

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: api),
        ChangeNotifierProvider.value(value: player),
        ChangeNotifierProvider.value(value: library),
        ChangeNotifierProvider.value(value: downloads),
        ChangeNotifierProvider.value(value: room),
        ChangeNotifierProvider.value(value: theme),
      ],
      child: const HermosaApp(),
    ),
  );
}

class HermosaApp extends StatelessWidget {
  const HermosaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, theme, _) {
        return MaterialApp(
          title: 'Hermosa',
          debugShowCheckedModeBanner: false,
          theme: theme.buildTheme(),
          home: const RootScreen(),
        );
      },
    );
  }
}