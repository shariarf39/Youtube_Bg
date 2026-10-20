import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/track.dart';
import 'core_providers.dart';

/// Listening history, newest first. Re-emits whenever the Hive box changes.
final historyProvider = StreamProvider<List<Track>>((ref) async* {
  final repo = ref.watch(libraryRepositoryProvider);
  yield repo.history();
  await for (final _ in repo.watchHistory()) {
    yield repo.history();
  }
});

/// Favourites, newest first.
final favouritesProvider = StreamProvider<List<Track>>((ref) async* {
  final repo = ref.watch(libraryRepositoryProvider);
  yield repo.favourites();
  await for (final _ in repo.watchFavourites()) {
    yield repo.favourites();
  }
});

/// Whether the video with this id is a favourite.
final isFavouriteProvider = Provider.family<bool, String>((ref, id) {
  // Rebuild whenever the favourites list changes.
  ref.watch(favouritesProvider);
  return ref.watch(libraryRepositoryProvider).isFavourite(id);
});
