// Diagnostic: runs a search and prints the full stack trace on failure.
// Run: dart run tool/search_probe.dart "query"
import 'dart:io';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

Future<void> main(List<String> args) async {
  final yt = YoutubeExplode();
  try {
    final r = (await yt.search.searchContent(args.isEmpty ? 'lofi' : args.first,
            filter: TypeFilters.video))
        .whereType<SearchVideo>();
    stdout.writeln('ok: ${r.length}');
  } catch (e, st) {
    stdout.writeln('$e\n$st');
  } finally {
    yt.close();
  }
}
