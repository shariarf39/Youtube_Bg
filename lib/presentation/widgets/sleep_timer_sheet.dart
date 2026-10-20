import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import '../providers/player_providers.dart';
import 'format.dart';

/// Bottom sheet for choosing a sleep timer.
class SleepTimerSheet extends ConsumerWidget {
  const SleepTimerSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (_) => const SleepTimerSheet(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.read(audioHandlerProvider);
    final timer = ref.watch(sleepTimerProvider).value;

    void pick(VoidCallback action) {
      action();
      Navigator.pop(context);
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Sleep timer', style: Theme.of(context).textTheme.titleMedium),
          if (timer?.remaining != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Stops in ${formatDuration(timer!.remaining)}'),
            ),
          if (timer?.endOfTrack == true)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Stops at the end of this track'),
            ),
          const SizedBox(height: 8),
          for (final minutes in const [15, 30, 60])
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: Text('$minutes minutes'),
              onTap: () => pick(
                  () => handler.setSleepTimer(Duration(minutes: minutes))),
            ),
          ListTile(
            leading: const Icon(Icons.music_off_outlined),
            title: const Text('End of current track'),
            onTap: () => pick(handler.setSleepAtEndOfTrack),
          ),
          if (timer?.isActive == true)
            ListTile(
              leading: const Icon(Icons.timer_off_outlined),
              title: const Text('Turn off timer'),
              onTap: () => pick(handler.cancelSleepTimer),
            ),
        ],
      ),
    );
  }
}
