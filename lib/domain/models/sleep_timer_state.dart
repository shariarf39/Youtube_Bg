/// Current sleep timer setting, published by the audio handler.
class SleepTimerState {
  const SleepTimerState.off()
      : remaining = null,
        endOfTrack = false;

  const SleepTimerState.countdown(Duration this.remaining) : endOfTrack = false;

  const SleepTimerState.endOfTrack()
      : remaining = null,
        endOfTrack = true;

  /// Time left, when a fixed-length timer is running.
  final Duration? remaining;

  /// True when playback stops after the current track.
  final bool endOfTrack;

  bool get isActive => remaining != null || endOfTrack;
}
