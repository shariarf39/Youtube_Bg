import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Error categories the UI knows how to explain to the user.
enum AppErrorKind {
  noInternet,
  unavailable,
  ageRestricted,
  rateLimited,
  timeout,
  unknown,
}

/// An error with a user-facing message. Repositories convert raw exceptions
/// into this type so screens never need to inspect library exceptions.
class AppError implements Exception {
  const AppError(this.kind, [this.details]);

  final AppErrorKind kind;

  /// Raw error text, for logs only.
  final String? details;

  /// Maps any thrown object to an [AppError].
  factory AppError.from(Object error) {
    if (error is AppError) return error;
    if (error is TimeoutException) {
      return AppError(AppErrorKind.timeout, error.toString());
    }
    if (error is SocketException ||
        error is http.ClientException ||
        error is HandshakeException) {
      return AppError(AppErrorKind.noInternet, error.toString());
    }
    if (error is RequestLimitExceededException) {
      return AppError(AppErrorKind.rateLimited, error.toString());
    }
    if (error is VideoUnplayableException) {
      final msg = error.message.toLowerCase();
      // YouTube reports age gates as "sign in to confirm your age" or similar.
      if (msg.contains('age') ||
          msg.contains('sign in') ||
          msg.contains('inappropriate')) {
        return AppError(AppErrorKind.ageRestricted, error.message);
      }
      return AppError(AppErrorKind.unavailable, error.message);
    }
    return AppError(AppErrorKind.unknown, error.toString());
  }

  String get title => switch (kind) {
        AppErrorKind.noInternet => 'No internet connection',
        AppErrorKind.unavailable => 'Video unavailable',
        AppErrorKind.ageRestricted => 'Age-restricted video',
        AppErrorKind.rateLimited => 'Too many requests',
        AppErrorKind.timeout => 'Taking too long',
        AppErrorKind.unknown => 'Something went wrong',
      };

  String get message => switch (kind) {
        AppErrorKind.noInternet =>
          'Check your Wi-Fi or mobile data and try again.',
        AppErrorKind.unavailable =>
          'This video is private, removed, or blocked in your region.',
        AppErrorKind.ageRestricted =>
          'YouTube requires sign-in for this video, so BgTube can\'t play it.',
        AppErrorKind.rateLimited =>
          'YouTube is limiting requests. Wait a minute and try again.',
        AppErrorKind.timeout =>
          'YouTube didn\'t respond in time. Check your connection and try again.',
        AppErrorKind.unknown => 'Please try again.',
      };

  /// Whether retrying with a fresh stream URL could help.
  bool get isRetryable =>
      kind == AppErrorKind.noInternet ||
      kind == AppErrorKind.timeout ||
      kind == AppErrorKind.unknown;

  @override
  String toString() => 'AppError($kind: $details)';
}
