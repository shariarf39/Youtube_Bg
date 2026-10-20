import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/track.dart';
import '../providers/core_providers.dart';
import '../providers/player_providers.dart';
import 'track_tile.dart';

/// Bottom sheet listing the queue. Tap to jump, drag to reorder,
/// swipe to remove.
class QueueSheet extends ConsumerWidget {
  static Future<void> show(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          builder: (_, controller) => QueueSheet._(controller),
        ),
      );

  const QueueSheet._(this._controller);

  final ScrollController _controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.read(audioHandlerProvider);
    final queue = ref.watch(queueProvider).value ?? const [];
    final currentIndex =
        ref.watch(playbackStateProvider.select((s) => s.value?.queueIndex));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('Up next · ${queue.length}',
              style: Theme.of(context).textTheme.titleMedium),
        ),
        Expanded(
          child: ReorderableListView.builder(
            scrollController: _controller,
            itemCount: queue.length,
            onReorderItem: handler.moveQueueItem,
            itemBuilder: (context, i) {
              final track = Track.fromMediaItem(queue[i]);
              return Dismissible(
                // Index in the key keeps duplicates of a video distinct.
                key: ValueKey('${track.id}-$i'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: const Icon(Icons.delete_outline),
                ),
                onDismissed: (_) => handler.removeQueueItemAt(i),
                child: TrackTile(
                  track: track,
                  onTap: () => handler.skipToQueueItem(i),
                  trailing: i == currentIndex
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(Icons.equalizer),
                        )
                      : ReorderableDragStartListener(
                          index: i,
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(Icons.drag_handle),
                          ),
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
