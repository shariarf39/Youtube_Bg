// Diagnostic: finds which byte-range requests YouTube accepts for a stream,
// using both the Range header and the `range=` query parameter.
// Run: dart run tool/range_probe.dart [videoId]
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

Future<void> main(List<String> args) async {
  final id = args.isNotEmpty ? args.first : 'VzLG6OqOcn8';
  final yt = YoutubeExplode();
  try {
    final m = await yt.videos.streams.getManifest(id);
    final url = m.audioOnly.withHighestBitrate().url;
    final ranges = [
      '0-1023', '1024-65535', '65536-131071', '131072-1048575',
      '1048576-2097151', '5000000-5100000', '0-2097151',
    ];
    for (final r in ranges) {
      final h = await http.get(url, headers: {'Range': 'bytes=$r'});
      final q = await http.get(url.replace(
          queryParameters: {...url.queryParameters, 'range': r}));
      stdout.writeln('${r.padRight(18)} header=${h.statusCode} '
          '(${h.bodyBytes.length}B)  query=${q.statusCode} (${q.bodyBytes.length}B)');
    }
  } catch (e) {
    stdout.writeln('FAILED: $e');
  } finally {
    yt.close();
  }
}
