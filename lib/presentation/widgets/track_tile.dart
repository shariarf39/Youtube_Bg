import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/track.dart';
import '../providers/library_providers.dart';
import '../providers/playback_actions.dart';
import '../providers/player_providers.dart';
import 'format.dart';
import 'thumbnail.dart';

/// A list row showing a track's thumbnail, title, channel and duration,
/// with a menu for queue and favourite actions.
class TrackTile extends ConsumerWidget {
  const TrackTile({
    super.key,
    required this.track,
    required this.onTap,
    this.trailing,
  });

  final Track track;
  final VoidCallback onTap;

  /// Replaces the default overflow menu.
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isCurrent = ref.watch(
        currentMediaItemProvider.select((m) => m.value?.id == track.id));

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Thumbnail(url: track.thumbnailUrl, width: 120, height: 68),
                Container(
                  margin: const EdgeInsets.all(4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: track.isLive ? Colors.red : Colors.black87,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    track.isLive ? 'LIVE' : formatDuration(track.duration),
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isCurrent ? theme.colorScheme.primary : null,
                      fontWeight: isCurrent ? FontWeight.w600 : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            trailing ?? _TrackMenu(track: track),
          ],
        ),
      ),
    );
  }
}

class _TrackMenu extends ConsumerWidget {
  const _TrackMenu({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(playbackActionsProvider);
    final fav = ref.watch(isFavouriteProvider(track.id));
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) => switch (value) {
        'next' => actions.playNext(context, track),
        'queue' => actions.addToQueue(context, track),
        'fav' => actions.toggleFavourite(context, track),
        _ => null,
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'next', child: Text('Play next')),
        const PopupMenuItem(value: 'queue', child: Text('Add to queue')),
        PopupMenuItem(
          value: 'fav',
          child: Text(fav ? 'Remove from favourites' : 'Add to favourites'),
        ),
      ],
    );
  }
}
