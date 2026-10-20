import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';

/// Explains and requests what Android needs for reliable screen-off
/// playback: the notification permission and an exemption from battery
/// optimisation.
///
/// Shown once on first launch, and available later from Settings.
class BackgroundSetupScreen extends ConsumerStatefulWidget {
  const BackgroundSetupScreen({super.key, this.onDone});

  /// Called when the user finishes. When null, the screen just pops.
  final VoidCallback? onDone;

  @override
  ConsumerState<BackgroundSetupScreen> createState() =>
      _BackgroundSetupScreenState();
}

class _BackgroundSetupScreenState extends ConsumerState<BackgroundSetupScreen>
    with WidgetsBindingObserver {
  bool _notificationsOk = false;
  bool _batteryOk = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-check when returning from system settings.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final perms = ref.read(permissionServiceProvider);
    final n = await perms.notificationsGranted();
    final b = await perms.batteryOptimizationDisabled();
    if (mounted) {
      setState(() {
        _notificationsOk = n;
        _batteryOk = b;
      });
    }
  }

  Future<void> _finish() async {
    await ref.read(settingsRepositoryProvider).setOnboardingDone();
    if (!mounted) return;
    if (widget.onDone != null) {
      widget.onDone!();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.read(permissionServiceProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Background playback')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Icon(Icons.screen_lock_portrait,
                size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Keep music playing with the screen off',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'BgTube plays through a media notification so Android keeps it '
              'running in the background. Some phones, especially Xiaomi, '
              'Samsung, Oppo, Vivo, Realme and Huawei, still stop background '
              'apps to save battery. Two quick steps prevent that.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            _StepCard(
              done: _notificationsOk,
              icon: Icons.notifications_active_outlined,
              title: '1. Allow notifications',
              body: 'Shows play/pause, next and the seek bar in your '
                  'notification shade and on the lock screen. Without it, '
                  'Android 13+ hides the controls.',
              action: 'Allow',
              onPressed: () async {
                await perms.requestNotifications();
                await _refresh();
              },
            ),
            const SizedBox(height: 12),
            _StepCard(
              done: _batteryOk,
              icon: Icons.battery_saver_outlined,
              title: '2. Disable battery optimisation',
              body: 'Lets BgTube keep playing for hours with the screen '
                  'locked. Choose "Allow" in the next dialog.',
              action: 'Allow',
              onPressed: () async {
                await perms.requestDisableBatteryOptimization();
                await _refresh();
              },
            ),
            if (Platform.isAndroid) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Still stopping? Extra steps for your phone',
                          style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      const Text(
                        '• Xiaomi / Redmi / POCO: App info → Autostart ON, '
                        'Battery saver → No restrictions. Lock the app in '
                        'Recents.\n'
                        '• Samsung: Battery → Unrestricted, and remove BgTube '
                        'from "Sleeping apps".\n'
                        '• Oppo / Realme / Vivo: Battery → Allow background '
                        'activity, and enable Auto-launch.\n'
                        '• Huawei: Battery → App launch → Manage manually, '
                        'all switches ON.',
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: perms.openSettings,
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('Open app settings'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _finish,
              child: Text(_notificationsOk && _batteryOk
                  ? 'Done'
                  : 'Continue anyway'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.done,
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onPressed,
  });

  final bool done;
  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(body, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 8),
                  done
                      ? Row(children: [
                          Icon(Icons.check_circle,
                              size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 6),
                          const Text('Done'),
                        ])
                      : FilledButton.tonal(
                          onPressed: onPressed, child: Text(action)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
