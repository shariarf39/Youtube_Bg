# BgTube

A Flutter app that plays YouTube audio, or video, and keeps playing when the screen is off, the app is minimised, or you switch apps.

- Opens straight into a YouTube feed: "For you" (related to your last played video), Trending, Music, Bangla, Lofi, Podcasts, News, Gaming
- Search with YouTube's own autocomplete suggestions as you type (no API key needed)
- Audio-only by default. Video mode shows the picture while the app is open.
- Media notification and lock-screen controls: play/pause, next, previous, seek bar, title and artwork
- Queue with shuffle, repeat one/all, play next, drag to reorder and swipe to remove
- Mini-player on every screen, plus a full Now Playing screen
- Sleep timer: 15, 30 or 60 minutes, or the end of the current track
- History and favourites stored locally with Hive
- Material 3, dark theme

## Project structure

```
lib/
├── main.dart                         # Hive init, audio service start, ProviderScope
├── app.dart                          # MaterialApp, M3 dark theme, first-run setup gate
├── domain/models/
│   ├── track.dart                    # App track model (+ MediaItem / Hive map conversion)
│   ├── app_error.dart                # User-facing error kinds and messages
│   ├── sleep_timer_state.dart
├── data/
│   ├── services/
│   │   ├── audio_handler.dart        # Custom BaseAudioHandler: queue, retries, focus, sleep timer
│   │   ├── youtube_service.dart      # youtube_explode_dart wrapper and stream selection
│   │   ├── stream_url_cache.dart     # Expiry-aware stream URL cache
│   │   └── permission_service.dart   # Notification and battery-optimisation permissions
│   └── repositories/
│       ├── youtube_repository.dart   # Search, suggestions, home feed, cached URLs, prefetch
│       ├── library_repository.dart   # History and favourites (Hive)
│       └── settings_repository.dart  # Video mode and onboarding flag (Hive)
└── presentation/
    ├── providers/                    # Riverpod providers and notifiers
    ├── screens/                      # Home, Search, Library, Now Playing, Background setup
    └── widgets/                      # Mini-player, seek bar, track tile, sheets, video pane
```

## How background playback works

1. **audio_service** runs playback in an Android foreground service of type `mediaPlayback`, with a media notification. Android doesn't kill a foreground media service when the screen is off. The same service publishes lock-screen and Bluetooth controls on both platforms.
2. **just_audio** (ExoPlayer on Android, AVPlayer on iOS) plays the audio-only stream. The custom `BgTubeAudioHandler` sits between the two.
3. While the next track's URL is resolving, the handler still reports "playing". This keeps the service in the foreground between tracks, so a queue keeps advancing with the screen off.
4. The next track's URL is prefetched while the current one plays, so moving to the next track takes no network round trip.
5. **Video mode** plays a muted video-only stream (mp4/H.264, 720p or lower) that follows the audio player's position. Audio always comes from the background service. When the app goes to the background, the video is released and audio continues without a break.

## Robustness

| Problem | How it's handled |
|---|---|
| Stream URL expired (HTTP 403) | On a player error, the handler drops the cached URL, re-fetches it, and resumes at the same position. It retries up to 2 times, waiting 1s and then 2s. The retry count resets after a minute of healthy playback. |
| Best audio stream | Highest bitrate audio-only stream from Opus/WebM or M4A; Opus wins a tie. On iOS, M4A only, because AVPlayer can't play WebM. Dubbed videos use the original audio track. Live streams use HLS. |
| URL cache | Entries expire 10 minutes before YouTube's own `expire` time. Simultaneous requests for the same video share one network call. |
| Video unavailable or age-restricted | Shows a clear message. In a queue, skips to the next track after 2 seconds. |
| No internet | Retried, then shown as "No internet connection" with a Try again button. |
| Phone call | Pauses, then resumes when the call ends. |
| Notification sound | Lowers the volume to 30%, then restores it. |
| Headphones unplugged or Bluetooth disconnected | Pauses. |
| Another music app starts | Pauses and stays paused. |

