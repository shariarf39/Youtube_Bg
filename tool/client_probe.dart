// Diagnostic: compares youtube_explode clients by making several range
// requests per stream URL, the way ExoPlayer/AVPlayer do.
// Run: dart run tool/client_probe.dart [videoId]
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

Future<void> main(List<String> args) async {
  final id = args.isNotEmpty ? args.first : 'dQw4w9WgXcQ';
  final clients = {
    'default': null,
    'ios': [YoutubeApiClient.ios],
    'androidVr': [YoutubeApiClient.androidVr],
    'tv': [YoutubeApiClient.tv],
  };
  for (final entry in clients.entries) {
    final yt = YoutubeExplode();
    try {
      final m = await yt.videos.streams
          .getManifest(id, ytClients: entry.value);
      final audio = m.audioOnly.withHighestBitrate();
      final codes = <int>[];
      for (final range in ['0-65535', '65536-1048575', '0-', '2000000-2100000']) {
        final r = await http.get(audio.url, headers: {
          'Range': 'bytes=$range',
          'User-Agent': 'ExoPlayerLib/2.18.7',
        });
        codes.add(r.statusCode);
      }
      stdout.writeln('${entry.key.padRight(10)} audio=${m.audioOnly.length} '
          'muxed=${m.muxed.length} videoOnly=${m.videoOnly.length} '
          'best=${audio.container.name}/${audio.bitrate.kiloBitsPerSecond.round()}k '
          'ranges=$codes');
    } catch (e) {
      stdout.writeln('${entry.key.padRight(10)} FAILED: $e');
    } finally {
      yt.close();
    }
  }
}
