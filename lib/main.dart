import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'audio/audio_handler.dart';
import 'audio/player_controller.dart';
import 'state/favorites.dart';
import 'state/playlists.dart';
import 'state/session.dart';
import 'ui/navigation.dart';
import 'ui/screens/login_screen.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // just_audio has no native Windows/Linux backend; use libmpv via media_kit.
  JustAudioMediaKit.ensureInitialized();

  final session = SessionController();
  final player = PlayerController();
  final favorites = FavoritesController();
  final playlists = PlaylistsController();

  try {
    await AudioService.init(
      builder: () => JewelcaseAudioHandler(player, () => session.isSignedIn ? session.client : null),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'app.jewelcase.player.playback',
        androidNotificationChannelName: 'Playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  } catch (e) {
    debugPrint('Media session unavailable: $e');
  }

  session.addListener(() {
    final client = session.isSignedIn ? session.client : null;
    player.attach(client);
    favorites.attach(client);
    playlists.attach(client);
  });
  unawaited(session.restore());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: session),
        ChangeNotifierProvider.value(value: player),
        ChangeNotifierProvider.value(value: favorites),
        ChangeNotifierProvider.value(value: playlists),
        ChangeNotifierProvider(create: (_) => NavController()),
      ],
      child: const JewelcaseApp(),
    ),
  );
}

class JewelcaseApp extends StatelessWidget {
  const JewelcaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = context.read<NavController>();
    return MaterialApp(
      title: 'Jewelcase',
      debugShowCheckedModeBanner: false,
      navigatorKey: nav.rootKey,
      theme: buildTheme(),
      builder: (context, child) => PlaybackShortcuts(child: child!),
      home: const _Gate(),
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final Widget child;
    if (session.isRestoring) {
      child = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else if (!session.isSignedIn) {
      child = const LoginScreen();
    } else {
      // Keyed by server so signing into another account starts fresh.
      child = AppShell(key: ValueKey(session.credentials!.baseUrl + session.credentials!.username));
    }
    return AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: child);
  }
}
