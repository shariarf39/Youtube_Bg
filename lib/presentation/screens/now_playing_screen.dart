import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/track.dart';
import '../providers/core_providers.dart';
import '../providers/library_providers.dart';
import '../providers/playback_actions.dart';
import '../providers/player_providers.dart';
import '../providers/settings_providers.dart';
import '../widgets/format.dart';
import '../widgets/queue_sheet.dart';
import '../widgets/seek_bar.dart';
import '../widgets/sleep_timer_sheet.dart';
import '../widgets/thumbnail.dart';
import '../widgets/video_pane.dart';

/// Full-screen player: artwork or video, seek bar, transport controls,
/// shuffle/repeat, sleep timer, queue and the Video mode toggle.
class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const NowPlayingScreen(),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(currentMediaItemProvider).value;
    final theme = Theme.of(context);

    if (item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Nothing playing')),
      );
    }

    final track = Track.fromMediaItem(item);
    final videoMode = ref.watch(videoModeProvider);
    final sleep = ref.watch(sleepTimerProvider).value;
    final isFav = ref.watch(isFavouriteProvider(track.id));
    final state = ref.watch(playbackStateProvider).value;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Now playing'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: videoMode ? 'Switch to audio only' : 'Switch to video',
            icon: Icon(videoMode
                ? Icons.music_video
                : Icons.ondemand_video_outlined),
            isSelected: videoMode,
            onPressed: () => ref.read(videoModeProvider.notifier).toggle(),
          ),
          IconButton(
            tooltip: 'Sleep timer',
            icon: Badge(
              isLabelVisible: sleep?.isActive == true,
              smallSize: 8,
              child: const Icon(Icons.bedtime_outlined),
            ),
            onPressed: () => SleepTimerSheet.show(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Center(
                  child: videoMode
                      ? VideoPane(
                          key: ValueKey(track.id),
                          videoId: track.id,
                          thumbUrl: track.thumbnailUrl,
                        )
                      : Hero(
                          tag: 'artwork',
                          child: Thumbnail(url: track.thumbnailUrl, radius: 16),
                        ),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(track.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(track.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(isFav ? Icons.favorite : Icons.favorite_border),
                    color: isFav ? theme.colorScheme.primary : null,
                    onPressed: () => ref
                        .read(playbackActionsProvider)
                        .toggleFavourite(context, track),
                  ),
                ],
              ),
              if (state?.processingState == AudioProcessingState.error)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${state?.errorMessage ?? 'Playback error'} · tap play to retry',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              if (sleep?.remaining != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Sleep in ${formatDuration(sleep!.remaining)}',
                      style: theme.textTheme.bodySmall),
                ),
              const SizedBox(height: 16),
              const SeekBar(),
              const SizedBox(height: 8),
              const _Controls(),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => QueueSheet.show(context),
                icon: const Icon(Icons.queue_music),
                label: const Text('Up next'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _Controls extends ConsumerWidget {
  const _Controls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.read(audioHandlerProvider);
    final state = ref.watch(playbackStateProvider).value;
    final playing = state?.playing ?? false;
    final shuffle = state?.shuffleMode == AudioServiceShuffleMode.all;
    final repeat = state?.repeatMode ?? AudioServiceRepeatMode.none;
    final loading = state?.processingState == AudioProcessingState.loading ||
        state?.processingState == AudioProcessingState.buffering;
    final primary = Theme.of(context).colorScheme.primary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          tooltip: 'Shuffle',
          icon: const Icon(Icons.shuffle),
          color: shuffle ? primary : null,
          onPressed: () => handler.setShuffleMode(shuffle
              ? AudioServiceShuffleMode.none
              : AudioServiceShuffleMode.all),
        ),
        IconButton(
          iconSize: 36,
          icon: const Icon(Icons.skip_previous),
          onPressed: handler.skipToPrevious,
        ),
        SizedBox(
          width: 72,
          height: 72,
          child: loading
              ? const Padding(
                  padding: EdgeInsets.all(18),
                  child: CircularProgressIndicator(),
                )
              : IconButton.filled(
                  iconSize: 40,
                  icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                  onPressed: playing ? handler.pause : handler.play,
                ),
        ),
        IconButton(
          iconSize: 36,
          icon: const Icon(Icons.skip_next),
          onPressed: handler.skipToNext,
        ),
        IconButton(
          tooltip: switch (repeat) {
            AudioServiceRepeatMode.one => 'Repeat one',
            AudioServiceRepeatMode.none => 'Repeat off',
            _ => 'Repeat all',
          },
          icon: Icon(repeat == AudioServiceRepeatMode.one
              ? Icons.repeat_one
              : Icons.repeat),
          color: repeat == AudioServiceRepeatMode.none ? null : primary,
          // Cycle: off -> all -> one -> off.
          onPressed: () => handler.setRepeatMode(switch (repeat) {
            AudioServiceRepeatMode.none => AudioServiceRepeatMode.all,
            AudioServiceRepeatMode.all => AudioServiceRepeatMode.one,
            _ => AudioServiceRepeatMode.none,
          }),
        ),
      ],
    );
  }
}