## Setup

### 1. Prerequisites

- Flutter 3.44 or newer (Dart 3.12). Tested with Flutter 3.44.7.
- Android SDK with platform **API 37** installed, because `permission_handler_android` requires compiling against it. Install it in Android Studio → SDK Manager.
- For iOS: macOS with Xcode and CocoaPods.

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Android configuration (already applied in this repo)

**`android/app/src/main/AndroidManifest.xml`**: add these inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"/>
```

Add these inside `<application>`:

```xml
<service
    android:name="com.ryanheise.audioservice.AudioService"
    android:foregroundServiceType="mediaPlayback"
    android:exported="true">
    <intent-filter>
        <action android:name="android.media.browse.MediaBrowserService"/>
    </intent-filter>
</service>

<receiver
    android:name="com.ryanheise.audioservice.MediaButtonReceiver"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.MEDIA_BUTTON"/>
    </intent-filter>
</receiver>
```

**`android/app/src/main/kotlin/com/bgtube/bgtube/MainActivity.kt`**:

```kotlin
package com.bgtube.bgtube

import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity()
```

**`android/app/build.gradle.kts`**: set `compileSdk = 37`. `minSdk` and `targetSdk` stay at Flutter's defaults.

The app requests the runtime permissions itself. On first launch, the **Background playback** screen asks for notification permission (Android 13+) and for exemption from battery optimisation. It also lists extra steps for Xiaomi, Samsung, Oppo, Vivo, Realme and Huawei phones. You can reopen this screen any time from the battery icon in the app bar.

### 4. iOS configuration (already applied in this repo)

**`ios/Runner/Info.plist`**: add this inside the top-level `<dict>`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

The audio session is set to the playback category in code (`AudioSessionConfiguration.music()` in `audio_handler.dart`). No other iOS change is needed. Then run:

```bash
cd ios && pod install && cd ..
```

### 5. Run

```bash
flutter run --release        # on a connected device
flutter build apk --release  # APK in build/app/outputs/flutter-apk/
```

Test background behaviour with a **release** build. Debug builds run much slower and keep a debugger connection, which can change how the system treats the app.

## Testing on a real Android device

1. Install the release build and open it. On the Background playback screen, allow notifications and battery optimisation.
2. Search for a long video, such as a 1-hour mix, and play it.
3. Check that the notification shows the title, artwork, previous/play/next and a seek bar. Drag the seek bar.
4. **Screen-off test:** lock the phone and leave it for at least 10 minutes. Audio must keep playing. Use the lock-screen controls to pause, resume and skip.
5. **Queue test:** tap a video in the feed (the whole list becomes the queue), lock the screen, and let at least 2 tracks advance on their own.
6. **App-switch test:** press Home, open another app for a few minutes, then come back. Playback and the mini-player should still be in sync.
7. **Audio focus:** call the phone (it should pause, then resume after hang-up), unplug headphones (it should pause), and trigger a notification sound (it should duck).
8. **Sleep timer:** set 15 minutes, lock the phone, and confirm it pauses.

If playback stops with the screen off on a Xiaomi, Oppo, Vivo or Huawei phone, apply the extra steps listed on the Background playback screen. These OEMs have their own task killers on top of Android's battery optimisation.

### Automated checks

```bash
flutter analyze   # no issues
flutter test      # model round-trip and error-mapping tests
```

## Notes

- **youtube_explode_dart** reverse-engineers YouTube's internal APIs. When YouTube changes them, extraction can break until the package is updated, so keep it current (`flutter pub upgrade youtube_explode_dart`).
- The package itself notes that age-restricted videos can't be played without signing in. BgTube shows the "Age-restricted video" message for these.
- Playing YouTube content outside the official apps may go against YouTube's Terms of Service. Use this app for personal and educational purposes.
