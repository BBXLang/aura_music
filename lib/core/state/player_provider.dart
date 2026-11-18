import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../audio/audio_engine.dart';
import '../audio/ohos_audio_bridge.dart';
import '../models/playlist.dart';
import '../models/source_plugin.dart';
import '../models/track.dart';
import '../playlist/playlist_codec.dart';
import '../scanner/local_music_scanner.dart';
import '../source/js_plugin_bridge.dart';
import '../source/sidecar_source_client.dart';
import '../storage/app_storage.dart';

/// Immutable snapshot of a previously active playback queue.
class QueueSnapshot {
  /// Creates a [QueueSnapshot].
  const QueueSnapshot({
    required this.name,
    required this.trackIds,
    required this.queuePos,
  });

  final String name;
  final List<String> trackIds;
  final int queuePos;
}

/// Entry recorded in the user's recent play history.
class PlayHistoryEntry {
  /// Creates a [PlayHistoryEntry].
  const PlayHistoryEntry({required this.trackId, required this.timestampLabel});

  final String trackId;
  final String timestampLabel;
}

/// Complete reactive state for AuraMusic's player, library, and settings.
class PlayerState {
  /// Creates a [PlayerState].
  const PlayerState({
    required this.tracks,
    this.hotTracks = const [],
    this.searchResults = const [],
    required this.playlists,
    required this.sources,
    required this.queueName,
    required this.queue,
    required this.queuePos,
    required this.recentQueues,
    required this.playHistory,
    required this.isPlaying,
    required this.progress,
    required this.activeLyric,
    this.lyricLineProgress = 0.0,
    this.playMode = PlayMode.loopList,
    this.quality = AudioQuality.hiRes,
    this.desktopLyrics = false,
    this.ambientEnabled = true,
    this.isDark = true,
    this.smartLocalFilter = true,
  });

  final List<Track> tracks;
  final List<Track> hotTracks;
  final List<Track> searchResults;
  final List<Playlist> playlists;
  final List<SourcePlugin> sources;
  final String queueName;
  final List<String> queue;
  final int queuePos;
  final List<QueueSnapshot> recentQueues;
  final List<PlayHistoryEntry> playHistory;
  final bool isPlaying;
  final double progress;
  final int activeLyric;
  final double lyricLineProgress;
  final PlayMode playMode;
  final AudioQuality quality;
  final bool desktopLyrics;
  final bool ambientEnabled;
  final bool isDark;
  final bool smartLocalFilter;

  /// Returns the currently selected track ID, or `null` if the queue is empty.
  String? get currentTrackId {
    if (queue.isEmpty || queuePos < 0 || queuePos >= queue.length) {
      return null;
    }
    return queue[queuePos];
  }

  /// Returns the currently selected [Track], or `null` if unavailable.
  Track? get currentTrack {
    final id = currentTrackId;
    if (id == null) return null;
    for (final track in tracks) {
      if (track.id == id) return track;
    }
    return null;
  }

  /// Returns a copy of this state with the specified fields updated.
  PlayerState copyWith({
    List<Track>? tracks,
    List<Track>? hotTracks,
    List<Track>? searchResults,
    List<Playlist>? playlists,
    List<SourcePlugin>? sources,
    String? queueName,
    List<String>? queue,
    int? queuePos,
    List<QueueSnapshot>? recentQueues,
    List<PlayHistoryEntry>? playHistory,
    bool? isPlaying,
    double? progress,
    int? activeLyric,
    double? lyricLineProgress,
    PlayMode? playMode,
    AudioQuality? quality,
    bool? desktopLyrics,
    bool? ambientEnabled,
    bool? isDark,
    bool? smartLocalFilter,
  }) {
    return PlayerState(
      tracks: tracks ?? this.tracks,
      hotTracks: hotTracks ?? this.hotTracks,
      searchResults: searchResults ?? this.searchResults,
      playlists: playlists ?? this.playlists,
      sources: sources ?? this.sources,
      queueName: queueName ?? this.queueName,
      queue: queue ?? this.queue,
      queuePos: queuePos ?? this.queuePos,
      recentQueues: recentQueues ?? this.recentQueues,
      playHistory: playHistory ?? this.playHistory,
      isPlaying: isPlaying ?? this.isPlaying,
      progress: progress ?? this.progress,
      activeLyric: activeLyric ?? this.activeLyric,
      lyricLineProgress: lyricLineProgress ?? this.lyricLineProgress,
      playMode: playMode ?? this.playMode,
      quality: quality ?? this.quality,
      desktopLyrics: desktopLyrics ?? this.desktopLyrics,
      ambientEnabled: ambientEnabled ?? this.ambientEnabled,
      isDark: isDark ?? this.isDark,
      smartLocalFilter: smartLocalFilter ?? this.smartLocalFilter,
    );
  }
}

/// Manages AuraMusic playback, queue history, playlists, and native bridges.
class PlayerNotifier extends StateNotifier<PlayerState> {
  /// Creates a [PlayerNotifier] with default catalog, playlists, and sources.
  PlayerNotifier({
    OhosAudioBridge? audioBridge,
    AudioEngineAdapter? audioEngine,
    AppStorage? storage,
    bool emptyStart = false,
  }) : _audioBridge = audioBridge ?? const OhosAudioBridge(),
       _audioEngine = audioEngine ?? NoopAudioEngine(),
       _storage = storage ?? AppStorage.memory(),
       super(emptyStart ? _createEmptyState() : _createInitialState());

  static const int _maxRecentQueues = 3;
  static const int _maxPlayHistory = 50;

  final OhosAudioBridge _audioBridge;
  final AudioEngineAdapter _audioEngine;
  final AppStorage _storage;
  SidecarSourceClient? _sidecar;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<void>? _completedSub;
  Duration? _activeDuration;
  Future<bool>? _sidecarConnecting;
  bool _hasStartedCurrentSession = false;
  bool _initialized = false;

  /// Loads persisted state from [AppStorage] and subscribes to [AudioEngineAdapter] streams.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final savedTracks = _storage.loadTracks();
    final savedHotTracks = _storage.loadHotTracks();
    final savedPlaylists = _storage.loadPlaylists();
    final savedActiveQueue = _storage.loadActiveQueue();
    final savedHistory = _storage.loadPlayHistory();
    final savedQueues = _storage.loadRecentQueues();
    final savedSources = _storage.loadSources();
    final savedTokens = _storage.loadOAuthTokens() ?? const <String, String>{};
    final savedSettings = _storage.loadSettings();

    List<Track>? mergedTracks;
    if (savedTracks != null || savedHotTracks != null) {
      final byId = <String, Track>{for (final t in state.tracks) t.id: t};
      if (savedHotTracks != null) {
        for (final t in savedHotTracks) {
          byId[t.id] = t;
        }
      }
      if (savedTracks != null) {
        for (final t in savedTracks) {
          byId[t.id] = t;
        }
      }
      mergedTracks = List<Track>.unmodifiable(byId.values);
    }

