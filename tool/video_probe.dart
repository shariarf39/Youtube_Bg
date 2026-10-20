// Diagnostic: lists the video streams each client offers for Video mode.
// Run: dart run tool/video_probe.dart [videoId]
import 'dart:io';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

Future<void> main(List<String> args) async {
  final id = args.isNotEmpty ? args.first : 'dQw4w9WgXcQ';
  for (final c in [YoutubeApiClient.ios, YoutubeApiClient.androidVr]) {
    final yt = YoutubeExplode();
    try {
      final m = await yt.videos.streams.getManifest(id, ytClients: [c]);
      final avc = m.videoOnly
          .where((s) =>
              s.container == StreamContainer.mp4 &&
              s.videoCodec.startsWith('avc1') &&
              s.videoResolution.height <= 720)
          .map((s) => s.videoResolution.height)
          .toList();
      stdout.writeln('${c.payload['context']['client']['clientName']}: '
          'avc1<=720 $avc, muxed ${m.muxed.length}');
    } catch (e) {
      stdout.writeln('failed: $e');
    } finally {
      yt.close();
    }
  }
}
