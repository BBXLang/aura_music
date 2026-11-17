# HarmonyOS NEXT (OHOS) Native Integration Guide

This directory contains the HarmonyOS NEXT (Stage Model) native module configuration and ArkTS audio bridge for **AuraMusic**.

## Architecture Overview

- **Dart Bridge**: `lib/core/audio/ohos_audio_bridge.dart` invokes native capabilities over `MethodChannel('com.auramusic/ohos_audio')`.
- **ArkTS Plugin**: `ohos/entry/src/main/ets/plugins/OhosAudioPlugin.ets` implements `FlutterPlugin` and `MethodCallHandler`, wiring:
  - `@ohos.multimedia.media` (`AVPlayer`) for audio playback (`playTrack` / `play`, `pause`, `resume`, `seek`, `stop`, `setQuality`)
  - `@ohos.multimedia.avsession` (`AVSession`) for lock-screen and control-center metadata/playback sync (`updateMetadata` / `updateSessionMetadata`, `updatePlaybackState`)
  - `@ohos.resourceschedule.backgroundTaskManager` (`audioPlayback`) for background audio keep-alive
  - `@ohos.window` (`TYPE_FLOAT`) subWindow stub for floating desktop lyrics (`setDesktopLyricsEnabled` / `setDesktopLyrics`, `updateDesktopLyricLine`)
- **Module Manifest**: `ohos/entry/src/main/module.json5` configures `MainAbility` with `backgroundModes: ["audioPlayback"]` and declares:
  - `ohos.permission.KEEP_BACKGROUND_RUNNING`
  - `ohos.permission.READ_AUDIO`
  - `ohos.permission.WRITE_AUDIO`
  - `ohos.permission.SYSTEM_FLOAT_WINDOW`
  - `ohos.permission.INTERNET`

## Prerequisites

1. **OpenHarmony Flutter SIG (`flutter_flutter`)**:
   - Install and configure the OpenHarmony-adapted Flutter SDK (`flutter_flutter`) on your `PATH`.
   - Verify with `flutter doctor -v` that the HarmonyOS / OpenHarmony toolchain is detected.
2. **DevEco Studio & HarmonyOS SDK**:
   - Install **DevEco Studio** (API 12+ / HarmonyOS NEXT) and the OpenHarmony/HarmonyOS SDK + `ohpm` + `hvigor`.
   - Set `DEVECO_SDK_HOME` (or configure the SDK path in DevEco Studio).

## Registering `OhosAudioPlugin`

Ensure `OhosAudioPlugin` is registered with the Flutter engine in your `MainAbility` / `EntryAbility` (or `GeneratedPluginRegistrant`):

```ts
import OhosAudioPlugin from '../plugins/OhosAudioPlugin';

// Inside configureFlutterEngine(flutterEngine: FlutterEngine)
flutterEngine.getPlugins()?.add(new OhosAudioPlugin());
```

## Building & Running

### Build `.hap` with `flutter_flutter` CLI

From the project root (`aura_music/`):

```bash
flutter pub get
flutter build hap --release
```

To run directly on a connected HarmonyOS NEXT device or emulator:

```bash
flutter devices
flutter run -d <ohos-device-id>
```

### Open in DevEco Studio (Signing & Native Debugging)

1. Open `aura_music/ohos` in **DevEco Studio**.
2. Wait for `ohpm` / `hvigor` sync to complete.
3. Configure automatic or release signing under **File > Project Structure > Project > Signing Configs**.
4. Select your target device and click **Run 'entry'** to deploy and inspect ArkTS Hilog output (`OhosAudioPlugin`).
