import 'youtube_service.dart';

/// In-memory cache of resolved stream URLs keyed by video id.
///
/// Entries are dropped shortly before YouTube's own expiry, so a cached URL
/// is never handed to the player when it's about to stop working.
class StreamUrlCache {
  static const _safetyMargin = Duration(minutes: 10);
  static const _maxEntries = 50;

  final _entries = <String, ResolvedStream>{};

  Uri? get(String key) {
    final entry = _entries[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt.subtract(_safetyMargin))) {
      _entries.remove(key);
      return null;
    }
    return entry.url;
  }

  void put(String key, ResolvedStream stream) {
    // Maps keep insertion order, so this evicts the oldest entry.
    if (_entries.length >= _maxEntries) _entries.remove(_entries.keys.first);
    _entries[key] = stream;
  }

  void invalidate(String key) => _entries.remove(key);
}
