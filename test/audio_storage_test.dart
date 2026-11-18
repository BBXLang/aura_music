import 'package:aura_music/core/audio/audio_engine.dart';
import 'package:aura_music/core/audio/ohos_audio_bridge.dart';
import 'package:aura_music/core/models/playlist.dart';
import 'package:aura_music/core/models/source_plugin.dart';
import 'package:aura_music/core/models/track.dart';
import 'package:aura_music/core/state/player_provider.dart';
import 'package:aura_music/core/storage/app_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Model JSON serialization', () {
    test('Track round-trips through toJson and fromJson', () {
      const track = Track(
        id: 'trk_test',
        title: 'Test Track',
        artist: 'Test Artist',
        album: 'Test Album',
        quality: 'Hi-Res',
        sourceId: 'netease',
        durationSeconds: 245,
        colors: [Color(0xFF1E1B4B), Color(0xFF38BDF8)],
        lyrics: ['Line 1', 'Line 2'],
        liked: true,
        localPath: '/music/test.flac',
        streamUrl: 'https://example.com/test.flac',
      );

      final restored = Track.fromJson(track.toJson());

      expect(restored.id, track.id);
      expect(restored.title, track.title);
      expect(restored.artist, track.artist);
      expect(restored.album, track.album);
      expect(restored.quality, track.quality);
      expect(restored.sourceId, track.sourceId);
      expect(restored.durationSeconds, track.durationSeconds);
      expect(restored.colors.length, 2);
      expect(restored.colors[0].toARGB32(), track.colors[0].toARGB32());
      expect(restored.colors[1].toARGB32(), track.colors[1].toARGB32());
      expect(restored.lyrics, track.lyrics);
      expect(restored.liked, isTrue);
      expect(restored.localPath, '/music/test.flac');
      expect(restored.streamUrl, 'https://example.com/test.flac');
    });

    test('Track defaults localPath and streamUrl to null', () {
      const track = Track(
        id: 'trk_min',
        title: 'Minimal',
        artist: 'Artist',
        album: 'Album',
        quality: 'SQ',
        sourceId: 'local',
        durationSeconds: 120,
        colors: [Color(0xFF000000)],
        lyrics: [],
      );

      expect(track.localPath, isNull);
      expect(track.streamUrl, isNull);

      final restored = Track.fromJson(track.toJson());
      expect(restored.localPath, isNull);
      expect(restored.streamUrl, isNull);
      expect(restored.liked, isFalse);
    });

    test('Playlist round-trips through toJson and fromJson', () {
      const playlist = Playlist(
        id: 'pl_1',
        name: 'Late Night',
        type: PlaylistType.imported,
        trackIds: ['trk_01', 'trk_02'],
      );

      final restored = Playlist.fromJson(playlist.toJson());

      expect(restored.id, playlist.id);
      expect(restored.name, playlist.name);
      expect(restored.type, PlaylistType.imported);
      expect(restored.trackIds, ['trk_01', 'trk_02']);
    });

    test('SourcePlugin round-trips through toJson and fromJson', () {
      const plugin = SourcePlugin(
        id: 'netease',
        name: '网易云音乐',
        version: 'v2.4.1',
        connected: true,
        tierLabel: 'Hi-Res',
      );

      final restored = SourcePlugin.fromJson(plugin.toJson());

      expect(restored.id, plugin.id);
      expect(restored.name, plugin.name);
      expect(restored.version, plugin.version);
      expect(restored.connected, isTrue);
      expect(restored.tierLabel, plugin.tierLabel);
    });
  });

  group('NoopAudioEngine', () {
    test('tracks playback state, volume, and emits stream events', () async {
      final engine = NoopAudioEngine();
      final positions = <Duration>[];
      final durations = <Duration>[];
      var completedCount = 0;

      final posSub = engine.positionStream.listen(positions.add);
      final durSub = engine.durationStream.listen(durations.add);
      final doneSub = engine.onCompleted.listen((_) => completedCount++);

      await engine.playUrl('https://example.com/song.mp3');
      expect(engine.isPlaying, isTrue);
      expect(engine.currentSource, 'https://example.com/song.mp3');

      engine.emitDuration(const Duration(seconds: 180));
      await engine.seek(const Duration(seconds: 42));
      expect(engine.currentPosition, const Duration(seconds: 42));

      await engine.pause();
      expect(engine.isPlaying, isFalse);

      await engine.resume();
      expect(engine.isPlaying, isTrue);

      await engine.setVolume(0.65);
      expect(engine.volume, 0.65);

      await engine.setVolume(1.5);
      expect(engine.volume, 1.0);

      engine.emitCompleted();
      expect(engine.isPlaying, isFalse);

      await engine.playFile('/storage/music/local.flac');
      expect(engine.isPlaying, isTrue);
      expect(engine.currentSource, '/storage/music/local.flac');

      await engine.stop();
      expect(engine.isPlaying, isFalse);
      expect(engine.currentSource, isNull);

      await Future<void>.delayed(Duration.zero);
      expect(durations, [const Duration(seconds: 180)]);
      expect(positions, contains(const Duration(seconds: 42)));
      expect(completedCount, 1);

      await posSub.cancel();
      await durSub.cancel();
      await doneSub.cancel();
      await engine.dispose();
    });
  });

  group('AppStorage.memory', () {
    test('returns null before any data is saved', () {
      final storage = AppStorage.memory();

      expect(storage.loadTracks(), isNull);
      expect(storage.loadPlaylists(), isNull);
      expect(storage.loadActiveQueue(), isNull);
      expect(storage.loadPlayHistory(), isNull);
      expect(storage.loadRecentQueues(), isNull);
      expect(storage.loadSources(), isNull);
      expect(storage.loadOAuthTokens(), isNull);
      expect(storage.loadSettings(), isNull);
    });

    test(
      'saves and loads tracks, active queue, playlists, history, queues, sources, tokens, and settings',
      () async {
        final storage = AppStorage.memory();

        const tracks = [
          Track(
            id: 'hw_999',
            title: 'Cloud Song',
            artist: 'Huawei Artist',
            album: 'Cloud Album',
            quality: 'Hi-Res',
            sourceId: 'huawei',
            durationSeconds: 210,
            colors: [Color(0xFF1E1B4B), Color(0xFF38BDF8)],
            lyrics: ['Line A', 'Line B'],
            lyricLines: [
              LyricLine(
                timeSeconds: 5.0,
                text: 'Line A',
                words: [
                  LyricWord(timeSeconds: 5.0, text: 'Line'),
                  LyricWord(timeSeconds: 6.0, text: ' A'),
                ],
              ),
            ],
            streamUrl: 'https://transient.signed.example/audio.flac',
            coverUrl: 'https://cdn.example/cover.jpg',
          ),
          Track(
            id: 'trk_local_1',
            title: 'Local Song',
            artist: 'Local Artist',
            album: 'Local Album',
            quality: 'SQ',
            sourceId: 'local',
            durationSeconds: 180,
            colors: [Color(0xFF1E1B4B), Color(0xFF38BDF8)],
            lyrics: ['Local Line'],
            lyricLines: [
              LyricLine(
                timeSeconds: 2.0,
                text: 'Local Line',
                words: [LyricWord(timeSeconds: 2.0, text: 'Local')],
              ),
            ],
            localPath: '/music/local.flac',
          ),
        ];
        const playlists = [
          Playlist(
            id: 'pl_fav',
            name: 'Favorites',
            type: PlaylistType.user,
            trackIds: ['trk_01', 'trk_03'],
          ),
        ];
        const history = [
          {'trackId': 'trk_01', 'timestampLabel': '刚刚'},
          {'trackId': 'trk_03', 'timestampLabel': '10 分钟前'},
        ];
        final queues = [
          {
            'name': 'Focus Mix',
            'trackIds': ['trk_01', 'trk_02'],
            'queuePos': 1,
          },
        ];
        const sources = [
          SourcePlugin(
            id: 'qq',
            name: 'QQ 音乐',
            version: 'v1.9.0',
            connected: true,
            tierLabel: 'SQ',
          ),
        ];
        const tokens = {'qq': 'token_abc_123'};
        const settings = AppSettings(
          ambientEnabled: false,
          isDark: false,
          desktopLyrics: true,
          smartLocalFilter: false,
          playMode: PlayMode.loopOne,
          quality: AudioQuality.sqLossless,
        );

        await storage.saveTracks(tracks);
        await storage.savePlaylists(playlists);
        await storage.saveActiveQueue(
          queueName: '云端队列',
          queue: const ['hw_999'],
          queuePos: 0,
        );
        await storage.savePlayHistory(history);
        await storage.saveRecentQueues(queues);
        await storage.saveSources(sources);
        await storage.saveOAuthTokens(tokens);
        await storage.saveSettings(settings);

        final loadedTracks = storage.loadTracks();
        expect(loadedTracks, isNotNull);
        expect(loadedTracks, hasLength(2));
        expect(loadedTracks!.first.id, 'hw_999');
        expect(loadedTracks.first.coverUrl, 'https://cdn.example/cover.jpg');
        // Transient Huawei streamUrl & verbose word-timed lyrics are stripped on disk.
        expect(loadedTracks.first.streamUrl, isNull);
        expect(loadedTracks.first.lyricLines, isEmpty);
        expect(loadedTracks.last.id, 'trk_local_1');
        expect(loadedTracks.last.lyricLines.single.words.length, 1);

        final loadedActiveQueue = storage.loadActiveQueue();
        expect(loadedActiveQueue, isNotNull);
        expect(loadedActiveQueue!.queueName, '云端队列');
        expect(loadedActiveQueue.queue, ['hw_999']);
        expect(loadedActiveQueue.queuePos, 0);

        final loadedPlaylists = storage.loadPlaylists();
        expect(loadedPlaylists, isNotNull);
        expect(loadedPlaylists!.single.id, 'pl_fav');
        expect(loadedPlaylists.single.type, PlaylistType.user);
        expect(loadedPlaylists.single.trackIds, ['trk_01', 'trk_03']);

        final loadedHistory = storage.loadPlayHistory();
        expect(loadedHistory, history);

        final loadedQueues = storage.loadRecentQueues();
        expect(loadedQueues, isNotNull);
        expect(loadedQueues!.single['name'], 'Focus Mix');
        expect(loadedQueues.single['queuePos'], 1);

        final loadedSources = storage.loadSources();
        expect(loadedSources, isNotNull);
        expect(loadedSources!.single.id, 'qq');
        expect(loadedSources.single.connected, isTrue);

        expect(storage.loadOAuthTokens(), tokens);

        final loadedSettings = storage.loadSettings();
        expect(loadedSettings, isNotNull);
        expect(loadedSettings!.ambientEnabled, isFalse);
        expect(loadedSettings.isDark, isFalse);
        expect(loadedSettings.desktopLyrics, isTrue);
        expect(loadedSettings.smartLocalFilter, isFalse);
        expect(loadedSettings.playMode, PlayMode.loopOne);
        expect(loadedSettings.quality, AudioQuality.sqLossless);

        await storage.clearAll();
        expect(storage.loadTracks(), isNull);
        expect(storage.loadPlaylists(), isNull);
        expect(storage.loadActiveQueue(), isNull);
        expect(storage.loadSettings(), isNull);
      },
    );

    test(
      'PlayerNotifier(emptyStart: true) restores tracks, playlists, and active queue across restarts',
      () async {
        final storage = AppStorage.memory();

        final firstSession = PlayerNotifier(storage: storage, emptyStart: true);
        await firstSession.init();

        const playlistJson = '''
{
  "name": "夜间收藏",
  "tracks": [
    {
      "id": "trk_persist_1",
      "title": "Persistent Song",
      "artist": "Aura Artist",
      "album": "Persistent Album",
      "durationSeconds": 240,
      "streamUrl": "https://example.com/song1.flac"
    },
    {
      "id": "trk_persist_2",
      "title": "Second Song",
      "artist": "Aura Artist",
      "album": "Persistent Album",
      "durationSeconds": 195,
      "streamUrl": "https://example.com/song2.flac"
    }
  ]
}
''';
        final importedOk = await firstSession.importPlaylistRaw(playlistJson);
        expect(importedOk, isTrue);
        firstSession.replaceQueue('夜间收藏', [
          'trk_persist_1',
          'trk_persist_2',
        ], startPos: 1);
        await Future<void>.delayed(Duration.zero);
        firstSession.dispose();

        final secondSession = PlayerNotifier(
          storage: storage,
          emptyStart: true,
        );
        await secondSession.init();

        expect(
          secondSession.state.tracks.map((t) => t.id),
          containsAll(['trk_persist_1', 'trk_persist_2']),
        );
        expect(
          secondSession.state.playlists.any((p) => p.name == '夜间收藏'),
          isTrue,
        );
        expect(secondSession.state.queueName, '夜间收藏');
        expect(secondSession.state.queue, ['trk_persist_1', 'trk_persist_2']);
        expect(secondSession.state.queuePos, 1);
        expect(secondSession.state.currentTrack?.title, 'Second Song');
        secondSession.dispose();
      },
    );
  });
}
