import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presentation/providers/core_providers.dart';
import 'presentation/screens/background_setup_screen.dart';
import 'presentation/screens/home_screen.dart';

class BgTubeApp extends ConsumerStatefulWidget {
  const BgTubeApp({super.key});

  @override
  ConsumerState<BgTubeApp> createState() => _BgTubeAppState();
}

class _BgTubeAppState extends ConsumerState<BgTubeApp> {
  late bool _showSetup =
      !ref.read(settingsRepositoryProvider).onboardingDone;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFFE53935);
    return MaterialApp(
      title: 'BgTube',
      debugShowCheckedModeBanner: false,
      // Dark by default; the light theme is used only if the system is light
      // and themeMode is changed to ThemeMode.system.
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
      ),
      home: _showSetup
          ? BackgroundSetupScreen(
              onDone: () => setState(() => _showSetup = false),
            )
          : const HomeScreen(),
    );
  }
}
