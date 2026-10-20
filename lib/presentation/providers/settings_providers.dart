import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core_providers.dart';

/// Video mode: show the video picture on Now Playing while the app is in
/// the foreground. Audio always comes from the background audio service.
class VideoModeNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(settingsRepositoryProvider).videoMode;

  Future<void> toggle() async {
    state = !state;
    await ref.read(settingsRepositoryProvider).setVideoMode(state);
  }
}

final videoModeProvider =
    NotifierProvider<VideoModeNotifier, bool>(VideoModeNotifier.new);

/// Resolved video stream URL for Video mode, per video id.
/// Tries each YouTube client in turn before giving up.
final videoUrlProvider =
    FutureProvider.autoDispose.family<Uri, String>((ref, videoId) async {
  final repo = ref.watch(youtubeRepositoryProvider);
  for (var attempt = 0;; attempt++) {
    try {
      return await repo.videoUrl(videoId, attempt: attempt);
    } catch (_) {
      if (attempt >= 2) rethrow;
    }
  }
});
