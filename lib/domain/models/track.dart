import 'package:audio_service/audio_service.dart';

/// A single playable YouTube item.
///
/// This is the app's own model, so the UI and storage never depend directly on
/// youtube_explode_dart or audio_service types.
class Track {
  const Track({
    required this.id,
    required this.title,
    required this.author,
    this.duration,
    this.isLive = false,
  });

  /// The 11-character YouTube video id.
  final String id;
  final String title;

  /// Channel name.
  final String author;

  /// Null for live streams, or when YouTube didn't report a length.
  final Duration? duration;
  final bool isLive;

  /// hqdefault is always present, unlike maxresdefault.
  String get thumbnailUrl => 'https://i.ytimg.com/vi/$id/hqdefault.jpg';

  String get watchUrl => 'https://www.youtube.com/watch?v=$id';

  /// Converts to the type audio_service shows in the notification and lock screen.
  MediaItem toMediaItem() => MediaItem(
        id: id,
        title: title,
        artist: author,
        duration: duration,
        artUri: Uri.parse(thumbnailUrl),
        extras: {'isLive': isLive},
      );

  factory Track.fromMediaItem(MediaItem item) => Track(
        id: item.id,
        title: item.title,
        author: item.artist ?? '',
        duration: item.duration,
        isLive: item.extras?['isLive'] == true,
      );

  /// Hive stores plain maps, so no type adapters or code generation are needed.
  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'author': author,
        'durationMs': duration?.inMilliseconds,
        'isLive': isLive,
      };

  factory Track.fromMap(Map<dynamic, dynamic> map) => Track(
        id: map['id'] as String,
        title: map['title'] as String? ?? '',
        author: map['author'] as String? ?? '',
        duration: map['durationMs'] == null
            ? null
            : Duration(milliseconds: map['durationMs'] as int),
        isLive: map['isLive'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) => other is Track && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
