import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../domain/models/track.dart';

/// Stores listening history and favourites in Hive.
///
/// Both boxes are keyed by video id, so re-adding a track replaces it instead
/// of duplicating it.
class LibraryRepository {
  LibraryRepository._(this._history, this._favourites);

  static const _historyBox = 'history';
  static const _favouritesBox = 'favourites';
  static const _maxHistory = 200;

  final Box<Map> _history;
  final Box<Map> _favourites;

  /// Opens the boxes. Call once at startup, after `Hive.initFlutter()`.
  static Future<LibraryRepository> open() async => LibraryRepository._(
        await Hive.openBox<Map>(_historyBox),
        await Hive.openBox<Map>(_favouritesBox),
      );

  // ---- History ----------------------------------------------------------

  /// Most recently played first.
  List<Track> history() => _sortedByTime(_history);

  Future<void> addToHistory(Track track) async {
    await _history.put(track.id, _stamped(track));
    if (_history.length > _maxHistory) {
      final oldest = _sortedKeys(_history).skip(_maxHistory);
      await _history.deleteAll(oldest);
    }
  }

  Future<void> removeFromHistory(String id) => _history.delete(id);

  Future<void> clearHistory() => _history.clear();

  // ---- Favourites -------------------------------------------------------

  /// Most recently added first.
  List<Track> favourites() => _sortedByTime(_favourites);

  bool isFavourite(String id) => _favourites.containsKey(id);

  /// Adds or removes [track]. Returns true if it is now a favourite.
  Future<bool> toggleFavourite(Track track) async {
    if (isFavourite(track.id)) {
      await _favourites.delete(track.id);
      return false;
    }
    await _favourites.put(track.id, _stamped(track));
    return true;
  }

  // ---- Change notifications --------------------------------------------

  /// Emits whenever history changes, so the UI can rebuild.
  Stream<void> watchHistory() => _history.watch();

  Stream<void> watchFavourites() => _favourites.watch();

  // ---- Helpers ----------------------------------------------------------

  Map<String, dynamic> _stamped(Track track) =>
      {...track.toMap(), 'at': DateTime.now().millisecondsSinceEpoch};

  List<Track> _sortedByTime(Box<Map> box) =>
      _sortedKeys(box).map((k) => Track.fromMap(box.get(k)!)).toList();

  List<dynamic> _sortedKeys(Box<Map> box) => box.keys.toList()
    ..sort((a, b) =>
        ((box.get(b)?['at'] as int?) ?? 0)
            .compareTo((box.get(a)?['at'] as int?) ?? 0));
}
