import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../data/services/audio_handler.dart';
import '../providers/core_providers.dart';
import '../providers/settings_providers.dart';
import 'thumbnail.dart';

/// Shows the video picture for [videoId] in Video mode.
///
/// The video plays muted and follows the audio handler's position and
/// play state. Audio always comes from the background audio service, so
/// the notification, queue and lock-screen controls keep working, and
/// nothing is interrupted when the app goes to the background. In the
/// background the video controller is released and only audio continues.
class VideoPane extends ConsumerStatefulWidget {
  const VideoPane({super.key, required this.videoId, required this.thumbUrl});

  final String videoId;
  final String thumbUrl;

  @override
  ConsumerState<VideoPane> createState() => _VideoPaneState();
}

class _VideoPaneState extends ConsumerState<VideoPane>
    with WidgetsBindingObserver {
  /// Larger drift than this triggers a corrective seek.
  static const _maxDrift = Duration(milliseconds: 400);

  VideoPlayerController? _controller;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription? _stateSub;
  bool _foreground = true;
  Uri? _loadedUrl;

  /// A URL that failed to initialise, so it isn't retried on every build.
  Uri? _failedUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final fg = state == AppLifecycleState.resumed;
    if (fg == _foreground) return;
    setState(() => _foreground = fg);
    if (!fg) _release(); // Save battery: audio only in the background.
  }

  @override
  void didUpdateWidget(VideoPane old) {
    super.didUpdateWidget(old);
    if (old.videoId != widget.videoId) _release();
  }

  Future<void> _attach(Uri url) async {
    if (!mounted || !_foreground || _loadedUrl == url || _failedUrl == url) {
      return;
    }
    _release();
    _loadedUrl = url;

    final controller = VideoPlayerController.networkUrl(url);
    _controller = controller;
    try {
      await controller.initialize();
    } catch (_) {
      // Fall back to the thumbnail; audio is unaffected.
      if (mounted && _controller == controller) {
        setState(() {
          _release();
          _failedUrl = url;
        });
      }
      return;
    }
    if (!mounted || _controller != controller) return;
    await controller.setVolume(0);

    final handler = ref.read(audioHandlerProvider);
    await controller.seekTo(handler.position);
    _syncPlaying(handler);
    _stateSub = handler.playbackState.listen((_) => _syncPlaying(handler));
    _positionSub = handler.positionStream.listen(_syncPosition);
    setState(() {});
  }

  void _syncPlaying(BgTubeAudioHandler handler) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final playing = handler.playbackState.value.playing;
    if (playing && !c.value.isPlaying) c.play();
    if (!playing && c.value.isPlaying) c.pause();
  }

  void _syncPosition(Duration audioPos) {
    final c = _controller;
    if (c == null || !c.value.isInitialized || c.value.isBuffering) return;
    final drift = (c.value.position - audioPos).abs();
    if (drift > _maxDrift) c.seekTo(audioPos);
  }

  void _release() {
    _positionSub?.cancel();
    _stateSub?.cancel();
    _positionSub = null;
    _stateSub = null;
    _controller?.dispose();
    _controller = null;
    _loadedUrl = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final thumb = Thumbnail(url: widget.thumbUrl, radius: 16);
    if (!_foreground) return thumb;

    final url = ref.watch(videoUrlProvider(widget.videoId));
    return url.when(
      loading: () => Stack(
        alignment: Alignment.center,
        children: [thumb, const CircularProgressIndicator()],
      ),
      error: (_, _) => thumb,
      data: (uri) {
        // Controller setup is async and calls setState, so start it after
        // this frame rather than during build.
        WidgetsBinding.instance.addPostFrameCallback((_) => _attach(uri));
        final c = _controller;
        if (c == null || !c.value.isInitialized) {
          return Stack(
            alignment: Alignment.center,
            children: [thumb, const CircularProgressIndicator()],
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: c.value.aspectRatio,
            child: VideoPlayer(c),
          ),
        );
      },
    );
  }
}
