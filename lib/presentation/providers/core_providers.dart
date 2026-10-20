import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/library_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/youtube_repository.dart';
import '../../data/services/audio_handler.dart';
import '../../data/services/permission_service.dart';

// These singletons need async setup, so main() creates them and injects
// them with ProviderScope overrides. Reading one without an override is a
// programming error.

final youtubeRepositoryProvider = Provider<YoutubeRepository>(
  (ref) => throw UnimplementedError('Overridden in main()'),
);

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => throw UnimplementedError('Overridden in main()'),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => throw UnimplementedError('Overridden in main()'),
);

final audioHandlerProvider = Provider<BgTubeAudioHandler>(
  (ref) => throw UnimplementedError('Overridden in main()'),
);

final permissionServiceProvider = Provider((ref) => PermissionService());