    final effectiveTracks = mergedTracks ?? state.tracks;
    final effectiveTrackIds = effectiveTracks.map((t) => t.id).toSet();

    List<String>? restoredQueue;
    String? restoredQueueName;
    int? restoredQueuePos;
    if (savedActiveQueue != null && savedActiveQueue.queue.isNotEmpty) {
      final validQueue = savedActiveQueue.queue
          .where(effectiveTrackIds.contains)
          .toList(growable: false);
      if (validQueue.isNotEmpty) {
        restoredQueue = List<String>.unmodifiable(validQueue);
        restoredQueueName = savedActiveQueue.queueName;
        restoredQueuePos = savedActiveQueue.queuePos.clamp(
          0,
          validQueue.length - 1,
        );
      }
    }

    List<SourcePlugin>? sanitizedSources;
    if (savedSources != null) {
      sanitizedSources = savedSources
          .map((s) {
            final hasToken = s.id == 'huawei'
                ? (savedTokens['sidecar_huawei_session']?.trim().isNotEmpty ??
                      false)
                : (savedTokens[s.id]?.trim().isNotEmpty ?? false);
            return s.connected && !hasToken ? s.copyWith(connected: false) : s;
          })
          .toList(growable: false);
    }

    state = state.copyWith(
      tracks: mergedTracks,
      hotTracks: savedHotTracks != null
          ? List<Track>.unmodifiable(savedHotTracks)
          : null,
      playlists: savedPlaylists != null
          ? List<Playlist>.unmodifiable(savedPlaylists)
          : null,
      queueName: restoredQueueName,
      queue: restoredQueue,
      queuePos: restoredQueuePos,
      playHistory: savedHistory != null
          ? List<PlayHistoryEntry>.unmodifiable(
              savedHistory.map(
                (entry) => PlayHistoryEntry(
                  trackId: entry['trackId'] ?? '',
                  timestampLabel: entry['timestampLabel'] ?? '',
                ),
              ),
            )
          : null,
      recentQueues: savedQueues != null
          ? List<QueueSnapshot>.unmodifiable(
              savedQueues.map(
                (entry) => QueueSnapshot(
                  name: entry['name'] as String? ?? '',
                  trackIds: ((entry['trackIds'] as List<dynamic>?) ?? const [])
                      .map((id) => id.toString())
                      .toList(growable: false),
                  queuePos: entry['queuePos'] as int? ?? 0,
                ),
              ),
            )
          : null,
      sources: sanitizedSources != null
          ? List<SourcePlugin>.unmodifiable(sanitizedSources)
          : null,
      ambientEnabled: savedSettings?.ambientEnabled,
      isDark: savedSettings?.isDark,
      desktopLyrics: savedSettings?.desktopLyrics,
      smartLocalFilter: savedSettings?.smartLocalFilter,
      playMode: savedSettings?.playMode,
      quality: savedSettings?.quality,
    );

    _durationSub = _audioEngine.durationStream.listen((duration) {
      if (duration > Duration.zero) {
        _activeDuration = duration;
        final track = state.currentTrack;
        if (track != null &&
            (track.durationSeconds - duration.inSeconds).abs() > 2) {
          final updated = state.tracks
              .map(
                (t) => t.id == track.id
                    ? t.copyWith(durationSeconds: duration.inSeconds)
                    : t,
              )
              .toList(growable: false);
          state = state.copyWith(tracks: List<Track>.unmodifiable(updated));
          _persistTracks();
        }
      }
    });

    _positionSub = _audioEngine.positionStream.listen(_handlePositionUpdate);
    _completedSub = _audioEngine.onCompleted.listen((_) {
      nextTrack(auto: true);
    });

    _audioBridge.setActionHandler((action) async {
      switch (action) {
        case 'prev':
          prevTrack();
          break;
        case 'togglePlay':
          togglePlay();
          break;
        case 'next':
          nextTrack();
          break;
        case 'close':
          if (state.desktopLyrics) {
            toggleDesktopLyrics();
          }
          break;
      }
    });

    if (state.desktopLyrics) {
      final track = state.currentTrack;
      final line =
          (track != null &&
              track.lyrics.isNotEmpty &&
              state.activeLyric < track.lyrics.length)
          ? track.lyrics[state.activeLyric]
          : null;
      final nextLine =
          (track != null && state.activeLyric + 1 < track.lyrics.length)
          ? track.lyrics[state.activeLyric + 1]
          : null;
      _audioBridge.setDesktopLyricsEnabled(
        true,
        currentLyric: line,
        nextLyric: nextLine,
        progress: state.lyricLineProgress,
        isPlaying: state.isPlaying,
      );
    }

