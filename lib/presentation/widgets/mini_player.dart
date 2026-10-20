import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import '../providers/player_providers.dart';
import '../screens/now_playing_screen.dart';
import 'thumbnail.dart';

/// The compact player bar shown at the bottom of every screen.
/// Tap it to open Now Playing. Hidden until something has been played.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(currentMediaItemProvider).value;
    if (item == null) return const SizedBox.shrink();

    final state = ref.watch(playbackStateProvider).value;
    final handler = ref.read(audioHandlerProvider);
    final theme = Theme.of(context);
    final loading = state?.processingState == AudioProcessingState.loading ||
        state?.processingState == AudioProcessingState.buffering;

    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      child: InkWell(
        onTap: () => NowPlayingScreen.open(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _MiniProgress(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
              child: Row(
                children: [
                  Hero(
                    tag: 'artwork',
                    child: Thumbnail(
                        url: item.artUri.toString(), width: 64, height: 40),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium),
                        Text(item.artist ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: loading
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            icon: Icon(state?.playing == true
                                ? Icons.pause
                                : Icons.play_arrow),
                            onPressed: state?.playing == true
                                ? handler.pause
                                : handler.play,
                          ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    onPressed: handler.skipToNext,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thin progress line. A separate widget so position ticks only rebuild it.
class _MiniProgress extends ConsumerWidget {
  const _MiniProgress();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duration = ref.watch(currentMediaItemProvider).value?.duration;
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final progress = duration == null || duration.inMilliseconds == 0
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    return LinearProgressIndicator(value: progress, minHeight: 2);
  }
}
