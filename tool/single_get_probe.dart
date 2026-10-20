// Diagnostic: checks whether a stream URL can be fully downloaded with a
// single request (YouTube may 403 every request after the first).
// Run: dart run tool/single_get_probe.dart [videoId]
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

Future<void> main(List<String> args) async {
  final id = args.isNotEmpty ? args.first : 'VzLG6OqOcn8';
  final yt = YoutubeExplode();
  final client = http.Client();
  try {
    final m = await yt.videos.streams.getManifest(id);
    final audio = m.audioOnly.withHighestBitrate();
    final sw = Stopwatch()..start();
    final res = await client.send(http.Request('GET', audio.url));
    var bytes = 0;
    await for (final chunk in res.stream) {
      bytes += chunk.length;
    }
    stdout.writeln('single GET: HTTP ${res.statusCode}, $bytes of '
        '${audio.size.totalBytes} bytes in ${sw.elapsedMilliseconds}ms');
    final again = await http.get(audio.url, headers: {'Range': 'bytes=0-1023'});
    stdout.writeln('second request: HTTP ${again.statusCode}');
  } catch (e) {
    stdout.writeln('FAILED: $e');
  } finally {
    client.close();
    yt.close();
  }
}
