import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/track.dart';
import '../providers/core_providers.dart';
import '../providers/library_providers.dart';
import '../providers/playback_actions.dart';
import '../widgets/track_tile.dart';
import 'now_playing_screen.dart';

/// Favourites and listening history, stored locally in Hive.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(tabs: [Tab(text: 'Favourites'), Tab(text: 'History')]),
          Expanded(
            child: TabBarView(
              children: [
                _TrackList(
                  tracks: ref.watch(favouritesProvider),
                  emptyText: 'Tap ♡ on Now Playing to save favourites.',
                ),
                _TrackList(
                  tracks: ref.watch(historyProvider),
                  emptyText: 'Videos you play will show up here.',
                  onClear: () => _confirmClear(context, ref),
                  onRemove: (t) =>
                      ref.read(libraryRepositoryProvider).removeFromHistory(t.id),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('This removes all videos from your history.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) await ref.read(libraryRepositoryProvider).clearHistory();
  }
}

class _TrackList extends ConsumerWidget {
  const _TrackList({
    required this.tracks,
    required this.emptyText,
    this.onClear,
    this.onRemove,
  });

  final AsyncValue<List<Track>> tracks;
  final String emptyText;
  final VoidCallback? onClear;
  final void Function(Track)? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = tracks.value ?? const <Track>[];
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(emptyText, textAlign: TextAlign.center),
        ),
      );
    }

    final actions = ref.read(playbackActionsProvider);
    return ListView.builder(
      itemCount: list.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => actions.playList(list, 0),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play all'),
                ),
                const Spacer(),
                if (onClear != null)
                  TextButton(onPressed: onClear, child: const Text('Clear')),
              ],
            ),
          );
        }
        final track = list[i - 1];
        final tile = TrackTile(
          track: track,
          onTap: () {
            actions.playList(list, i - 1);
            NowPlayingScreen.open(context);
          },
        );
        if (onRemove == null) return tile;
        return Dismissible(
          key: ValueKey(track.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            color: Theme.of(context).colorScheme.errorContainer,
            child: const Icon(Icons.delete_outline),
          ),
          onDismissed: (_) => onRemove!(track),
          child: tile,
        );
      },
    );
  }
}
