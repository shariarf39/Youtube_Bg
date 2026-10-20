import 'dart:io';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../domain/models/track.dart';

/// A page of videos (search results or a feed) plus a handle for loading more.
class SearchPage {
  SearchPage(this.tracks, [this._loadNext]);

  final List<Track> tracks;
  final Future<SearchPage?> Function()? _loadNext;

  bool get hasMore => _loadNext != null;

  /// Returns the next page, or null when YouTube has no more results.
  Future<SearchPage?> next() async => _loadNext?.call();
}

/// A resolved, directly playable stream URL.
class ResolvedStream {
  const ResolvedStream(this.url, this.expiresAt);

  final Uri url;

  /// From the `expire` query parameter YouTube puts on every stream URL.
  final DateTime expiresAt;
}

/// Thin wrapper around youtube_explode_dart. This is the only file that
/// talks to YouTube directly; everything else uses [Track] and [ResolvedStream].
class YoutubeService {
  YoutubeService() : _yt = YoutubeExplode();

  final YoutubeExplode _yt;

  /// Stream extraction clients, tried in order. YouTube regularly breaks
  /// one client or another, and a URL from one client can fail on a device
  /// where another works, so each retry moves to the next client.
  /// `null` is the library's default.
  static final List<List<YoutubeApiClient>?> _clients = [
    [YoutubeApiClient.ios],
    [YoutubeApiClient.androidVr],
    null,
  ];

  /// A manifest request that takes longer than this is treated as failed.
  static const _manifestTimeout = Duration(seconds: 20);

  /// Gets a stream manifest. [attempt] selects the client, and wraps
  /// around after the last one.
  Future<StreamManifest> _manifest(String videoId, int attempt) {
    final clients = _clients[attempt % _clients.length];
    return _yt.videos.streams
        .getManifest(videoId, ytClients: clients)
        .timeout(_manifestTimeout);
  }

  static Track trackFromVideo(Video v) => Track(
        id: v.id.value,
        title: v.title,
        author: v.author,
        duration: v.duration,
        isLive: v.isLive,
      );

  /// Uses `searchContent` instead of `search`: in youtube_explode_dart
  /// 3.1.0, `search` crashes on results whose upload date reads
  /// "Streamed 2 years ago", which fails the whole page.
  Future<SearchPage> search(String query) async => _searchPage(
      await _yt.search.searchContent(query, filter: TypeFilters.video));

  SearchPage _searchPage(SearchList list) => SearchPage(
        list.whereType<SearchVideo>().map(_trackFromSearch).toList(),
        () async {
          final next = await list.nextPage();
          return next == null || next.isEmpty ? null : _searchPage(next);
        },
      );

  static Track _trackFromSearch(SearchVideo v) => Track(
        id: v.id.value,
        title: v.title,
        author: v.author,
        duration: _parseDuration(v.duration),
        isLive: v.isLive,
      );

  /// Parses "4:13" or "1:02:03". Returns null for live streams or
  /// anything unexpected.
  static Duration? _parseDuration(String text) {
    final parts = text.split(':').map(int.tryParse).toList();
    if (parts.isEmpty || parts.length > 3 || parts.contains(null)) return null;
    var seconds = 0;
    for (final p in parts) {
      seconds = seconds * 60 + p!;
    }
    return Duration(seconds: seconds);
  }

  /// Autocomplete suggestions, the same ones youtube.com shows while typing.
  Future<List<String>> suggestions(String query) =>
      _yt.search.getQuerySuggestions(query);

  /// Videos YouTube recommends next to [videoId], for the "For you" feed.
  /// Returns null if YouTube doesn't provide any.
  Future<SearchPage?> related(String videoId) async {
    final video = await _yt.videos.get(videoId);
    final list = await _yt.videos.getRelatedVideos(video);
    if (list == null || list.isEmpty) return null;
    return _relatedPage(list);
  }

  SearchPage _relatedPage(RelatedVideosList list) =>
      SearchPage(list.map(trackFromVideo).toList(), () async {
        final next = await list.nextPage();
        return next == null || next.isEmpty ? null : _relatedPage(next);
      });

  /// Resolves the best audio-only stream for background playback.
  ///
  /// Chooses the highest bitrate, preferring Opus/WebM on a tie because it
  /// sounds better than AAC at the same bitrate. iOS's AVPlayer can't decode
  /// WebM, so iOS only considers M4A (mp4 container).
  ///
  /// [attempt] selects which YouTube client to use; see [_clients].
  Future<ResolvedStream> getAudioStream(String videoId, {int attempt = 0}) async {
    final manifest = await _manifest(videoId, attempt);

    var candidates = manifest.audioOnly.where((s) =>
        s.container == StreamContainer.mp4 ||
        (!Platform.isIOS && s.container == StreamContainer.webM));

    // Dubbed videos have one audio track per language; keep the original.
    final defaults =
        candidates.where((s) => s.audioTrack?.audioIsDefault ?? true);
    if (defaults.isNotEmpty) candidates = defaults;

    if (candidates.isEmpty) {
      // Live streams only expose HLS, which just_audio can play directly.
      if (manifest.hls.isNotEmpty) {
        return _resolved(manifest.hls.first.url);
      }
      throw VideoUnplayableException('No playable audio stream for $videoId');
    }

    final best = candidates.reduce((a, b) {
      final byBitrate = a.bitrate.compareTo(b.bitrate);
      if (byBitrate != 0) return byBitrate > 0 ? a : b;
      return a.container == StreamContainer.webM ? a : b;
    });
    return _resolved(best.url);
  }

  /// Resolves a video stream for Video mode. Video mode plays picture only,
  /// muted and kept in sync with the audio player, so the audio service
  /// stays in charge of the notification and background playback.
  ///
  /// Prefers mp4/H.264 at 720p or below for wide decoder support and to
  /// limit data use. Falls back to a muxed stream.
  Future<ResolvedStream> getVideoStream(String videoId, {int attempt = 0}) async {
    final manifest = await _manifest(videoId, attempt);

    final mp4 = manifest.videoOnly
        .where((s) =>
            s.container == StreamContainer.mp4 &&
            s.videoCodec.startsWith('avc1') &&
            s.videoResolution.height <= 720)
        .toList()
      ..sort((a, b) =>
          b.videoResolution.height.compareTo(a.videoResolution.height));
    if (mp4.isNotEmpty) return _resolved(mp4.first.url);

    if (manifest.muxed.isNotEmpty) {
      return _resolved(manifest.muxed.bestQuality.url);
    }
    if (manifest.hls.isNotEmpty) return _resolved(manifest.hls.first.url);
    throw VideoUnplayableException('No playable video stream for $videoId');
  }

  ResolvedStream _resolved(Uri url) {
    // YouTube URLs carry an `expire` unix timestamp, usually about 6 hours
    // ahead. Fall back to 1 hour if it's missing.
    final expire = int.tryParse(url.queryParameters['expire'] ?? '');
    final expiresAt = expire != null
        ? DateTime.fromMillisecondsSinceEpoch(expire * 1000)
        : DateTime.now().add(const Duration(hours: 1));
    return ResolvedStream(url, expiresAt);
  }

  void dispose() => _yt.close();
}
