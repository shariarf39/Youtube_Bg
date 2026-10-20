import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Runtime permissions needed for reliable background playback.
class PermissionService {
  /// Android 13+ needs POST_NOTIFICATIONS at runtime, or the media
  /// notification is hidden. Older versions grant it automatically.
  Future<bool> requestNotifications() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<bool> notificationsGranted() async {
    if (!Platform.isAndroid) return true;
    return Permission.notification.isGranted;
  }

  /// True when Android won't apply battery optimisation to this app.
  /// Always true on iOS, which has no equivalent setting.
  Future<bool> batteryOptimizationDisabled() async {
    if (!Platform.isAndroid) return true;
    return Permission.ignoreBatteryOptimizations.isGranted;
  }

  /// Shows the system "Let app always run in background?" dialog.
  /// Needs REQUEST_IGNORE_BATTERY_OPTIMIZATIONS in the manifest.
  Future<bool> requestDisableBatteryOptimization() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.ignoreBatteryOptimizations.request();
    return status.isGranted;
  }

  /// Opens this app's system settings page, for OEM-specific options such as
  /// Xiaomi "Autostart" or Samsung "Unrestricted" battery use.
  Future<void> openSettings() => openAppSettings();
}
