# HarmonyOS NEXT (OHOS) 适配说明

本工程在 `lib/core/audio/ohos_audio_bridge.dart` 预留了 HarmonyOS NEXT 原生 `MethodChannel` 桥接协议（`com.auramusic/ohos_audio`）：
- **音频播放**：对接 `@ohos.multimedia.media` (`AVPlayer`)
- **播控中心与后台保活**：对接 `@ohos.multimedia.avsession` (`AVSession`) 与 `KEEP_BACKGROUND_RUNNING` (`backgroundModes: ["audioPlayback"]`)
- **桌面歌词**：对接 `SYSTEM_FLOAT_WINDOW` 悬浮窗能力

使用 OpenHarmony Flutter SIG (`flutter_flutter`) 工具链即可直接执行 `flutter build hap --release` 构建 `.hap` 安装包。
