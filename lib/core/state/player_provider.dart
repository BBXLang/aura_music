import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    this.playMode = PlayMode.loopList,
    this.quality = AudioQuality.hiRes,
    this.desktopLyrics = false,
    this.ambientEnabled = true,
    this.isDark = true,
    this.smartLocalFilter = true,
  });

  final List<Track> tracks;
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
    PlayMode? playMode,
    AudioQuality? quality,
    bool? desktopLyrics,
    bool? ambientEnabled,
    bool? isDark,
    bool? smartLocalFilter,
  }) {
    return PlayerState(
      tracks: tracks ?? this.tracks,
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
  bool _initialized = false;

  /// Loads persisted state from [AppStorage] and subscribes to [AudioEngineAdapter] streams.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final savedPlaylists = _storage.loadPlaylists();
    final savedHistory = _storage.loadPlayHistory();
    final savedQueues = _storage.loadRecentQueues();
    final savedSources = _storage.loadSources();
    final savedSettings = _storage.loadSettings();

    state = state.copyWith(
      playlists: savedPlaylists != null
          ? List<Playlist>.unmodifiable(savedPlaylists)
          : null,
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
      sources: savedSources != null
          ? List<SourcePlugin>.unmodifiable(savedSources)
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
      }
    });

    _positionSub = _audioEngine.positionStream.listen(_handlePositionUpdate);
    _completedSub = _audioEngine.onCompleted.listen((_) {
      nextTrack(auto: true);
    });
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
    var lyricIndex = state.activeLyric;
    if (track != null && track.lyrics.isNotEmpty) {
      lyricIndex = (nextProgress * track.lyrics.length).floor().clamp(
        0,
        track.lyrics.length - 1,
      );
    }

    state = state.copyWith(progress: nextProgress, activeLyric: lyricIndex);
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
          connected: true,
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
          connected: true,
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
    _persistHistory();
  }

  /// Toggles play/pause state for the current track.
  void togglePlay() {
    if (state.queue.isEmpty) return;
    final nextPlaying = !state.isPlaying;
    state = state.copyWith(isPlaying: nextPlaying);

    if (nextPlaying) {
      unawaited(_audioEngine.resume());
      final track = state.currentTrack;
      if (track != null) {
        _audioBridge.resume();
        _audioBridge.updatePlaybackState(
          isPlaying: true,
          positionSeconds: _currentPositionSeconds(track),
        );
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
    _persistHistory();
  }

  /// Seeks playback progress to [value] (clamped to `0.0..1.0`).
  void seek(double value) {
    final clamped = value.clamp(0.0, 1.0);
    final track = state.currentTrack;
    var lyricIndex = state.activeLyric;

    if (track != null && track.lyrics.isNotEmpty) {
      lyricIndex = (clamped * track.lyrics.length).floor().clamp(
        0,
        track.lyrics.length - 1,
      );
    }

    state = state.copyWith(progress: clamped, activeLyric: lyricIndex);

    if (track != null) {
      final totalMs =
          (_activeDuration != null && _activeDuration!.inMilliseconds > 0)
          ? _activeDuration!.inMilliseconds
          : track.durationSeconds * 1000;
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
        _audioBridge.updateDesktopLyricLine(track.lyrics[lyricIndex]);
      }
    }
  }

  /// Jumps directly to lyric line [index] and updates playback progress.
  void jumpLyric(int index) {
    final track = state.currentTrack;
    if (track == null || track.lyrics.isEmpty) return;

    final clampedIndex = index.clamp(0, track.lyrics.length - 1);
    final nextProgress = clampedIndex / track.lyrics.length;

    state = state.copyWith(activeLyric: clampedIndex, progress: nextProgress);

    final totalMs =
        (_activeDuration != null && _activeDuration!.inMilliseconds > 0)
        ? _activeDuration!.inMilliseconds
        : track.durationSeconds * 1000;
    if (totalMs > 0) {
      unawaited(
        _audioEngine.seek(
          Duration(milliseconds: (totalMs * nextProgress).round()),
        ),
      );
    }
    final posSeconds = (track.durationSeconds * nextProgress).round();
    _audioBridge.seek(posSeconds);
    if (state.desktopLyrics) {
      _audioBridge.updateDesktopLyricLine(track.lyrics[clampedIndex]);
    }
  }

  /// Toggles the liked status of the currently playing track.
  void toggleLike() {
    final currentId = state.currentTrackId;
    if (currentId == null) return;

    final updatedTracks = state.tracks
        .map(
          (track) => track.id == currentId
              ? track.copyWith(liked: !track.liked)
              : track,
        )
        .toList(growable: false);

    state = state.copyWith(tracks: updatedTracks);
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
    _persistPlaylists();
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
    await _storage.savePlaylists(state.playlists);
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
    await _storage.savePlaylists(state.playlists);
    return true;
  }

  /// Parses a community JS plugin script or JSON manifest [jsOrJson], adds or
  /// updates the corresponding [SourcePlugin], and persists to storage.
  Future<bool> importPluginScript(String jsOrJson) async {
    final trimmed = jsOrJson.trim();
    if (trimmed.isEmpty) return false;

    CommunityPluginManifest manifest;
    try {
      manifest = CommunityPluginManifest.parse(trimmed);
    } catch (_) {
      return false;
    }

    final existingIndex = state.sources.indexWhere((s) => s.id == manifest.id);
    final plugin = SourcePlugin(
      id: manifest.id,
      name: manifest.name,
      version: manifest.version,
      connected: existingIndex >= 0
          ? state.sources[existingIndex].connected
          : false,
      tierLabel: manifest.apiBase.isNotEmpty ? 'JS 插件 · HTTP' : 'JS 插件',
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

  /// Marks [sourceId] as OAuth-authorized and optionally persists [token].
  Future<void> authorizeOAuth(String sourceId, {String? token}) async {
    final updated = state.sources
        .map(
          (source) =>
              source.id == sourceId ? source.copyWith(connected: true) : source,
        )
        .toList(growable: false);
    state = state.copyWith(sources: List<SourcePlugin>.unmodifiable(updated));
    await _storage.saveSources(state.sources);

    if (token != null && token.trim().isNotEmpty) {
      final existingTokens = Map<String, String>.from(
        _storage.loadOAuthTokens() ?? const {},
      );
      existingTokens[sourceId] = token.trim();
      await _storage.saveOAuthTokens(existingTokens);
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

  /// Toggles HarmonyOS desktop floating lyrics window.
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
    _audioBridge.setDesktopLyricsEnabled(nextValue, currentLyric: line);
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
      _audioBridge.updateDesktopLyricLine(track.lyrics.first);
    }
  }

  void _persistPlaylists() {
    unawaited(_storage.savePlaylists(state.playlists));
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
    _sidecar = client;
    final verified = await client.verifySession();
    final plugin = SourcePlugin(
      id: 'huawei',
      name: '华为音乐 (Sidecar)',
      version: '1.0.0',
      connected: verified,
      tierLabel: verified ? 'Sidecar 已登录' : '待 OAuth 登录',
    );
    final updated = [...state.sources.where((s) => s.id != 'huawei'), plugin];
    state = state.copyWith(sources: List<SourcePlugin>.unmodifiable(updated));
    _persistSources();
    return true;
  }

  /// Triggers the Sidecar native WebView OAuth login flow.
  Future<bool> loginSidecar({WebViewOpenCallback? onWebViewOpen}) async {
    final client = _sidecar;
    if (client == null) return false;
    if (onWebViewOpen != null) {
      client.onWebViewOpen = onWebViewOpen;
    }
    final ok = await client.login();
    if (!ok) return false;
    final updated = state.sources
        .map(
          (s) => s.id == 'huawei'
              ? s.copyWith(connected: true, tierLabel: 'Sidecar 已登录')
              : s,
        )
        .toList(growable: false);
    state = state.copyWith(sources: List<SourcePlugin>.unmodifiable(updated));
    _persistSources();
    return true;
  }

  /// Searches the connected Sidecar source and merges results into [state.tracks].
  Future<List<Track>> searchSidecar(String query) async {
    final client = _sidecar;
    if (client == null || query.trim().isEmpty) return const [];
    final results = await client.search(query.trim());
    if (results.isEmpty) return const [];
    final existing = state.tracks.map((t) => t.id).toSet();
    final added = results.where((t) => !existing.contains(t.id)).toList();
    if (added.isNotEmpty) {
      state = state.copyWith(
        tracks: List<Track>.unmodifiable([...state.tracks, ...added]),
      );
    }
    return results;
  }

  /// Resolves stream URL & lyrics for a Sidecar track and starts playback.
  Future<void> playSidecarTrack(Track track) async {
    final client = _sidecar;
    if (client == null) return;
    final url = await client.resolveStreamUrl(track.id);
    final lyrics = await client.fetchLyrics(track.id);
    final resolved = track.copyWith(
      streamUrl: url ?? track.streamUrl,
      lyrics: lyrics.isNotEmpty ? lyrics : track.lyrics,
    );
    final updatedTracks = [
      for (final t in state.tracks)
        if (t.id == resolved.id) resolved else t,
    ];
    if (!updatedTracks.any((t) => t.id == resolved.id)) {
      updatedTracks.add(resolved);
    }
    state = state.copyWith(tracks: List<Track>.unmodifiable(updatedTracks));
    playTrack(resolved.id);
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
