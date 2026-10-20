import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

import '../../domain/models/app_error.dart';
import '../../domain/models/sleep_timer_state.dart';
import '../../domain/models/track.dart';
import '../repositories/library_repository.dart';
import '../repositories/youtube_repository.dart';

/// Starts the audio service and returns the handler.
///
/// The service runs as an Android foreground service of type
/// `mediaPlayback`. That is what keeps playback alive with the screen off or
/// the app in the background. It also publishes the media notification and
/// lock-screen controls.
Future<BgTubeAudioHandler> initAudioHandler({
  required YoutubeRepository youtube,
  required LibraryRepository library,
}) {
  return AudioService.init(
    builder: () => BgTubeAudioHandler(youtube, library),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.bgtube.bgtube.playback',
      androidNotificationChannelName: 'Playback',
      androidNotificationChannelDescription: 'Media controls for BgTube',
      // Non-dismissable while playing. Once paused, the service leaves the
      // foreground and the user can swipe the notification away.
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      fastForwardInterval: Duration(seconds: 10),
      rewindInterval: Duration(seconds: 10),
    ),
  );
}

/// The app's single audio engine.
///
/// The queue is managed here rather than in a just_audio playlist because
/// YouTube stream URLs must be resolved just before playback and expire after
/// a few hours. Each track is loaded on demand, and the next track's URL is
/// prefetched so transitions are near-gapless.
class BgTubeAudioHandler extends BaseAudioHandler with SeekHandler {
  BgTubeAudioHandler(this._youtube, this._library) {
    _init();
  }

  /// Retries per track. Each retry uses a different YouTube client
  /// (see YoutubeService._clients), so 2 retries try all three.
  static const _maxRetries = 2;

  static const _loadTimeout = Duration(seconds: 20);
  static const _duckVolume = 0.3;

  final YoutubeRepository _youtube;
  final LibraryRepository _library;

  // Interruptions are handled below; just_audio's built-in handler only
  // ducks for game audio.
  final _player = AudioPlayer(handleInterruptions: false);
  final _random = Random();

  /// Index into [queue] of the current track.
  int? _index;

  /// Play order as indices into [queue]. Shuffled when shuffle is on, with
  /// the current track first.
  List<int> _order = [];

  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;
  AudioServiceShuffleMode _shuffleMode = AudioServiceShuffleMode.none;

  /// Incremented on every load so stale async results are discarded when
  /// the user skips quickly.
  int _loadToken = 0;

  /// True while the stream URL is being resolved, before the player has a source.
  bool _resolving = false;

  /// Whether playback should start once the current load finishes.
  bool _autoplay = false;

  AppError? _error;
  int _retries = 0;
  Duration _lastPosition = Duration.zero;
  Duration _retryPosition = Duration.zero;

  bool _pausedByInterruption = false;
  bool _ducked = false;

  Timer? _sleepTimer;
  final sleepTimer =
      BehaviorSubject<SleepTimerState>.seeded(const SleepTimerState.off());

  /// One event per playback error that wasn't recovered, for snackbars.
  final errors = PublishSubject<AppError>();

  /// High-frequency position for seek bars and Video mode sync.
  Stream<Duration> get positionStream => _player.positionStream;
  Duration get position => _player.position;

