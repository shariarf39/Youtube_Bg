import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import '../providers/player_providers.dart';
import 'format.dart';

/// A draggable seek bar with elapsed and total time.
///
/// While dragging it shows the drag position and seeks only on release, so
/// the stream isn't asked for many ranges in a row.
class SeekBar extends ConsumerStatefulWidget {
  const SeekBar({super.key});

  @override
  ConsumerState<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends ConsumerState<SeekBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final duration =
        ref.watch(currentMediaItemProvider).value?.duration ?? Duration.zero;
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final max = duration.inMilliseconds.toDouble();
    final value = (_dragValue ?? position.inMilliseconds.toDouble())
        .clamp(0.0, max > 0 ? max : 1.0);
    final style = Theme.of(context).textTheme.bodySmall;

    return Column(
      children: [
        Slider(
          value: value,
          max: max > 0 ? max : 1.0,
          onChanged: max > 0 ? (v) => setState(() => _dragValue = v) : null,
          onChangeEnd: (v) {
            ref
                .read(audioHandlerProvider)
                .seek(Duration(milliseconds: v.round()));
            setState(() => _dragValue = null);
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatDuration(Duration(milliseconds: value.round())),
                  style: style),
              Text(max > 0 ? formatDuration(duration) : 'LIVE', style: style),
            ],
          ),
        ),
      ],
    );
  }
}
