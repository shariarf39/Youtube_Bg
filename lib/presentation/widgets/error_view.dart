import 'package:flutter/material.dart';

import '../../domain/models/app_error.dart';

/// A centred, friendly error message with an optional retry button.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final AppError error;
  final VoidCallback? onRetry;

  IconData get _icon => switch (error.kind) {
        AppErrorKind.noInternet => Icons.wifi_off,
        AppErrorKind.ageRestricted => Icons.no_adult_content,
        AppErrorKind.unavailable => Icons.videocam_off,
        AppErrorKind.rateLimited => Icons.hourglass_empty,
        AppErrorKind.timeout => Icons.timer_off_outlined,
        AppErrorKind.unknown => Icons.error_outline,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 56, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(error.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              error.message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