  Future<void> _init() async {
    await _configureAudioSession();

    _player.playbackEventStream.listen(
      (_) => _broadcastState(),
      // Errors are handled once, through errorStream below.
      onError: (Object _, StackTrace _) {},
    );
    _player.playingStream.listen((_) => _broadcastState());

    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed && !_resolving) {
        _onTrackCompleted();
      }
    });

    _player.positionStream.listen((p) {
      if (_resolving || p == Duration.zero) return;
      _lastPosition = p;
      // After a minute of healthy playback, allow fresh retries again.
      // This lets a stream that expires hours into a long mix recover.
      if (_retries > 0 && p - _retryPosition > const Duration(minutes: 1)) {
        _retries = 0;
      }
    });

    // Mid-playback errors, e.g. the stream URL expired (HTTP 403).
    // Errors during a load are caught in [_loadIndex] instead.
    _player.errorStream.listen((e) {
      if (!_resolving) _handleError(e, _loadToken);
    });

    _broadcastState();
  }

  // ---------------------------------------------------------------------
  // Audio focus
  // ---------------------------------------------------------------------

  Future<void> _configureAudioSession() async {
    final session = await AudioSession.instance;
    // On iOS this sets AVAudioSessionCategoryPlayback, which together with
    // the "audio" UIBackgroundMode allows playback while locked.
    // On Android it requests AUDIOFOCUS_GAIN with music attributes.
    await session.configure(const AudioSessionConfiguration.music());

    // Headphones unplugged or Bluetooth disconnected: pause.
    session.becomingNoisyEventStream.listen((_) => pause());

    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.duck:
            // A notification sound or navigation prompt: lower the volume.
            if (_player.playing) {
              _ducked = true;
              _player.setVolume(_duckVolume);
            }
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            // Phone call, alarm, or another app took focus.
            if (_player.playing) {
              _player.pause();
              _pausedByInterruption = true;
            }
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.duck:
            if (_ducked) {
              _ducked = false;
              _player.setVolume(1.0);
            }
          case AudioInterruptionType.pause:
            // Temporary interruption ended (e.g. the call hung up): resume.
            if (_pausedByInterruption) play();
            _pausedByInterruption = false;
          case AudioInterruptionType.unknown:
            // Another app took focus permanently: stay paused.
            _pausedByInterruption = false;
        }
      }
    });
  }

  // ---------------------------------------------------------------------
  // Public queue API (called directly by the UI through Riverpod)
  // ---------------------------------------------------------------------

  /// Replaces the queue with [tracks] and starts playing [startIndex].
  Future<void> playTracks(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    queue.add(tracks.map((t) => t.toMediaItem()).toList());
    _index = null;
    _rebuildOrder(current: startIndex);
    await _loadIndex(startIndex, autoplay: true);
  }

  /// Inserts [track] right after the current one.
  Future<void> playNext(Track track) async {
    if (_index == null) return playTracks([track]);
    final items = [...queue.value]..insert(_index! + 1, track.toMediaItem());
    queue.add(items);
    _rebuildOrder(current: _index!);
    // In shuffle mode "play next" should still mean next.
    _order
      ..remove(_index! + 1)
      ..insert(_order.indexOf(_index!) + 1, _index! + 1);
    _prefetchNext();
  }

  /// Appends [tracks] to the end of the queue.
  Future<void> addToQueue(List<Track> tracks) async {
    if (_index == null) return playTracks(tracks);
    queue.add([...queue.value, ...tracks.map((t) => t.toMediaItem())]);
    _rebuildOrder(current: _index!);
    _prefetchNext();
  }

  /// Moves a queue item, for drag-to-reorder.
  Future<void> moveQueueItem(int from, int to) async {
    final items = [...queue.value];
    final item = items.removeAt(from);
    items.insert(to, item);
    if (_index != null) {
      final current = queue.value[_index!];
      _index = items.indexOf(current);
    }
    queue.add(items);
    if (_index != null) _rebuildOrder(current: _index!);
    _broadcastState();
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    final items = [...queue.value]..removeAt(index);
    final current = _index;
    queue.add(items);

    if (items.isEmpty) {
      _index = null;
      _order = [];
      return stop();
    }
    if (current == null) return;
    if (index < current) {
      _index = current - 1;
    } else if (index == current) {
      // Removed the playing track: continue with whatever is now there.
      final next = min(index, items.length - 1);
      _rebuildOrder(current: next);
      return _loadIndex(next, autoplay: _player.playing || _autoplay);
    }
    _rebuildOrder(current: _index!);
    _broadcastState();
  }

  // ---------------------------------------------------------------------
  // Transport controls. These are also invoked by the notification, lock
  // screen, Bluetooth headsets and Android Auto.
  // ---------------------------------------------------------------------

  @override
  Future<void> play() async {
    _pausedByInterruption = false;
    if (_index == null) return;
    if (_error != null || _player.audioSource == null) {
      // Recover from an error state, or from a URL that was never loaded.
      return _loadIndex(_index!,
          autoplay: true, start: _lastPosition, attempt: _retries + 1);
    }
    if (_resolving) {
      _autoplay = true;
      _broadcastState();
      return;
    }
    // Don't await: play() completes only when playback stops.
    unawaited(_player.play());
  }

  @override
  Future<void> pause() async {
    _pausedByInterruption = false;
    _autoplay = false;
    await _player.pause();
    _broadcastState();
  }

  @override
  Future<void> stop() async {
    _loadToken++;
    _resolving = false;
    _autoplay = false;
    cancelSleepTimer();
    await _player.stop();
    // Idle processing state tells audio_service to stop the foreground
    // service and remove the notification.
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    final next = _nextIndex(userInitiated: true);
    if (next != null) await _loadIndex(next, autoplay: true);
  }

  @override
  Future<void> skipToPrevious() async {
    // Like most players: restart the track if more than 3s in.
    if (_player.position > const Duration(seconds: 3) || _index == null) {
      return _player.seek(Duration.zero);
    }
    final pos = _order.indexOf(_index!);
    int? prev;
    if (pos > 0) {
      prev = _order[pos - 1];
    } else if (_repeatMode == AudioServiceRepeatMode.all && _order.isNotEmpty) {
      prev = _order.last;
    }
    if (prev == null) return _player.seek(Duration.zero);
    await _loadIndex(prev, autoplay: true);
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= queue.value.length) return;
    if (_shuffleMode == AudioServiceShuffleMode.all) {
      _rebuildOrder(current: index);
    }
    await _loadIndex(index, autoplay: true);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    // `group` is unused here; treat it as repeat all.
    _repeatMode = repeatMode == AudioServiceRepeatMode.group
        ? AudioServiceRepeatMode.all
        : repeatMode;
    _broadcastState();
    _prefetchNext();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    _shuffleMode = shuffleMode == AudioServiceShuffleMode.none
        ? AudioServiceShuffleMode.none
        : AudioServiceShuffleMode.all;
    if (_index != null) _rebuildOrder(current: _index!);
    _broadcastState();
    _prefetchNext();
  }

  /// Called when the user swipes the app away from recents. Keep playing if
  /// audio is playing, as users expect from a music app. Otherwise stop the
  /// service so no stale notification is left behind.
  @override
  Future<void> onTaskRemoved() async {
    if (!_player.playing) await stop();
  }

  // ---------------------------------------------------------------------
  // Sleep timer
  // ---------------------------------------------------------------------

  /// Pauses playback after [duration]. Dart timers keep running in the
  /// background because the foreground service keeps the app alive.
  void setSleepTimer(Duration duration) {
    _sleepTimer?.cancel();
    var remaining = duration;
    sleepTimer.add(SleepTimerState.countdown(remaining));
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      remaining -= const Duration(seconds: 1);
      if (remaining <= Duration.zero) {
        t.cancel();
        sleepTimer.add(const SleepTimerState.off());
        pause();
      } else {
        sleepTimer.add(SleepTimerState.countdown(remaining));
      }
    });
  }

  /// Pauses when the current track ends. See [_onTrackCompleted].
  void setSleepAtEndOfTrack() {
    _sleepTimer?.cancel();
    sleepTimer.add(const SleepTimerState.endOfTrack());
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    sleepTimer.add(const SleepTimerState.off());
  }

  // ---------------------------------------------------------------------
  // Loading, errors and retries
  // ---------------------------------------------------------------------

  /// Resolves the stream URL for queue item [index] and loads it.
  Future<void> _loadIndex(
    int index, {
    required bool autoplay,
    Duration start = Duration.zero,
    int attempt = 0,
  }) async {
    final token = ++_loadToken;
    final item = queue.value[index];

    if (_index != index) {
      _retries = 0;
      _retryPosition = Duration.zero;
      _library.addToHistory(Track.fromMediaItem(item));
    }
    _index = index;
    _error = null;
    _resolving = true;
    _autoplay = autoplay;
    _lastPosition = start;
    mediaItem.add(item);
    _broadcastState();

    // Silence the previous track while the next one resolves.
    if (_player.playing &&
        _player.processingState != ProcessingState.completed) {
      await _player.pause();
    }

    try {
      debugPrint('BgTube: resolving ${item.id} (attempt $attempt)');
      final url = await _youtube.audioUrl(item.id, attempt: attempt);
      debugPrint('BgTube: resolved (token $token/$_loadToken)');
      if (token != _loadToken) return;

      debugPrint('BgTube: loading ${url.host}');
      // Without a timeout a stalled connection would leave the UI
      // spinning forever; a timeout becomes a retry instead.
      final duration = await _player
          .setAudioSource(AudioSource.uri(url, tag: item),
              initialPosition: start)
          .timeout(_loadTimeout);
      if (token != _loadToken) return;
      _resolving = false;
      debugPrint('BgTube: ready, duration $duration');

      // Search results sometimes lack a duration; fill it in so the
      // notification seek bar works.
      if (duration != null && item.duration != duration) {
        _replaceItem(index, item.copyWith(duration: duration));
      }

      if (_autoplay) {
        unawaited(_player.play());
      } else if (_player.playing) {
        await _player.pause();
      }
      _broadcastState();
      _prefetchNext();
    } catch (e) {
      debugPrint('BgTube: load failed (token $token/$_loadToken): $e');
      if (token != _loadToken) return;
      _resolving = false;
      await _handleError(e, token);
    }
  }

  Future<void> _handleError(Object e, int token) async {
    // PlayerException is usually an expired or throttled URL (HTTP 403),
    // so treat it as retryable.
    final error = e is PlayerException
        ? AppError(AppErrorKind.unknown, '${e.code}: ${e.message}')
        : AppError.from(e);
    debugPrint('BgTube playback error: $error');

    final index = _index;
    if (index == null) return;

    // Retry everything, not only network errors: a video one client
    // reports as unplayable often plays through another client.
    if (_retries < _maxRetries) {
      _retries++;
      _retryPosition = _lastPosition;
      final wasPlaying = _autoplay || _player.playing;
      // Short backoff: 1s, then 2s.
      await Future<void>.delayed(Duration(seconds: _retries));
      if (token != _loadToken) return;
      return _loadIndex(index,
          autoplay: wasPlaying, start: _lastPosition, attempt: _retries);
    }

    _error = error;
    _autoplay = false;
    _broadcastState();
    errors.add(error);

    // In a playlist, skip videos that can never play instead of stalling.
    final permanent = error.kind == AppErrorKind.unavailable ||
        error.kind == AppErrorKind.ageRestricted;
    final next = _nextIndex();
    if (permanent && next != null) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (token == _loadToken) await _loadIndex(next, autoplay: true);
    }
  }

  Future<void> _onTrackCompleted() async {
    if (sleepTimer.value.endOfTrack) {
      cancelSleepTimer();
      await _player.pause();
      await _player.seek(Duration.zero);
      return;
    }
    if (_repeatMode == AudioServiceRepeatMode.one) {
      await _player.seek(Duration.zero);
      unawaited(_player.play());
      return;
    }
    final next = _nextIndex();
    if (next != null) {
      await _loadIndex(next, autoplay: true);
    } else {
      // End of queue.
      await _player.pause();
      await _player.seek(Duration.zero);
    }
  }

  /// Next index in play order. Repeat-one only applies to natural track
  /// endings, so the next button always advances.
  int? _nextIndex({bool userInitiated = false}) {
    if (_index == null || _order.isEmpty) return null;
    final pos = _order.indexOf(_index!);
    if (pos >= 0 && pos + 1 < _order.length) return _order[pos + 1];
    final wrap = _repeatMode == AudioServiceRepeatMode.all ||
        (userInitiated && _repeatMode == AudioServiceRepeatMode.one);
    return wrap ? _order.first : null;
  }

  void _prefetchNext() {
    final next = _nextIndex();
    if (next != null && next != _index) {
      _youtube.prefetchAudio(queue.value[next].id);
    }
  }

  void _rebuildOrder({required int current}) {
    final n = queue.value.length;
    _order = List.generate(n, (i) => i);
    if (_shuffleMode == AudioServiceShuffleMode.all && n > 1) {
      _order
        ..remove(current)
        ..shuffle(_random)
        ..insert(0, current);
    }
  }

  void _replaceItem(int index, MediaItem item) {
    final items = [...queue.value];
    items[index] = item;
    queue.add(items);
    if (index == _index) mediaItem.add(item);
  }

  // ---------------------------------------------------------------------
  // State broadcasting
  // ---------------------------------------------------------------------

  /// Publishes the current state to the notification, the lock screen
  /// and the UI.
  void _broadcastState() {
    // While a URL resolves, report the intended play state. If this
    // reported "paused" between tracks, Android would demote the foreground
    // service while the screen is off and could kill the app mid-queue.
    final playing = _resolving ? _autoplay : _player.playing;

    final AudioProcessingState processingState;
    if (_resolving) {
      processingState = AudioProcessingState.loading;
    } else if (_error != null) {
      processingState = AudioProcessingState.error;
    } else {
      processingState = switch (_player.processingState) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      };
    }

    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      // `seek` enables the draggable seek bar in the Android 13+
      // notification and on the lock screen.
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.setRepeatMode,
        MediaAction.setShuffleMode,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: processingState,
      playing: playing,
      updatePosition: _resolving ? _lastPosition : _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _index,
      repeatMode: _repeatMode,
      shuffleMode: _shuffleMode,
      errorCode: _error?.kind.index,
      errorMessage: _error?.title,
    ));
  }
}
