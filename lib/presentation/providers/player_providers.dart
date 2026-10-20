import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/sleep_timer_state.dart';
import 'core_providers.dart';

/// Playing/paused, processing state, repeat/shuffle mode, and queue index.
final playbackStateProvider = StreamProvider<PlaybackState>(
  (ref) => ref.watch(audioHandlerProvider).playbackState,
);

/// The track currently loaded, or null when nothing has played yet.
final currentMediaItemProvider = StreamProvider<MediaItem?>(
  (ref) => ref.watch(audioHandlerProvider).mediaItem,
);

final queueProvider = StreamProvider<List<MediaItem>>(
  (ref) => ref.watch(audioHandlerProvider).queue,
);

/// Updates about every 200ms while playing. Watch it only in small widgets
/// such as seek bars, so whole screens don't rebuild that often.
final positionProvider = StreamProvider.autoDispose<Duration>(
  (ref) => ref.watch(audioHandlerProvider).positionStream,
);

final sleepTimerProvider = StreamProvider<SleepTimerState>(
  (ref) => ref.watch(audioHandlerProvider).sleepTimer,
);
