import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';

import 'screens/root_screen.dart';
import 'services/library_service.dart';
import 'services/player_service.dart';
import 'services/saavn_api.dart';
import 'theme.dart';

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
  final player = PlayerService();

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
      ],
      child: const HermosaApp(),
    ),
  );
}

class HermosaApp extends StatelessWidget {
  const HermosaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hermosa',
      debugShowCheckedModeBanner: false,
      theme: buildHermosaTheme(),
      home: const RootScreen(),
    );
  }
}
