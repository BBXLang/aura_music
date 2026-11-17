import 'package:flutter/services.dart';

import '../models/track.dart';

/// Supported audio output quality tiers.
enum AudioQuality { audioVivid, hiRes, sqLossless, hq320 }

/// Display labels for [AudioQuality].
extension AudioQualityX on AudioQuality {
  /// Human-readable quality label shown in player controls.
  String get label {
    switch (this) {
      case AudioQuality.audioVivid:
        return 'AudioVivid';
      case AudioQuality.hiRes:
        return 'Hi-Res';
      case AudioQuality.sqLossless:
        return 'SQ 无损';
      case AudioQuality.hq320:
        return 'HQ 320k';
    }
  }
}

/// Playback repetition and queue termination modes.
enum PlayMode { loopList, loopOne, playOnce }

/// Display labels for [PlayMode].
extension PlayModeX on PlayMode {
  /// Human-readable play mode label.
  String get label {
    switch (this) {
      case PlayMode.loopList:
        return '列表循环';
      case PlayMode.loopOne:
        return '单曲循环';
      case PlayMode.playOnce:
        return '单曲播完';
    }
  }
}

/// Bridge to HarmonyOS (OHOS) native AVPlayer, AVSession, and desktop lyrics
/// float window via [MethodChannel].
///
/// Safely falls back to a no-op on non-OHOS platforms and in unit tests where
/// the platform channel is not registered.
class OhosAudioBridge {
  /// Creates an [OhosAudioBridge] targeting `com.auramusic/ohos_audio`.
  const OhosAudioBridge({MethodChannel? channel})
    : _channel = channel ?? _defaultChannel;

  static const MethodChannel _defaultChannel = MethodChannel(
    'com.auramusic/ohos_audio',
  );

  final MethodChannel _channel;

  Future<void> _invokeSafe(String method, [Map<String, dynamic>? args]) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on MissingPluginException {
      // Safe no-op fallback on non-OHOS platforms or test environments.
    } on PlatformException {
      // Ignore native channel errors so UI state stays responsive.
    }
  }

  /// Starts AVPlayer playback for [track] and syncs AVSession metadata.
  Future<void> playTrack(
    Track track, {
    AudioQuality quality = AudioQuality.hiRes,
  }) async {
    await _invokeSafe('playTrack', {
      'id': track.id,
      'title': track.title,
      'artist': track.artist,
      'album': track.album,
      'durationSeconds': track.durationSeconds,
      'sourceId': track.sourceId,
      'quality': quality.name,
    });
  }

  /// Pauses AVPlayer and updates AVSession playback state.
  Future<void> pause() => _invokeSafe('pause');

  /// Resumes AVPlayer and updates AVSession playback state.
  Future<void> resume() => _invokeSafe('resume');

  /// Seeks AVPlayer to [positionSeconds].
  Future<void> seek(int positionSeconds) => _invokeSafe('seek', {
    'positionSeconds': positionSeconds < 0 ? 0 : positionSeconds,
  });

  /// Updates the active streaming/decoding [AudioQuality] tier.
  Future<void> setQuality(AudioQuality quality) =>
      _invokeSafe('setQuality', {'quality': quality.name});

  /// Pushes updated media metadata to the system AVSession controller.
  Future<void> updateMetadata(Track track) => _invokeSafe('updateMetadata', {
    'id': track.id,
    'title': track.title,
    'artist': track.artist,
    'album': track.album,
    'durationSeconds': track.durationSeconds,
  });

  /// Syncs AVSession play/pause state and position.
  Future<void> updatePlaybackState({
    required bool isPlaying,
    required int positionSeconds,
  }) => _invokeSafe('updatePlaybackState', {
    'isPlaying': isPlaying,
    'positionSeconds': positionSeconds < 0 ? 0 : positionSeconds,
  });

  /// Toggles the HarmonyOS floating desktop lyrics window.
  Future<void> setDesktopLyricsEnabled(bool enabled, {String? currentLyric}) =>
      _invokeSafe('setDesktopLyricsEnabled', {
        'enabled': enabled,
        if (currentLyric != null) 'currentLyric': currentLyric,
      });

  /// Updates the text displayed in the desktop lyrics float window.
  Future<void> updateDesktopLyricLine(String line) =>
      _invokeSafe('updateDesktopLyricLine', {'line': line});
}
