import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';

import 'app.dart';
import 'data/repositories/library_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/youtube_repository.dart';
import 'data/services/audio_handler.dart';
import 'data/services/youtube_service.dart';
import 'presentation/providers/core_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // In debug builds, print youtube_explode_dart's internal log so stream
  // extraction problems can be diagnosed with `flutter run` or logcat.
  if (kDebugMode) {
    Logger.root.level = Level.FINE;
    Logger.root.onRecord.listen((r) {
      debugPrint('[${r.loggerName}] ${r.message}${r.error != null ? ' ${r.error}' : ''}');
    });
  }

  // Local storage first, because the audio handler writes to history.
  await Hive.initFlutter();
  final library = await LibraryRepository.open();
  final settings = await SettingsRepository.open();

  final youtube = YoutubeRepository(YoutubeService());

  // Starts the background audio service. It must finish before runApp so
  // the notification and lock-screen controls are ready immediately.
  final audioHandler =
      await initAudioHandler(youtube: youtube, library: library);

  runApp(
    ProviderScope(
      overrides: [
        youtubeRepositoryProvider.overrideWithValue(youtube),
        libraryRepositoryProvider.overrideWithValue(library),
        settingsRepositoryProvider.overrideWithValue(settings),
        audioHandlerProvider.overrideWithValue(audioHandler),
      ],
      // Riverpod 3 retries failed providers automatically. Turn that off:
      // the app retries playback itself and shows explicit "Try again"
      // buttons everywhere else.
      retry: (_, _) => null,
      child: const BgTubeApp(),
    ),
  );
}
