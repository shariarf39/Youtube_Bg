import '../../domain/models/app_error.dart';
import '../services/stream_url_cache.dart';
import '../services/youtube_service.dart';

/// Entry point for all YouTube data. Adds stream URL caching on top of
/// [YoutubeService] and converts every failure to an [AppError].
class YoutubeRepository {
  YoutubeRepository(this._service);

  final YoutubeService _service;
  final _cache = StreamUrlCache();

  // Requests in flight, so a prefetch and a real load of the same track
  // share one network call instead of racing.
  final _pending = <String, Future<Uri>>{};

  Future<SearchPage> search(String query) =>
      _guard(() => _service.search(query));

  Future<SearchPage?> nextPage(SearchPage page) => _guard(page.next);

  Future<List<String>> suggestions(String query) =>
      _guard(() => _service.suggestions(query));

  /// Home feed. With a [seedVideoId] (the last played video) this is
  /// YouTube's related videos for it; otherwise, or if that fails, it is
  /// a search for [fallbackQuery].
  Future<SearchPage> homeFeed({
    String? seedVideoId,
    required String fallbackQuery,
  }) async {
    if (seedVideoId != null) {
      try {
        final related = await _service.related(seedVideoId);
        if (related != null) return related;
      } catch (_) {
        // Fall through to the generic feed.
      }
    }
    return search(fallbackQuery);
  }

  /// Returns a playable audio URL, from cache when possible.
  ///
  /// After a playback error, pass [attempt] > 0: this discards the cached
  /// URL and resolves a new one through a different YouTube client.
  Future<Uri> audioUrl(String videoId, {int attempt = 0}) => _cached(
      'a:$videoId',
      attempt > 0,
      () => _service.getAudioStream(videoId, attempt: attempt));

  /// Returns a playable video URL for Video mode.
  Future<Uri> videoUrl(String videoId, {int attempt = 0}) => _cached(
      'v:$videoId',
      attempt > 0,
      () => _service.getVideoStream(videoId, attempt: attempt));

  /// Resolves and caches the audio URL without playing it. Errors are
  /// ignored; the real load will report them.
  void prefetchAudio(String videoId) {
    audioUrl(videoId).ignore();
  }

  Future<Uri> _cached(
    String key,
    bool forceRefresh,
    Future<ResolvedStream> Function() fetch,
  ) {
    if (forceRefresh) {
      _cache.invalidate(key);
    } else {
      final hit = _cache.get(key);
      if (hit != null) return Future.value(hit);
      final pending = _pending[key];
      if (pending != null) return pending;
    }

    final future = _guard(() async {
      final stream = await fetch();
      _cache.put(key, stream);
      return stream.url;
    }).whenComplete(() => _pending.remove(key));
    _pending[key] = future;
    return future;
  }

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } catch (e) {
      throw AppError.from(e);
    }
  }

  void dispose() => _service.dispose();
}
