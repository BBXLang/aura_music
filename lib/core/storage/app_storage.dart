import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../audio/ohos_audio_bridge.dart';
import '../models/playlist.dart';
import '../models/source_plugin.dart';

/// Persisted user preferences and playback settings for AuraMusic.
class AppSettings {
  /// Creates an [AppSettings] instance.
  const AppSettings({
    this.ambientEnabled = true,
    this.isDark = true,
    this.desktopLyrics = false,
    this.smartLocalFilter = true,
    this.playMode = PlayMode.loopList,
    this.quality = AudioQuality.hiRes,
  });

  final bool ambientEnabled;
  final bool isDark;
  final bool desktopLyrics;
  final bool smartLocalFilter;
  final PlayMode playMode;
  final AudioQuality quality;

  /// Creates an [AppSettings] from a JSON map.
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final playModeName = json['playMode'] as String?;
    final qualityName = json['quality'] as String?;
    return AppSettings(
      ambientEnabled: json['ambientEnabled'] as bool? ?? true,
      isDark: json['isDark'] as bool? ?? true,
      desktopLyrics: json['desktopLyrics'] as bool? ?? false,
      smartLocalFilter: json['smartLocalFilter'] as bool? ?? true,
      playMode: PlayMode.values.firstWhere(
        (mode) => mode.name == playModeName,
        orElse: () => PlayMode.loopList,
      ),
      quality: AudioQuality.values.firstWhere(
        (item) => item.name == qualityName,
        orElse: () => AudioQuality.hiRes,
      ),
    );
  }

  /// Serializes this [AppSettings] to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'ambientEnabled': ambientEnabled,
      'isDark': isDark,
      'desktopLyrics': desktopLyrics,
      'smartLocalFilter': smartLocalFilter,
      'playMode': playMode.name,
      'quality': quality.name,
    };
  }

  /// Returns a copy of these settings with the specified fields replaced.
  AppSettings copyWith({
    bool? ambientEnabled,
    bool? isDark,
    bool? desktopLyrics,
    bool? smartLocalFilter,
    PlayMode? playMode,
    AudioQuality? quality,
  }) {
    return AppSettings(
      ambientEnabled: ambientEnabled ?? this.ambientEnabled,
      isDark: isDark ?? this.isDark,
      desktopLyrics: desktopLyrics ?? this.desktopLyrics,
      smartLocalFilter: smartLocalFilter ?? this.smartLocalFilter,
      playMode: playMode ?? this.playMode,
      quality: quality ?? this.quality,
    );
  }
}

/// Persistent storage wrapper for playlists, history, queues, sources, and settings.
class AppStorage {
  /// Creates an [AppStorage] backed by [SharedPreferences].
  AppStorage(SharedPreferences prefs) : _prefs = prefs, _memory = null;

  /// Creates an in-memory [AppStorage] instance for unit and widget tests.
  AppStorage.memory() : _prefs = null, _memory = <String, String>{};

  /// Asynchronously initializes [AppStorage] using [SharedPreferences.getInstance].
  static Future<AppStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    return AppStorage(prefs);
  }

  static const String _keyPlaylists = 'aura_playlists_v1';
  static const String _keyPlayHistory = 'aura_play_history_v1';
  static const String _keyRecentQueues = 'aura_recent_queues_v1';
  static const String _keySources = 'aura_sources_v1';
  static const String _keyOAuthTokens = 'aura_oauth_tokens_v1';
  static const String _keySettings = 'aura_settings_v1';

  final SharedPreferences? _prefs;
  final Map<String, String>? _memory;

  String? _readString(String key) {
    return _prefs != null ? _prefs.getString(key) : _memory![key];
  }

  Future<void> _writeString(String key, String value) async {
    if (_prefs != null) {
      await _prefs.setString(key, value);
    } else {
      _memory![key] = value;
    }
  }

  dynamic _decodeJson(String key) {
    final raw = _readString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  /// Persists [playlists] to storage.
  Future<void> savePlaylists(List<Playlist> playlists) {
    final encoded = jsonEncode(playlists.map((item) => item.toJson()).toList());
    return _writeString(_keyPlaylists, encoded);
  }

  /// Loads persisted playlists, or `null` if none have been saved.
  List<Playlist>? loadPlaylists() {
    final decoded = _decodeJson(_keyPlaylists);
    if (decoded is! List) return null;
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(Playlist.fromJson)
        .toList();
  }

  /// Persists [history] entries (`trackId` + `timestampLabel`) to storage.
  Future<void> savePlayHistory(List<Map<String, String>> history) {
    return _writeString(_keyPlayHistory, jsonEncode(history));
  }

  /// Loads persisted play history entries, or `null` if none have been saved.
  List<Map<String, String>>? loadPlayHistory() {
    final decoded = _decodeJson(_keyPlayHistory);
    if (decoded is! List) return null;
    return decoded
        .whereType<Map>()
        .map(
          (entry) => entry.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ),
        )
        .toList();
  }

  /// Persists [queues] snapshots to storage.
  Future<void> saveRecentQueues(List<Map<String, dynamic>> queues) {
    return _writeString(_keyRecentQueues, jsonEncode(queues));
  }

  /// Loads persisted recent queue snapshots, or `null` if none have been saved.
  List<Map<String, dynamic>>? loadRecentQueues() {
    final decoded = _decodeJson(_keyRecentQueues);
    if (decoded is! List) return null;
    return decoded
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  /// Persists [sources] plugin states to storage.
  Future<void> saveSources(List<SourcePlugin> sources) {
    final encoded = jsonEncode(sources.map((item) => item.toJson()).toList());
    return _writeString(_keySources, encoded);
  }

  /// Loads persisted source plugins, or `null` if none have been saved.
  List<SourcePlugin>? loadSources() {
    final decoded = _decodeJson(_keySources);
    if (decoded is! List) return null;
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(SourcePlugin.fromJson)
        .toList();
  }

  /// Persists OAuth [tokens] keyed by source plugin ID.
  Future<void> saveOAuthTokens(Map<String, String> tokens) {
    return _writeString(_keyOAuthTokens, jsonEncode(tokens));
  }

  /// Loads persisted OAuth tokens, or `null` if none have been saved.
  Map<String, String>? loadOAuthTokens() {
    final decoded = _decodeJson(_keyOAuthTokens);
    if (decoded is! Map) return null;
    return decoded.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  }

  /// Persists [settings] to storage.
  Future<void> saveSettings(AppSettings settings) {
    return _writeString(_keySettings, jsonEncode(settings.toJson()));
  }

  /// Loads persisted [AppSettings], or `null` if none have been saved.
  AppSettings? loadSettings() {
    final decoded = _decodeJson(_keySettings);
    if (decoded is! Map<String, dynamic>) return null;
    return AppSettings.fromJson(decoded);
  }

  /// Clears all AuraMusic keys from storage.
  Future<void> clearAll() async {
    const keys = [
      _keyPlaylists,
      _keyPlayHistory,
      _keyRecentQueues,
      _keySources,
      _keyOAuthTokens,
      _keySettings,
    ];
    if (_prefs != null) {
      for (final key in keys) {
        await _prefs.remove(key);
      }
    } else {
      for (final key in keys) {
        _memory!.remove(key);
      }
    }
  }
}
