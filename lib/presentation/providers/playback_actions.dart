import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/track.dart';
import 'core_providers.dart';

/// UI-level playback commands that show feedback in a snackbar.
class PlaybackActions {
  PlaybackActions(this._ref);

  final Ref _ref;

  /// Plays [tracks] starting at [index], replacing the queue.
  Future<void> playList(List<Track> tracks, int index) =>
      _ref.read(audioHandlerProvider).playTracks(tracks, startIndex: index);

  void playNext(BuildContext context, Track track) {
    _ref.read(audioHandlerProvider).playNext(track);
    _toast(context, 'Playing next: ${track.title}');
  }

  void addToQueue(BuildContext context, Track track) {
    _ref.read(audioHandlerProvider).addToQueue([track]);
    _toast(context, 'Added to queue');
  }

  Future<void> toggleFavourite(BuildContext context, Track track) async {
    final added =
        await _ref.read(libraryRepositoryProvider).toggleFavourite(track);
    if (context.mounted) {
      _toast(context, added ? 'Added to favourites' : 'Removed from favourites');
    }
  }

  void _toast(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 2),
      ));
  }
}

final playbackActionsProvider = Provider(PlaybackActions.new);
