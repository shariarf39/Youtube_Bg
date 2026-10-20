// Diagnostic: resolves audio streams the way the app does and checks that
// YouTube actually serves them. Run: dart run tool/stream_probe.dart [videoId]
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

Future<void> main(List<String> args) async {
  final id = args.isNotEmpty ? args.first : 'jfKfPfyJRdk';
  final yt = YoutubeExplode();
  final sw = Stopwatch()..start();
  try {
    final search = await yt.search.search(args.length > 1 ? args[1] : 'arijit singh');
    stdout.writeln('search ok: ${search.length} results (${sw.elapsedMilliseconds}ms)');
    final m = await yt.videos.streams.getManifest(id);
    stdout.writeln('manifest ok (${sw.elapsedMilliseconds}ms): '
        '${m.audioOnly.length} audio, ${m.muxed.length} muxed, '
        '${m.videoOnly.length} video-only, ${m.hls.length} hls');
    for (final s in [...m.audioOnly.take(3), ...m.muxed.take(1)]) {
      final r = await http.get(s.url, headers: {'Range': 'bytes=0-1023'});
      stdout.writeln('${s.runtimeType} ${s.container.name} '
          '${s.bitrate.kiloBitsPerSecond.round()}kbps -> HTTP ${r.statusCode}');
    }
  } catch (e) {
    stdout.writeln('FAILED after ${sw.elapsedMilliseconds}ms: $e');
  } finally {
    yt.close();
  }
}
