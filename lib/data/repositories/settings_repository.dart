import 'package:hive_ce_flutter/hive_flutter.dart';

/// Small key-value settings stored in Hive.
class SettingsRepository {
  SettingsRepository._(this._box);

  static const _boxName = 'settings';
  static const _videoModeKey = 'videoMode';
  static const _onboardingDoneKey = 'onboardingDone';

  final Box _box;

  static Future<SettingsRepository> open() async =>
      SettingsRepository._(await Hive.openBox(_boxName));

  /// Video is shown by default. Users can switch to audio-only to save
  /// data and battery.
  bool get videoMode => _box.get(_videoModeKey, defaultValue: true) as bool;
  Future<void> setVideoMode(bool value) => _box.put(_videoModeKey, value);

  /// Whether the background-playback setup screen has been shown.
  bool get onboardingDone =>
      _box.get(_onboardingDoneKey, defaultValue: false) as bool;
  Future<void> setOnboardingDone() => _box.put(_onboardingDoneKey, true);
}