    const defaultSidecarPath =
        r'D:\code\Music\docs\huawei-1.0.0-windows-x64\bin\huawei-source.exe';
    if (Platform.isWindows &&
        _audioEngine is! NoopAudioEngine &&
        (state.sources.any((s) => s.id == 'huawei') ||
            File(defaultSidecarPath).existsSync())) {
      _sidecarConnecting = connectSidecar(defaultSidecarPath);
      unawaited(_sidecarConnecting!);
    }
  }

  void _handlePositionUpdate(Duration position) {
    if (!state.isPlaying) return;
    final track = state.currentTrack;
    final totalMs =
        (_activeDuration != null && _activeDuration!.inMilliseconds > 0)
        ? _activeDuration!.inMilliseconds
        : (track?.durationSeconds ?? 0) * 1000;
    if (totalMs <= 0) return;

    final nextProgress = (position.inMilliseconds / totalMs).clamp(0.0, 1.0);
    final currentSec = position.inMilliseconds / 1000.0;
    var lyricIndex = state.activeLyric;
    var lineProg = state.lyricLineProgress;

    if (track != null && track.lyricLines.isNotEmpty) {
      var found = 0;
      for (var i = 0; i < track.lyricLines.length; i++) {
        if (track.lyricLines[i].timeSeconds <= currentSec) {
          found = i;
        } else {
          break;
        }
      }
      lyricIndex = found;
      lineProg = track.lineProgressAt(lyricIndex, currentSec);
    } else if (track != null && track.lyrics.isNotEmpty) {
      final exact = nextProgress * track.lyrics.length;
      lyricIndex = exact.floor().clamp(0, track.lyrics.length - 1);
      lineProg = (exact - lyricIndex).clamp(0.0, 1.0);
    }

    state = state.copyWith(
      progress: nextProgress,
      activeLyric: lyricIndex,
      lyricLineProgress: lineProg,
    );

    if (state.desktopLyrics && track != null && track.lyrics.isNotEmpty) {
      _syncDesktopLyricSnapshot(track, lyricIndex, lineProg);
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completedSub?.cancel();
    unawaited(_sidecar?.dispose());
    super.dispose();
  }

  static PlayerState _createEmptyState() {
    return const PlayerState(
      tracks: [],
      hotTracks: [],
      searchResults: [],
      playlists: [
        Playlist(
          id: 'pl_local',
          name: '本地音乐',
          type: PlaylistType.local,
          trackIds: [],
        ),
      ],
      sources: [],
      queueName: '当前播放',
      queue: [],
      queuePos: 0,
      recentQueues: [],
      playHistory: [],
      isPlaying: false,
      progress: 0.0,
      activeLyric: 0,
    );
  }

  static PlayerState _createInitialState() {
    final initialIds = sampleTracks.map((t) => t.id).toList(growable: false);
    final localIds = sampleTracks
        .where((t) => t.sourceId == 'local')
        .map((t) => t.id)
        .toList(growable: false);
    final likedIds = sampleTracks
        .where((t) => t.liked)
        .map((t) => t.id)
        .toList(growable: false);

    return PlayerState(
      tracks: List<Track>.unmodifiable(sampleTracks),
      hotTracks: List<Track>.unmodifiable(sampleTracks),
      searchResults: const [],
      playlists: [
        Playlist(
          id: 'pl_local',
          name: '本地无损音乐',
          type: PlaylistType.local,
          trackIds: localIds,
        ),
        Playlist(
          id: 'pl_favorites',
          name: '红心收藏',
          type: PlaylistType.user,
          trackIds: likedIds,
        ),
        Playlist(
          id: 'pl_imported_night',
          name: '深夜沉浸漫游',
          type: PlaylistType.imported,
          trackIds: initialIds.take(6).toList(growable: false),
        ),
      ],
      sources: const [
        SourcePlugin(
          id: 'netease',
          name: '网易云音源插件',
          version: '2.4.0',
          connected: false,
          tierLabel: 'Hi-Res',
        ),
        SourcePlugin(
          id: 'qq',
          name: 'QQ 音乐音源插件',
          version: '1.9.2',
          connected: false,
          tierLabel: 'SQ 无损',
        ),
        SourcePlugin(
          id: 'apple',
          name: 'Spatial Audio 桥接',
          version: '1.2.0',
          connected: false,
          tierLabel: 'AudioVivid',
        ),
      ],
      queueName: '推荐漫游队列',
      queue: initialIds,
      queuePos: 0,
      recentQueues: const [],
      playHistory: const [],
      isPlaying: false,
      progress: 0.0,
      activeLyric: 0,
    );
  }

  /// Plays [trackId] within the current queue without replacing the playlist.
  ///
  /// If [trackId] is already in [PlayerState.queue], playback jumps to its
  /// position; otherwise it is appended to the current queue.
  void playTrack(String trackId) {
    final track = _findTrack(trackId);
    if (track == null) return;

    final updatedQueue = List<String>.from(state.queue);
    var targetIndex = updatedQueue.indexOf(trackId);
    if (targetIndex == -1) {
      updatedQueue.add(trackId);
      targetIndex = updatedQueue.length - 1;
    }

    state = state.copyWith(
      queue: List<String>.unmodifiable(updatedQueue),
      queuePos: targetIndex,
      isPlaying: true,
      progress: 0.0,
      activeLyric: 0,
      playHistory: _recordHistory(state.playHistory, trackId),
    );

    _syncNativeTrackStart(track);
    _persistActiveQueue();
    _persistHistory();
  }

  /// Toggles play/pause state for the current track.
  void togglePlay() {
    if (state.queue.isEmpty) return;
    final nextPlaying = !state.isPlaying;
    state = state.copyWith(isPlaying: nextPlaying);

    if (nextPlaying) {
      final track = state.currentTrack;
      if (!_hasStartedCurrentSession && track != null) {
        _syncNativeTrackStart(track);
        return;
      }
      unawaited(_audioEngine.resume());
      if (track != null) {
        _audioBridge.resume();
        _audioBridge.updatePlaybackState(
          isPlaying: true,
          positionSeconds: _currentPositionSeconds(track),
        );
        if (state.desktopLyrics) {
          _syncDesktopLyricSnapshot(
            track,
            state.activeLyric,
            state.lyricLineProgress,
          );
        }
      }
    } else {
      unawaited(_audioEngine.pause());
      _audioBridge.pause();
      final track = state.currentTrack;
      if (track != null) {
        _audioBridge.updatePlaybackState(
          isPlaying: false,
          positionSeconds: _currentPositionSeconds(track),
        );
        if (state.desktopLyrics) {
          _syncDesktopLyricSnapshot(
            track,
            state.activeLyric,
            state.lyricLineProgress,
          );
        }
      }
    }
  }

  /// Advances playback according to [PlayerState.playMode].
  ///
  /// When [auto] is `true` (track ended naturally):
  /// - [PlayMode.loopOne] replays the current track.
  /// - [PlayMode.playOnce] stops playback at the end of the track.
  /// - [PlayMode.loopList] advances and wraps around the queue.
  void nextTrack({bool auto = false}) {
    if (state.queue.isEmpty) return;

    if (auto && state.playMode == PlayMode.playOnce) {
      state = state.copyWith(isPlaying: false, progress: 0.0, activeLyric: 0);
      unawaited(_audioEngine.pause());
      _audioBridge.pause();
      return;
    }

    final nextPos = (auto && state.playMode == PlayMode.loopOne)
        ? state.queuePos
        : (state.queuePos + 1) % state.queue.length;

    final nextId = state.queue[nextPos];
    state = state.copyWith(
      queuePos: nextPos,
      isPlaying: true,
      progress: 0.0,
      activeLyric: 0,
      playHistory: _recordHistory(state.playHistory, nextId),
    );

    final track = _findTrack(nextId);
    if (track != null) {
      _syncNativeTrackStart(track);
    }
    _persistActiveQueue();
    _persistHistory();
  }

  /// Moves to the previous track in the queue, wrapping around if needed.
  void prevTrack() {
    if (state.queue.isEmpty) return;
    final prevPos =
        (state.queuePos - 1 + state.queue.length) % state.queue.length;
    final prevId = state.queue[prevPos];

    state = state.copyWith(
      queuePos: prevPos,
      isPlaying: true,
      progress: 0.0,
      activeLyric: 0,
      playHistory: _recordHistory(state.playHistory, prevId),
    );

    final track = _findTrack(prevId);
    if (track != null) {
      _syncNativeTrackStart(track);
    }
    _persistActiveQueue();
    _persistHistory();
  }

  /// Seeks playback progress to [value] (clamped to `0.0..1.0`).
  void seek(double value) {
    final clamped = value.clamp(0.0, 1.0);
    final track = state.currentTrack;
    var lyricIndex = state.activeLyric;
    var lineProg = 0.0;

    final totalMs =
        (_activeDuration != null && _activeDuration!.inMilliseconds > 0)
        ? _activeDuration!.inMilliseconds
        : (track?.durationSeconds ?? 0) * 1000;

    if (track != null && track.lyricLines.isNotEmpty && totalMs > 0) {
      final targetSec = (totalMs * clamped) / 1000.0;
      var found = 0;
      for (var i = 0; i < track.lyricLines.length; i++) {
        if (track.lyricLines[i].timeSeconds <= targetSec) {
          found = i;
        } else {
          break;
        }
      }
      lyricIndex = found;
      lineProg = track.lineProgressAt(lyricIndex, targetSec);
    } else if (track != null && track.lyrics.isNotEmpty) {
      final exact = clamped * track.lyrics.length;
      lyricIndex = exact.floor().clamp(0, track.lyrics.length - 1);
      lineProg = (exact - lyricIndex).clamp(0.0, 1.0);
    }

    state = state.copyWith(
      progress: clamped,
      activeLyric: lyricIndex,
      lyricLineProgress: lineProg,
    );

    if (track != null) {
      if (totalMs > 0) {
        unawaited(
          _audioEngine.seek(
            Duration(milliseconds: (totalMs * clamped).round()),
          ),
        );
      }
      final posSeconds = (track.durationSeconds * clamped).round();
      _audioBridge.seek(posSeconds);
      if (state.desktopLyrics && track.lyrics.isNotEmpty) {
        _syncDesktopLyricSnapshot(track, lyricIndex, lineProg);
      }
    }
  }

  /// Jumps directly to lyric line [index] and updates playback progress.
  void jumpLyric(int index) {
    final track = state.currentTrack;
    if (track == null || track.lyrics.isEmpty) return;

    final clampedIndex = index.clamp(0, track.lyrics.length - 1);
    final totalMs =
        (_activeDuration != null && _activeDuration!.inMilliseconds > 0)
        ? _activeDuration!.inMilliseconds
        : track.durationSeconds * 1000;

    double nextProgress;
    int seekMs;
    if (track.lyricLines.isNotEmpty &&
        clampedIndex < track.lyricLines.length &&
        totalMs > 0) {
      final targetSec = track.lyricLines[clampedIndex].timeSeconds;
      seekMs = (targetSec * 1000).round();
      nextProgress = (seekMs / totalMs).clamp(0.0, 1.0);
    } else {
      nextProgress = clampedIndex / track.lyrics.length;
      seekMs = (totalMs * nextProgress).round();
    }

    state = state.copyWith(
      activeLyric: clampedIndex,
      progress: nextProgress,
      lyricLineProgress: 0.0,
    );

    if (totalMs > 0) {
      unawaited(_audioEngine.seek(Duration(milliseconds: seekMs)));
    }
    _audioBridge.seek((seekMs / 1000).round());
    if (state.desktopLyrics) {
      _syncDesktopLyricSnapshot(track, clampedIndex, 0.0);
    }
  }

  /// Toggles the liked status of [trackId] across library, hot tracks, and search results.
  void toggleTrackLike(String trackId) {
    Track updateLike(Track t) =>
        t.id == trackId ? t.copyWith(liked: !t.liked) : t;

    final updatedTracks = state.tracks.map(updateLike).toList(growable: false);
    final updatedHot = state.hotTracks.map(updateLike).toList(growable: false);
    final updatedSearch = state.searchResults
        .map(updateLike)
        .toList(growable: false);

    state = state.copyWith(
      tracks: List<Track>.unmodifiable(updatedTracks),
      hotTracks: List<Track>.unmodifiable(updatedHot),
      searchResults: List<Track>.unmodifiable(updatedSearch),
    );
    _persistTracks();
    _persistHotTracks();
  }

  /// Toggles the liked status of the currently playing track.
  void toggleLike() {
    final currentId = state.currentTrackId;
    if (currentId == null) return;
    toggleTrackLike(currentId);
  }

  /// Inserts [track] immediately after the current track in the active queue.
  ///
  /// If the queue is currently empty, starts playing [track] right away.
  void playNextInQueue(Track track) {
    final tracksById = <String, Track>{for (final t in state.tracks) t.id: t};
    var tracksChanged = false;
    if (!tracksById.containsKey(track.id)) {
      tracksById[track.id] = track;
      tracksChanged = true;
    }
    if (tracksChanged) {
      state = state.copyWith(
        tracks: List<Track>.unmodifiable(tracksById.values),
      );
      _persistTracks();
    }

    if (state.queue.isEmpty) {
      playTrack(track.id);
      return;
    }

    final currentId = state.currentTrackId;
    if (currentId == track.id) return;

    final updated = List<String>.from(state.queue)..remove(track.id);
    final nextCurrentPos = currentId == null
        ? state.queuePos.clamp(0, updated.length - 1)
        : updated.indexOf(currentId).clamp(0, updated.length - 1);
    final insertAt = (nextCurrentPos + 1).clamp(0, updated.length);
    updated.insert(insertAt, track.id);

    state = state.copyWith(
      queue: List<String>.unmodifiable(updated),
      queuePos: nextCurrentPos,
    );
    _persistActiveQueue();
  }

  /// Adds [track] to the playlist identified by [playlistId] and persists.
  bool addTrackToPlaylist(String playlistId, Track track) {
    final plIndex = state.playlists.indexWhere((pl) => pl.id == playlistId);
    if (plIndex < 0) return false;

    final hasTrack = state.tracks.any((t) => t.id == track.id);
    final updatedTracks = hasTrack
        ? state.tracks
        : List<Track>.unmodifiable([...state.tracks, track]);

    final targetPlaylist = state.playlists[plIndex];
    final alreadyInPlaylist = targetPlaylist.trackIds.contains(track.id);
    final updatedPlaylists = List<Playlist>.from(state.playlists);
    if (!alreadyInPlaylist) {
      updatedPlaylists[plIndex] = targetPlaylist.copyWith(
        trackIds: List<String>.unmodifiable([
          ...targetPlaylist.trackIds,
          track.id,
        ]),
      );
    }

    state = state.copyWith(
      tracks: updatedTracks,
      playlists: List<Playlist>.unmodifiable(updatedPlaylists),
    );
    if (!hasTrack) {
      _persistTracks();
    }
    if (!alreadyInPlaylist) {
      _persistPlaylists();
    }
    return !alreadyInPlaylist;
  }

  /// Cycles [PlayerState.playMode] in order: `loopList -> loopOne -> playOnce`.
  void cyclePlayMode() {
    final modes = PlayMode.values;
    final nextMode = modes[(state.playMode.index + 1) % modes.length];
    state = state.copyWith(playMode: nextMode);
    _persistSettings();
  }

  /// Sets the preferred [AudioQuality] tier.
  void setQuality(AudioQuality q) {
    state = state.copyWith(quality: q);
    _audioBridge.setQuality(q);
    _persistSettings();
  }

  /// Reorders an item inside the current queue without replacing the playlist.
  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= state.queue.length ||
        newIndex < 0 ||
        newIndex > state.queue.length) {
      return;
    }

    final currentId = state.currentTrackId;
    final updated = List<String>.from(state.queue);
    final moved = updated.removeAt(oldIndex);
    final targetIndex = newIndex.clamp(0, updated.length);
    updated.insert(targetIndex, moved);

    final updatedPos = currentId == null
        ? 0
        : updated.indexOf(currentId).clamp(0, updated.length - 1);

    state = state.copyWith(
      queue: List<String>.unmodifiable(updated),
      queuePos: updatedPos,
    );
    _persistActiveQueue();
  }

  /// Removes the track at [index] from the current queue without replacing it.
  void removeFromQueue(int index) {
    if (index < 0 || index >= state.queue.length) return;

    final updated = List<String>.from(state.queue)..removeAt(index);
    if (updated.isEmpty) {
      state = state.copyWith(
        queue: const [],
        queuePos: 0,
        isPlaying: false,
        progress: 0.0,
        activeLyric: 0,
      );
      unawaited(_audioEngine.pause());
      _audioBridge.pause();
      _persistActiveQueue();
      return;
    }

    var nextPos = state.queuePos;
    if (index < state.queuePos) {
      nextPos -= 1;
    } else if (state.queuePos >= updated.length) {
      nextPos = updated.length - 1;
    }

    state = state.copyWith(
      queue: List<String>.unmodifiable(updated),
      queuePos: nextPos,
    );
    _persistActiveQueue();
  }

  /// Replaces the active queue with [trackIds] and pushes the previous queue
  /// into [PlayerState.recentQueues] (capped at 3).
  void replaceQueue(String name, List<String> trackIds, {int startPos = 0}) {
    final previousSnapshot = QueueSnapshot(
      name: state.queueName,
      trackIds: List<String>.unmodifiable(state.queue),
      queuePos: state.queuePos,
    );

    final updatedRecent = [
      previousSnapshot,
      ...state.recentQueues,
    ].take(_maxRecentQueues).toList(growable: false);

    final safePos = trackIds.isEmpty
        ? 0
        : startPos.clamp(0, trackIds.length - 1);
    final hasTracks = trackIds.isNotEmpty;
    final startTrackId = hasTracks ? trackIds[safePos] : null;

    state = state.copyWith(
      queueName: name,
      queue: List<String>.unmodifiable(trackIds),
      queuePos: safePos,
      recentQueues: List<QueueSnapshot>.unmodifiable(updatedRecent),
      isPlaying: hasTracks,
      progress: 0.0,
      activeLyric: 0,
      playHistory: startTrackId == null
          ? state.playHistory
          : _recordHistory(state.playHistory, startTrackId),
    );

    if (startTrackId != null) {
      final track = _findTrack(startTrackId);
      if (track != null) {
        _syncNativeTrackStart(track);
      }
      _persistHistory();
    }
    _persistActiveQueue();
    _persistRecentQueues();
  }

  /// Restores the queue snapshot at [recentIndex] from [PlayerState.recentQueues].
  void switchRecentQueue(int recentIndex) {
    if (recentIndex < 0 || recentIndex >= state.recentQueues.length) return;

    final target = state.recentQueues[recentIndex];
    final currentSnapshot = QueueSnapshot(
      name: state.queueName,
      trackIds: List<String>.unmodifiable(state.queue),
      queuePos: state.queuePos,
    );

    final remainingRecent = List<QueueSnapshot>.from(state.recentQueues)
      ..removeAt(recentIndex);
    final updatedRecent = [
      currentSnapshot,
      ...remainingRecent,
    ].take(_maxRecentQueues).toList(growable: false);

    final hasTracks = target.trackIds.isNotEmpty;
    final safePos = hasTracks
        ? target.queuePos.clamp(0, target.trackIds.length - 1)
        : 0;
    final activeId = hasTracks ? target.trackIds[safePos] : null;

    state = state.copyWith(
      queueName: target.name,
      queue: List<String>.unmodifiable(target.trackIds),
      queuePos: safePos,
      recentQueues: List<QueueSnapshot>.unmodifiable(updatedRecent),
      isPlaying: hasTracks,
      progress: 0.0,
      activeLyric: 0,
      playHistory: activeId == null
          ? state.playHistory
          : _recordHistory(state.playHistory, activeId),
    );

    if (activeId != null) {
      final track = _findTrack(activeId);
      if (track != null) {
        _syncNativeTrackStart(track);
      }
      _persistHistory();
    }
    _persistActiveQueue();
    _persistRecentQueues();
  }

  /// Creates a new user playlist named [name].
  void createPlaylist(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final created = Playlist(
      id: 'pl_user_${state.playlists.length + 1}',
      name: trimmed,
      type: PlaylistType.user,
      trackIds: const [],
    );

    state = state.copyWith(
      playlists: List<Playlist>.unmodifiable([...state.playlists, created]),
    );
    _persistPlaylists();
  }

  /// Imports an external playlist with [name] and [trackIds].
  void importPlaylist(String name, List<String> trackIds) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final imported = Playlist(
      id: 'pl_imported_${state.playlists.length + 1}',
      name: trimmed,
      type: PlaylistType.imported,
      trackIds: List<String>.unmodifiable(trackIds),
    );

    state = state.copyWith(
      playlists: List<Playlist>.unmodifiable([...state.playlists, imported]),
    );
    _persistPlaylists();
  }

  /// Scans simulated local audio candidates using [LocalMusicScanner] and
  /// updates the local playlist.
  void scanLocalMusic() {
    const mockDeviceCandidates = [
      LocalAudioCandidate(
        path: '/storage/emulated/0/Music/lossless/morning_dew.flac',
        title: '晨露微光 (Local)',
        artist: 'Local Studio',
        durationSeconds: 218,
        sizeBytes: 28 * 1024 * 1024,
      ),
      LocalAudioCandidate(
        path: '/storage/emulated/0/Recordings/call_001.m4a',
        title: '通话录音_001',
        artist: 'Unknown',
        durationSeconds: 185,
        sizeBytes: 2 * 1024 * 1024,
      ),
      LocalAudioCandidate(
        path: '/storage/emulated/0/Ringtones/chime.mp3',
        title: '默认铃声',
        artist: 'System',
        durationSeconds: 24,
        sizeBytes: 320 * 1024,
      ),
    ];

    final accepted = LocalMusicScanner.filterMusic(
      mockDeviceCandidates,
      smartFilter: state.smartLocalFilter,
    );

    final existingIds = state.tracks.map((t) => t.id).toSet();
    final discoveredTracks = <Track>[];
    final discoveredIds = <String>[];

    for (var i = 0; i < accepted.length; i++) {
      final candidate = accepted[i];
      final id = 'trk_local_scan_$i';
      discoveredIds.add(id);
      if (!existingIds.contains(id)) {
        discoveredTracks.add(
          Track(
            id: id,
            title: candidate.title,
            artist: candidate.artist,
            album: '本地扫描',
            quality: 'SQ',
            sourceId: 'local',
            durationSeconds: candidate.durationSeconds,
            colors: const [
              Color(0xFF0F172A),
              Color(0xFF0EA5E9),
              Color(0xFF38BDF8),
            ],
            lyrics: const ['本地无损音频'],
          ),
        );
      }
    }

    final baseLocalIds = state.tracks
        .where((t) => t.sourceId == 'local')
        .map((t) => t.id)
        .toList();
    final combinedLocalIds = {
      ...baseLocalIds,
      ...discoveredIds,
    }.toList(growable: false);

    final updatedPlaylists = state.playlists
        .map(
          (pl) => pl.id == 'pl_local'
              ? pl.copyWith(trackIds: combinedLocalIds)
              : pl,
        )
        .toList(growable: false);

    state = state.copyWith(
      tracks: List<Track>.unmodifiable([...state.tracks, ...discoveredTracks]),
      playlists: List<Playlist>.unmodifiable(updatedPlaylists),
    );
    _persistTracks();
    _persistPlaylists();
    _persistActiveQueue();
  }

  /// Scans real device [directories] (or [LocalMusicScanner.defaultMusicDirectories])
  /// for local audio files, adds newly discovered tracks to the library and
  /// `pl_local` playlist, persists, and returns the scanned track count.
  Future<int> scanLocalMusicReal({List<String>? directories}) async {
    final dirs = directories ?? LocalMusicScanner.defaultMusicDirectories();
    final scanned = await LocalMusicScanner.scanDirectories(
      dirs,
      smartFilter: state.smartLocalFilter,
    );

    final existingIds = state.tracks.map((t) => t.id).toSet();
    final newTracks = scanned
        .where((t) => !existingIds.contains(t.id))
        .toList(growable: false);

    final existingLocalIds = state.tracks
        .where((t) => t.sourceId == 'local')
        .map((t) => t.id)
        .toList();
    final scannedIds = scanned.map((t) => t.id).toList();
    final combinedLocalIds = {
      ...existingLocalIds,
      ...scannedIds,
    }.toList(growable: false);

    final updatedPlaylists = state.playlists
        .map(
          (pl) => pl.id == 'pl_local'
              ? pl.copyWith(trackIds: combinedLocalIds)
              : pl,
        )
        .toList(growable: false);

    state = state.copyWith(
      tracks: List<Track>.unmodifiable([...state.tracks, ...newTracks]),
      playlists: List<Playlist>.unmodifiable(updatedPlaylists),
    );
    await _storage.saveTracks(state.tracks);
    await _storage.savePlaylists(state.playlists);
    _persistActiveQueue();
    return scanned.length;
  }

  /// Parses an M3U or JSON playlist string [raw], adds any new tracks and the
  /// imported playlist to state, and persists to storage.
  Future<bool> importPlaylistRaw(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return false;

    ({String name, List<Track> tracks}) parsed;
    try {
      parsed = trimmed.startsWith('{')
          ? PlaylistCodec.parseJson(trimmed)
          : PlaylistCodec.parseM3u(trimmed);
    } catch (_) {
      return false;
    }

    if (parsed.tracks.isEmpty) return false;

    final existingIds = state.tracks.map((t) => t.id).toSet();
    final newTracks = parsed.tracks
        .where((t) => !existingIds.contains(t.id))
        .toList(growable: false);

    final imported = Playlist(
      id: 'pl_imported_${state.playlists.length + 1}',
      name: parsed.name,
      type: PlaylistType.imported,
      trackIds: List<String>.unmodifiable(
        parsed.tracks.map((t) => t.id).toList(growable: false),
      ),
    );

    state = state.copyWith(
      tracks: List<Track>.unmodifiable([...state.tracks, ...newTracks]),
      playlists: List<Playlist>.unmodifiable([...state.playlists, imported]),
    );
    await _storage.saveTracks(state.tracks);
    await _storage.savePlaylists(state.playlists);
    _persistActiveQueue();
    return true;
  }

  /// Parses a community JS plugin script, JSON manifest, or remote URL [input],
  /// adds or updates the corresponding [SourcePlugin], and persists to storage.
  Future<bool> importPluginScript(
    String input, {
    http.Client? httpClient,
  }) async {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return false;

    String payload = trimmed;
    String? importUrl;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri == null || uri.host.isEmpty) return false;
      importUrl = trimmed;
      final client = httpClient ?? http.Client();
      try {
        final response = await client
            .get(uri)
            .timeout(const Duration(seconds: 15));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return false;
        }
        payload = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
        if (payload.isEmpty) return false;
      } catch (_) {
        return false;
      } finally {
        if (httpClient == null) {
          client.close();
        }
      }
    }

    CommunityPluginManifest manifest;
    try {
      manifest = CommunityPluginManifest.parse(payload);
    } catch (_) {
      return false;
    }

    var pluginName = manifest.name;
    var pluginId = manifest.id;
    if (importUrl != null && pluginName == 'Unnamed Plugin') {
      final uri = Uri.parse(importUrl);
      final rawSeg = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : uri.host;
      final cleaned = rawSeg.replaceAll(
        RegExp(r'\.(js|json)$', caseSensitive: false),
        '',
      );
      if (cleaned.isNotEmpty) {
        pluginName = cleaned;
        if (pluginId == 'unnamed_plugin' || pluginId == 'community_plugin') {
          pluginId = cleaned
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
              .replaceAll(RegExp(r'^_+|_+$'), '');
          if (pluginId.isEmpty) pluginId = 'remote_plugin';
        }
      }
    }

    final existingIndex = state.sources.indexWhere((s) => s.id == pluginId);
    final plugin = SourcePlugin(
      id: pluginId,
      name: pluginName,
      version: manifest.version,
      connected: existingIndex >= 0
          ? state.sources[existingIndex].connected
          : false,
      tierLabel: importUrl != null
          ? 'JS 插件 · URL'
          : (manifest.apiBase.isNotEmpty ? 'JS 插件 · HTTP' : 'JS 插件'),
      enabled: existingIndex >= 0 ? state.sources[existingIndex].enabled : true,
      importUrl: importUrl,
    );

    final updatedSources = List<SourcePlugin>.from(state.sources);
    if (existingIndex >= 0) {
      updatedSources[existingIndex] = plugin;
    } else {
      updatedSources.add(plugin);
    }

    state = state.copyWith(
      sources: List<SourcePlugin>.unmodifiable(updatedSources),
    );
    await _storage.saveSources(state.sources);
    return true;
  }

  /// Marks [sourceId] as OAuth-authorized when a non-empty [token] is provided.
  Future<void> authorizeOAuth(String sourceId, {String? token}) async {
    final cleanToken = token?.trim() ?? '';
    if (cleanToken.isEmpty) return;

    final updated = state.sources
        .map(
          (source) =>
              source.id == sourceId ? source.copyWith(connected: true) : source,
        )
        .toList(growable: false);
    state = state.copyWith(sources: List<SourcePlugin>.unmodifiable(updated));
    await _storage.saveSources(state.sources);

    final existingTokens = Map<String, String>.from(
      _storage.loadOAuthTokens() ?? const {},
    );
    existingTokens[sourceId] = cleanToken;
    await _storage.saveOAuthTokens(existingTokens);
  }

  /// Toggles whether the source plugin with [sourceId] is enabled for playback/search.
  void toggleSourceEnabled(String sourceId) {
    final updated = state.sources
        .map(
          (source) => source.id == sourceId
              ? source.copyWith(enabled: !source.enabled)
              : source,
        )
        .toList(growable: false);
    state = state.copyWith(sources: List<SourcePlugin>.unmodifiable(updated));
    _persistSources();
  }

  /// Removes the source plugin with [sourceId] and clears any associated tokens.
  Future<void> removeSource(String sourceId) async {
    final updated = state.sources
        .where((source) => source.id != sourceId)
        .toList(growable: false);
    state = state.copyWith(sources: List<SourcePlugin>.unmodifiable(updated));
    await _storage.saveSources(state.sources);

    final tokens = Map<String, String>.from(
      _storage.loadOAuthTokens() ?? const {},
    );
    if (tokens.remove(sourceId) != null) {
      await _storage.saveOAuthTokens(tokens);
    }

    if (sourceId == 'huawei') {
      await _sidecar?.dispose();
      _sidecar = null;
    }
  }

  /// Toggles OAuth connection status for the source plugin with [sourceId].
  void toggleOAuth(String sourceId) {
    final updated = state.sources
        .map(
          (source) => source.id == sourceId
              ? source.copyWith(connected: !source.connected)
              : source,
        )
        .toList(growable: false);
    state = state.copyWith(sources: List<SourcePlugin>.unmodifiable(updated));
    _persistSources();
  }

  /// Toggles ambient background color glow.
  void toggleAmbient() {
    state = state.copyWith(ambientEnabled: !state.ambientEnabled);
    _persistSettings();
  }

  /// Toggles HarmonyOS/Windows floating desktop lyrics window.
  void toggleDesktopLyrics() {
    final nextValue = !state.desktopLyrics;
    state = state.copyWith(desktopLyrics: nextValue);

    final track = state.currentTrack;
    final line =
        (track != null &&
            track.lyrics.isNotEmpty &&
            state.activeLyric < track.lyrics.length)
        ? track.lyrics[state.activeLyric]
        : null;
    final nextLine =
        (track != null && state.activeLyric + 1 < track.lyrics.length)
        ? track.lyrics[state.activeLyric + 1]
        : null;
    _audioBridge.setDesktopLyricsEnabled(
      nextValue,
      currentLyric: line,
      nextLyric: nextLine,
      progress: state.lyricLineProgress,
      isPlaying: state.isPlaying,
    );
    _persistSettings();
  }

  /// Toggles dark/light theme mode.
  void toggleTheme() {
    state = state.copyWith(isDark: !state.isDark);
    _persistSettings();
  }

  /// Toggles smart local audio filtering.
  void toggleSmartLocalFilter() {
    state = state.copyWith(smartLocalFilter: !state.smartLocalFilter);
    _persistSettings();
  }

  Track? _findTrack(String trackId) {
    for (final track in state.tracks) {
      if (track.id == trackId) return track;
    }
    return null;
  }

  int _currentPositionSeconds(Track track) {
    return (track.durationSeconds * state.progress).round();
  }

  void _syncNativeTrackStart(Track track) {
    _hasStartedCurrentSession = true;
    if ((track.sourceId == 'huawei' || track.id.startsWith('hw_')) &&
        (track.streamUrl == null || track.streamUrl!.isEmpty)) {
      unawaited(playSidecarTrack(track));
      return;
    }
    _activeDuration = null;
    if (track.localPath != null && track.localPath!.isNotEmpty) {
      unawaited(_audioEngine.playFile(track.localPath!));
    } else if (track.streamUrl != null && track.streamUrl!.isNotEmpty) {
      unawaited(_audioEngine.playUrl(track.streamUrl!));
    }
    _audioBridge.playTrack(track, quality: state.quality);
    _audioBridge.updateMetadata(track);
    _audioBridge.updatePlaybackState(isPlaying: true, positionSeconds: 0);
    if (state.desktopLyrics && track.lyrics.isNotEmpty) {
      _syncDesktopLyricSnapshot(track, 0, 0.0);
    }
  }

  void _syncDesktopLyricSnapshot(Track track, int lyricIndex, double lineProg) {
    if (track.lyrics.isEmpty) return;
    final safeIdx = lyricIndex.clamp(0, track.lyrics.length - 1);
    final nextLine = safeIdx + 1 < track.lyrics.length
        ? track.lyrics[safeIdx + 1]
        : '';
    _audioBridge.updateDesktopLyricLine(
      track.lyrics[safeIdx],
      nextLine: nextLine,
      progress: lineProg,
      isPlaying: state.isPlaying,
    );
  }

  void _persistTracks() {
    unawaited(_storage.saveTracks(state.tracks));
  }

  void _persistHotTracks() {
    unawaited(_storage.saveHotTracks(state.hotTracks));
  }

  void _persistPlaylists() {
    unawaited(_storage.savePlaylists(state.playlists));
  }

  void _persistActiveQueue() {
    unawaited(
      _storage.saveActiveQueue(
        queueName: state.queueName,
        queue: state.queue,
        queuePos: state.queuePos,
      ),
    );
  }

  void _persistHistory() {
    final encoded = state.playHistory
        .map(
          (entry) => {
            'trackId': entry.trackId,
            'timestampLabel': entry.timestampLabel,
          },
        )
        .toList(growable: false);
    unawaited(_storage.savePlayHistory(encoded));
  }

  void _persistRecentQueues() {
    final encoded = state.recentQueues
        .map(
          (q) => {
            'name': q.name,
            'trackIds': q.trackIds,
            'queuePos': q.queuePos,
          },
        )
        .toList(growable: false);
    unawaited(_storage.saveRecentQueues(encoded));
  }

  void _persistSources() {
    unawaited(_storage.saveSources(state.sources));
  }

  void _persistSettings() {
    unawaited(
      _storage.saveSettings(
        AppSettings(
          ambientEnabled: state.ambientEnabled,
          isDark: state.isDark,
          desktopLyrics: state.desktopLyrics,
          smartLocalFilter: state.smartLocalFilter,
          playMode: state.playMode,
          quality: state.quality,
        ),
      ),
    );
  }

  List<PlayHistoryEntry> _recordHistory(
    List<PlayHistoryEntry> current,
    String trackId,
  ) {
    final now = DateTime.now();
    final label =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final entry = PlayHistoryEntry(trackId: trackId, timestampLabel: label);
    return List<PlayHistoryEntry>.unmodifiable(
      [entry, ...current].take(_maxPlayHistory),
    );
  }

  /// Connects a Windows/Desktop Sidecar binary (e.g. `huawei-source.exe`)
  /// using `Content-Length` JSON-RPC 2.0.
  Future<bool> connectSidecar(
    String executablePath, {
    WebViewOpenCallback? onWebViewOpen,
  }) async {
    await _sidecar?.dispose();
    final client = SidecarSourceClient(
      sourceId: 'huawei',
      storage: _storage,
      executablePath: executablePath,
      onWebViewOpen: onWebViewOpen,
    );
    final started = await client.start();
    if (!started) return false;
    if (!mounted) {
      await client.dispose();
      return false;
    }
    _sidecar = client;
    final verified = await client.verifySession();
    if (!mounted) return false;
    final existingHuawei = state.sources
        .where((s) => s.id == 'huawei')
        .firstOrNull;
    final plugin = SourcePlugin(
      id: 'huawei',
      name: '华为音乐 (Sidecar)',
      version: '1.0.0',
      connected: verified,
      tierLabel: verified ? 'Sidecar 已登录' : '待 OAuth 登录',
      enabled: existingHuawei?.enabled ?? true,
    );
    final updated = [...state.sources.where((s) => s.id != 'huawei'), plugin];
    state = state.copyWith(sources: List<SourcePlugin>.unmodifiable(updated));
    _persistSources();
    if (state.hotTracks.isEmpty) {
      unawaited(refreshHotTracks());
    }
    return true;
  }

  /// Refreshes home chart [PlayerState.hotTracks] from Sidecar without altering
  /// [PlayerState.searchResults].
  Future<void> refreshHotTracks() async {
    if (_sidecar == null && _sidecarConnecting != null) {
      await _sidecarConnecting;
    }
    final client = _sidecar;
    if (client == null || !mounted) return;
    final hwSource = state.sources.where((s) => s.id == 'huawei').firstOrNull;
    if (hwSource != null && !hwSource.enabled) return;

    try {
      final raw = await client.search('热歌', pageSize: 30);
      if (raw.isEmpty || !mounted) return;
      final filtered = raw
          .where((t) => t.title.trim() != '热歌')
          .toList(growable: false);
      final curated = filtered.isNotEmpty ? filtered : raw;
      final existingById = <String, Track>{
        for (final t in state.tracks) t.id: t,
      };
      for (final t in curated) {
        existingById.putIfAbsent(t.id, () => t);
      }
      state = state.copyWith(
        hotTracks: List<Track>.unmodifiable(curated),
        tracks: List<Track>.unmodifiable(existingById.values),
      );
      _persistHotTracks();
      _persistTracks();
    } catch (_) {
      // Leave existing hotTracks untouched on transient network failure.
    }
  }

  /// Triggers the Sidecar native WebView OAuth login flow.
  Future<bool> loginSidecar({WebViewOpenCallback? onWebViewOpen}) async {
    final client = _sidecar;
    if (client == null) return false;
    if (onWebViewOpen != null) {
      client.onWebViewOpen = onWebViewOpen;
    }
    final ok = await client.login();
    if (!ok || !mounted) return false;
    final updated = state.sources
        .map(
          (s) => s.id == 'huawei'
              ? s.copyWith(connected: true, tierLabel: 'Sidecar 已登录')
              : s,
        )
        .toList(growable: false);
    state = state.copyWith(sources: List<SourcePlugin>.unmodifiable(updated));
    _persistSources();
    if (state.hotTracks.isEmpty) {
      unawaited(refreshHotTracks());
    }
    return true;
  }

  /// Searches the connected Sidecar source and stores results in
  /// [PlayerState.searchResults] without overwriting [PlayerState.hotTracks].
  Future<List<Track>> searchSidecar(String query) async {
    final hwSource = state.sources.where((s) => s.id == 'huawei').firstOrNull;
    if (hwSource != null && !hwSource.enabled) return const [];
    final client = _sidecar;
    if (client == null || query.trim().isEmpty) return const [];
    final results = await client.search(query.trim());
    if (!mounted) return results;
    final existing = state.tracks.map((t) => t.id).toSet();
    final added = results.where((t) => !existing.contains(t.id)).toList();
    state = state.copyWith(
      searchResults: List<Track>.unmodifiable(results),
      tracks: added.isNotEmpty
          ? List<Track>.unmodifiable([...state.tracks, ...added])
          : null,
    );
    if (added.isNotEmpty) {
      _persistTracks();
    }
    return results;
  }

  /// Resolves stream URL & lyrics for a Sidecar track and starts playback.
  Future<void> playSidecarTrack(Track track) async {
    if (_sidecar == null && _sidecarConnecting != null) {
      await _sidecarConnecting;
    }
    final client = _sidecar;
    if (client == null) return;
    final url = await client.resolveStreamUrl(track);
    final timedLyrics = await client.fetchTimedLyrics(track.id);
    if (!mounted) return;
    final resolved = track.copyWith(
      streamUrl: url ?? track.streamUrl,
      lyricLines: timedLyrics.isNotEmpty ? timedLyrics : track.lyricLines,
      lyrics: timedLyrics.isNotEmpty
          ? timedLyrics.map((l) => l.text).toList(growable: false)
          : track.lyrics,
    );
    final updatedTracks = [
      for (final t in state.tracks)
        if (t.id == resolved.id) resolved else t,
    ];
    if (!updatedTracks.any((t) => t.id == resolved.id)) {
      updatedTracks.add(resolved);
    }
    state = state.copyWith(tracks: List<Track>.unmodifiable(updatedTracks));
    _persistTracks();
    if (resolved.streamUrl != null && resolved.streamUrl!.isNotEmpty) {
      playTrack(resolved.id);
    } else {
      state = state.copyWith(isPlaying: false);
    }
  }
}

/// Riverpod provider for the active [AudioEngineAdapter].
final audioEngineProvider = Provider<AudioEngineAdapter>(
  (ref) => NoopAudioEngine(),
);

/// Riverpod provider for the active [AppStorage].
final appStorageProvider = Provider<AppStorage>((ref) => AppStorage.memory());

/// Whether [PlayerNotifier] starts with an empty production state (no fake data).
final emptyStartProvider = Provider<bool>((ref) => false);

/// Global Riverpod provider for [PlayerNotifier] and [PlayerState].
final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((
  ref,
) {
  return PlayerNotifier(
    audioEngine: ref.watch(audioEngineProvider),
    storage: ref.watch(appStorageProvider),
    emptyStart: ref.watch(emptyStartProvider),
  );
});
