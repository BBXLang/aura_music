import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import '../models/track.dart';
import 'ohos_audio_bridge.dart';

/// Cross-platform audio playback engine abstraction for AuraMusic.
abstract class AudioEngineAdapter {
  /// Starts playback from a remote HTTP/HTTPS audio [url].
  Future<void> playUrl(String url);

  /// Starts playback from a local file [path].
  Future<void> playFile(String path);

  /// Pauses current playback.
  Future<void> pause();

  /// Resumes paused playback.
  Future<void> resume();

  /// Seeks to [position].
  Future<void> seek(Duration position);

  /// Stops playback and resets the active source.
  Future<void> stop();

  /// Sets playback volume in `[0.0, 1.0]`.
  Future<void> setVolume(double volume);

  /// Emits playback position updates.
  Stream<Duration> get positionStream;

  /// Emits total track duration updates.
  Stream<Duration> get durationStream;

  /// Emits an event when the active track finishes playing.
  Stream<void> get onCompleted;

  /// Releases underlying native or stream resources.
  Future<void> dispose();
}

/// [AudioEngineAdapter] backed by `package:audioplayers`.
class AudioPlayersEngine implements AudioEngineAdapter {
  /// Creates an [AudioPlayersEngine], optionally injecting a custom [AudioPlayer].
  AudioPlayersEngine({AudioPlayer? player})
    : _player = player ?? AudioPlayer() {
    _player.positionUpdater = TimerPositionUpdater(
      getPosition: _player.getCurrentPosition,
      interval: const Duration(milliseconds: 250),
    );
  }

  final AudioPlayer _player;
  int _opToken = 0;

  Future<void> _runSafe(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Swallow platform/codec exceptions so UI state remains responsive.
    }
  }

  @override
  Future<void> playUrl(String url) async {
    final token = ++_opToken;
    await _runSafe(_player.stop);
    if (token != _opToken) return;
    await _runSafe(() => _player.play(UrlSource(url)));
  }

  @override
  Future<void> playFile(String path) async {
    final token = ++_opToken;
    await _runSafe(_player.stop);
    if (token != _opToken) return;
    await _runSafe(() => _player.play(DeviceFileSource(path)));
  }

  @override
  Future<void> pause() {
    ++_opToken;
    return _runSafe(_player.pause);
  }

  @override
  Future<void> resume() => _runSafe(_player.resume);

  @override
  Future<void> seek(Duration position) {
    final safePosition = position.isNegative ? Duration.zero : position;
    return _runSafe(() => _player.seek(safePosition));
  }

  @override
  Future<void> stop() {
    ++_opToken;
    return _runSafe(_player.stop);
  }

  @override
  Future<void> setVolume(double volume) =>
      _runSafe(() => _player.setVolume(volume.clamp(0.0, 1.0)));

  @override
  Stream<Duration> get positionStream => _player.onPositionChanged;

  @override
  Stream<Duration> get durationStream => _player.onDurationChanged;

  @override
  Stream<void> get onCompleted => _player.onPlayerComplete;

  @override
  Future<void> dispose() => _runSafe(_player.dispose);
}

/// [AudioEngineAdapter] delegating playback control to [OhosAudioBridge].
class OhosAudioEngine implements AudioEngineAdapter {
  /// Creates an [OhosAudioEngine] backed by [bridge].
  OhosAudioEngine({OhosAudioBridge? bridge})
    : _bridge = bridge ?? const OhosAudioBridge();

  final OhosAudioBridge _bridge;
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();
  final StreamController<void> _completedController =
      StreamController<void>.broadcast();
  bool _disposed = false;

  Track _buildSyntheticTrack({
    required String source,
    String? localPath,
    String? streamUrl,
  }) {
    return Track(
      id: source,
      title: source,
      artist: '',
      album: '',
      quality: 'Hi-Res',
      sourceId: localPath != null ? 'local' : 'ohos',
      durationSeconds: 0,
      colors: const [],
      lyrics: const [],
      localPath: localPath,
      streamUrl: streamUrl,
    );
  }

  @override
  Future<void> playUrl(String url) =>
      _bridge.playTrack(_buildSyntheticTrack(source: url, streamUrl: url));

  @override
  Future<void> playFile(String path) =>
      _bridge.playTrack(_buildSyntheticTrack(source: path, localPath: path));

  @override
  Future<void> pause() => _bridge.pause();

  @override
  Future<void> resume() => _bridge.resume();

  @override
  Future<void> seek(Duration position) {
    final safeSeconds = position.isNegative ? 0 : position.inSeconds;
    if (!_disposed) {
      _positionController.add(Duration(seconds: safeSeconds));
    }
    return _bridge.seek(safeSeconds);
  }

  @override
  Future<void> stop() async {
    await _bridge.pause();
    if (!_disposed) {
      _positionController.add(Duration.zero);
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    // System AVPlayer volume is managed via HarmonyOS hardware/AVSession keys.
  }

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration> get durationStream => _durationController.stream;

  @override
  Stream<void> get onCompleted => _completedController.stream;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _positionController.close();
    await _durationController.close();
    await _completedController.close();
  }
}

/// In-memory no-op [AudioEngineAdapter] for unit and widget tests.
class NoopAudioEngine implements AudioEngineAdapter {
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();
  final StreamController<void> _completedController =
      StreamController<void>.broadcast();

  bool _isPlaying = false;
  bool _disposed = false;
  String? _currentSource;
  Duration _currentPosition = Duration.zero;
  double _volume = 1.0;

  /// Whether playback is currently active.
  bool get isPlaying => _isPlaying;

  /// The last played URL or file path, or `null` when stopped.
  String? get currentSource => _currentSource;

  /// The most recent playback position.
  Duration get currentPosition => _currentPosition;

  /// The current playback volume in `[0.0, 1.0]`.
  double get volume => _volume;

  void _emitPosition(Duration position) {
    _currentPosition = position;
    if (!_disposed) {
      _positionController.add(position);
    }
  }

  /// Pushes a synthetic position update for tests.
  void emitPosition(Duration position) => _emitPosition(position);

  /// Pushes a synthetic duration update for tests.
  void emitDuration(Duration duration) {
    if (!_disposed) {
      _durationController.add(duration);
    }
  }

  /// Pushes a synthetic track completion event for tests.
  void emitCompleted() {
    _isPlaying = false;
    if (!_disposed) {
      _completedController.add(null);
    }
  }

  @override
  Future<void> playUrl(String url) async {
    _currentSource = url;
    _isPlaying = true;
    _emitPosition(Duration.zero);
  }

  @override
  Future<void> playFile(String path) async {
    _currentSource = path;
    _isPlaying = true;
    _emitPosition(Duration.zero);
  }

  @override
  Future<void> pause() async {
    _isPlaying = false;
  }

  @override
  Future<void> resume() async {
    if (_currentSource != null) {
      _isPlaying = true;
    }
  }

  @override
  Future<void> seek(Duration position) async {
    _emitPosition(position.isNegative ? Duration.zero : position);
  }

  @override
  Future<void> stop() async {
    _isPlaying = false;
    _currentSource = null;
    _emitPosition(Duration.zero);
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
  }

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration> get durationStream => _durationController.stream;

  @override
  Stream<void> get onCompleted => _completedController.stream;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _positionController.close();
    await _durationController.close();
    await _completedController.close();
  }
}
