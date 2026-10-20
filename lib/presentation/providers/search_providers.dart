import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/youtube_service.dart';
import '../../domain/models/app_error.dart';
import '../../domain/models/track.dart';
import 'core_providers.dart';

/// A home-feed category chip and the YouTube query behind it.
class FeedCategory {
  const FeedCategory(this.label, this.query);

  final String label;
  final String query;

  /// Related videos for the last played track. Only shown when there is
  /// history.
  static const forYou = FeedCategory('For you', 'trending music');

  static const all = [
    forYou,
    FeedCategory('Trending', 'trending'),
    FeedCategory('Music', 'new songs'),
    FeedCategory('Bangla', 'bangla song'),
    FeedCategory('Lofi', 'lofi music'),
    FeedCategory('Podcasts', 'podcast'),
    FeedCategory('News', 'news'),
    FeedCategory('Gaming', 'gaming'),
  ];
}

/// State of the home screen: either a feed category or a typed search.
class SearchState {
  const SearchState({
    this.query = '',
    this.category,
    this.tracks = const [],
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.page,
  });

  /// The typed search, or empty when a feed category is shown.
  final String query;

  /// The selected feed chip, or null when showing search results.
  final FeedCategory? category;
  final List<Track> tracks;
  final bool loading;
  final bool loadingMore;
  final AppError? error;

  /// The last page loaded, used to fetch the next one.
  final SearchPage? page;

  bool get hasMore => page?.hasMore ?? false;

  SearchState copyWith({
    List<Track>? tracks,
    bool? loadingMore,
    SearchPage? page,
  }) =>
      SearchState(
        query: query,
        category: category,
        tracks: tracks ?? this.tracks,
        loadingMore: loadingMore ?? this.loadingMore,
        page: page,
      );
}

/// Loads the home feed on startup, runs searches, and paginates.
class SearchNotifier extends Notifier<SearchState> {
  /// Increments per request so a slow old response can't replace a newer one.
  int _generation = 0;

  @override
  SearchState build() {
    // Open straight into YouTube content instead of an empty screen.
    Future.microtask(() => showCategory(_defaultCategory));
    return const SearchState(loading: true);
  }

  bool get hasHistory =>
      ref.read(libraryRepositoryProvider).history().isNotEmpty;

  FeedCategory get _defaultCategory =>
      hasHistory ? FeedCategory.forYou : FeedCategory.all[1];

  Future<void> showCategory(FeedCategory category) {
    final repo = ref.read(youtubeRepositoryProvider);
    final history = ref.read(libraryRepositoryProvider).history();
    return _load(
      SearchState(category: category, loading: true),
      () => category == FeedCategory.forYou && history.isNotEmpty
          ? repo.homeFeed(
              seedVideoId: history.first.id,
              fallbackQuery: category.query,
            )
          : repo.search(category.query),
    );
  }

  Future<void> search(String query) {
    final q = query.trim();
    if (q.isEmpty) return showCategory(_defaultCategory);
    return _load(
      SearchState(query: q, loading: true),
      () => ref.read(youtubeRepositoryProvider).search(q),
    );
  }

  /// Back to the feed from search results.
  Future<void> clearSearch() => showCategory(_defaultCategory);

  Future<void> retry() => state.category != null
      ? showCategory(state.category!)
      : search(state.query);

  Future<void> _load(
    SearchState loadingState,
    Future<SearchPage> Function() fetch,
  ) async {
    final gen = ++_generation;
    state = loadingState;
    try {
      final page = await fetch();
      if (gen != _generation) return;
      state = SearchState(
        query: loadingState.query,
        category: loadingState.category,
        tracks: page.tracks,
        page: page,
      );
    } on AppError catch (e) {
      if (gen != _generation) return;
      state = SearchState(
        query: loadingState.query,
        category: loadingState.category,
        error: e,
      );
    }
  }

  Future<void> loadMore() async {
    final page = state.page;
    if (page == null || !page.hasMore || state.loading || state.loadingMore) {
      return;
    }
    final gen = _generation;
    state = state.copyWith(loadingMore: true, page: page);
    try {
      final next = await ref.read(youtubeRepositoryProvider).nextPage(page);
      if (gen != _generation) return;
      // Pages can overlap, so drop duplicates.
      final seen = state.tracks.map((t) => t.id).toSet();
      state = state.copyWith(
        tracks: [
          ...state.tracks,
          ...?next?.tracks.where((t) => seen.add(t.id)),
        ],
        loadingMore: false,
        page: next,
      );
    } on AppError {
      if (gen != _generation) return;
      // Keep what's already shown; scrolling down again retries.
      state = state.copyWith(loadingMore: false, page: page);
    }
  }
}

final searchProvider =
    NotifierProvider<SearchNotifier, SearchState>(SearchNotifier.new);
