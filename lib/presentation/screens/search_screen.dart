import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import '../providers/playback_actions.dart';
import '../providers/search_providers.dart';
import '../widgets/error_view.dart';
import '../widgets/track_tile.dart';
import 'now_playing_screen.dart';

/// Home tab. Opens straight into a YouTube feed with category chips.
/// The search bar shows YouTube's own autocomplete suggestions while typing.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  static const _debounce = Duration(milliseconds: 250);

  final _search = SearchController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _submit(String text) {
    if (_search.isOpen) _search.closeView(text);
    FocusScope.of(context).unfocus();
    ref.read(searchProvider.notifier).search(text);
  }

  /// Fetches suggestions from YouTube, waiting briefly so each keystroke
  /// doesn't trigger a request. SearchAnchor discards results for text that
  /// has since changed.
  Future<Iterable<Widget>> _suggestions(
      BuildContext context, SearchController controller) async {
    final query = controller.text.trim();
    if (query.isEmpty) return const [];
    await Future<void>.delayed(_debounce);
    if (controller.text.trim() != query) return const [];

    final List<String> items;
    try {
      items = await ref.read(youtubeRepositoryProvider).suggestions(query);
    } catch (_) {
      return const []; // Suggestions are optional; searching still works.
    }
    return items.map((s) => ListTile(
          leading: const Icon(Icons.search),
          title: Text(s),
          // Copy the suggestion into the box to refine it, like YouTube.
          trailing: IconButton(
            icon: const Icon(Icons.north_west),
            onPressed: () => controller.text = s,
          ),
          onTap: () => _submit(s),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);
    final notifier = ref.read(searchProvider.notifier);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SearchAnchor.bar(
            searchController: _search,
            barHintText: 'Search YouTube',
            viewHintText: 'Search YouTube',
            barLeading: const Icon(Icons.search),
            barTrailing: [
              if (state.query.isNotEmpty)
                IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _search.clear();
                    notifier.clearSearch();
                  },
                ),
            ],
            textInputAction: TextInputAction.search,
            onSubmitted: _submit,
            suggestionsBuilder: _suggestions,
          ),
        ),
        if (state.query.isEmpty) _CategoryChips(selected: state.category),
        Expanded(child: _body(state)),
      ],
    );
  }

  Widget _body(SearchState state) {
    final notifier = ref.read(searchProvider.notifier);
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return ErrorView(error: state.error!, onRetry: notifier.retry);
    }
    if (state.tracks.isEmpty) {
      return const Center(child: Text('No results'));
    }

    return RefreshIndicator(
      onRefresh: notifier.retry,
      child: NotificationListener<ScrollNotification>(
        // Load the next page when close to the bottom.
        onNotification: (n) {
          if (n.metrics.extentAfter < 600) notifier.loadMore();
          return false;
        },
        child: ListView.builder(
          itemCount: state.tracks.length + (state.hasMore ? 1 : 0),
          itemBuilder: (context, i) {
            if (i == state.tracks.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return TrackTile(
              track: state.tracks[i],
              // Queue the whole list so next/previous work from here,
              // and open the player so the video is visible.
              onTap: () {
                ref.read(playbackActionsProvider).playList(state.tracks, i);
                NowPlayingScreen.open(context);
              },
            );
          },
        ),
      ),
    );
  }
}

/// Horizontally scrolling feed categories, like the chips on YouTube's home.
class _CategoryChips extends ConsumerWidget {
  const _CategoryChips({required this.selected});

  final FeedCategory? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(searchProvider.notifier);
    final categories = FeedCategory.all
        .where((c) => c != FeedCategory.forYou || notifier.hasHistory)
        .toList();

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = categories[i];
          return Center(
            child: ChoiceChip(
              label: Text(c.label),
              selected: c == selected,
              onSelected: (_) => notifier.showCategory(c),
            ),
          );
        },
      ),
    );
  }
}
