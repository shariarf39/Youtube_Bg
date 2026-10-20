import 'package:bgtube/domain/models/app_error.dart';
import 'package:bgtube/domain/models/track.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  test('Track survives a Hive map round trip', () {
    const track = Track(
      id: 'dQw4w9WgXcQ',
      title: 'Title',
      author: 'Channel',
      duration: Duration(minutes: 3, seconds: 33),
    );
    final back = Track.fromMap(track.toMap());
    expect(back.id, track.id);
    expect(back.duration, track.duration);
    expect(back.title, track.title);
  });

  test('age-gate errors map to ageRestricted', () {
    final e = AppError.from(
        VideoUnplayableException('Sign in to confirm your age'));
    expect(e.kind, AppErrorKind.ageRestricted);
  });

  test('removed videos map to unavailable', () {
    final e = AppError.from(VideoUnavailableException('Video unavailable'));
    expect(e.kind, AppErrorKind.unavailable);
  });
}
