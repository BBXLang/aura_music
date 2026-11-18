import 'dart:convert';
import 'dart:typed_data';

import 'package:aura_music/core/audio/audio_engine.dart';
import 'package:aura_music/core/audio/ohos_audio_bridge.dart';
import 'package:aura_music/core/models/playlist.dart';
import 'package:aura_music/core/models/source_plugin.dart';
import 'package:aura_music/core/models/track.dart';
import 'package:aura_music/core/scanner/local_music_scanner.dart';
import 'package:aura_music/core/state/player_provider.dart';
import 'package:aura_music/core/storage/app_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Track & sampleTracks', () {
    test('contains 16 rich sample tracks with formatted durations', () {
      expect(sampleTracks, hasLength(16));
      final titles = sampleTracks.map((t) => t.title).toSet();
      expect(titles, containsAll(['星云漫游', '落日玻璃海', '极光森林', '午夜黄金律', '量子雨夜']));
      expect(sampleTracks.first.formattedDuration, '04:24');
      expect(
        sampleTracks.every((t) => t.colors.length == 3 && t.lyrics.isNotEmpty),
        isTrue,
      );
    });
  });

  group('LocalMusicScanner.filterMusic', () {
    const validTrack = LocalAudioCandidate(
      path: '/storage/emulated/0/Music/aura_track.flac',
      title: 'Aura Track',
      artist: 'Artist A',
      durationSeconds: 210,
      sizeBytes: 24 * 1024 * 1024,
    );

    const recordingFile = LocalAudioCandidate(
      path: '/storage/emulated/0/Recordings/voice_memo.m4a',
      title: 'Voice Memo',
      artist: 'Unknown',
      durationSeconds: 180,
      sizeBytes: 3 * 1024 * 1024,
    );

    const ringtoneFile = LocalAudioCandidate(
      path: '/storage/emulated/0/Ringtones/morning_bell.mp3',
      title: 'Morning Bell',
      artist: 'System',
      durationSeconds: 90,
      sizeBytes: 1024 * 1024,
    );

    const notificationFile = LocalAudioCandidate(
      path: '/storage/emulated/0/Notifications/ping.ogg',
      title: 'Ping',
      artist: 'System',
      durationSeconds: 65,
      sizeBytes: 600 * 1024,
    );

    const soundsFile = LocalAudioCandidate(
      path: '/storage/emulated/0/Sounds/clip.wav',
      title: 'Clip',
      artist: 'System',
      durationSeconds: 120,
      sizeBytes: 2 * 1024 * 1024,
    );

    const wechatFile = LocalAudioCandidate(
      path: '/storage/emulated/0/Tencent/WeChat/audio_01.amr',
      title: 'WeChat Voice',
      artist: 'Friend',
      durationSeconds: 75,
      sizeBytes: 700 * 1024,
    );

    const shortAudio = LocalAudioCandidate(
      path: '/storage/emulated/0/Music/intro_59s.mp3',
      title: 'Short Intro',
      artist: 'Artist B',
      durationSeconds: 59,
      sizeBytes: 2 * 1024 * 1024,
    );

    const tinyAudio = LocalAudioCandidate(
      path: '/storage/emulated/0/Music/tiny_file.mp3',
      title: 'Tiny File',
      artist: 'Artist C',
      durationSeconds: 180,
      sizeBytes: 400 * 1024,
    );

    const allCandidates = [
      validTrack,
      recordingFile,
      ringtoneFile,
      notificationFile,
      soundsFile,
      wechatFile,
      shortAudio,
      tinyAudio,
    ];

    test(
      'filters out recordings, ringtones, notifications, <60s, and <500KB',
      () {
        final filtered = LocalMusicScanner.filterMusic(allCandidates);
        expect(filtered, hasLength(1));
        expect(filtered.single.title, 'Aura Track');
      },
    );

    test('returns all candidates when smartFilter is false', () {
      final unfiltered = LocalMusicScanner.filterMusic(
        allCandidates,
        smartFilter: false,
      );
      expect(unfiltered, hasLength(allCandidates.length));
    });
  });

  group('OhosAudioBridge', () {
    test('safely no-ops when platform channel is unavailable', () async {
      const bridge = OhosAudioBridge();
      await bridge.playTrack(sampleTracks.first);
      await bridge.pause();
      await bridge.resume();
      await bridge.seek(42);
      await bridge.setQuality(AudioQuality.audioVivid);
      await bridge.updateMetadata(sampleTracks.first);
      await bridge.updatePlaybackState(isPlaying: true, positionSeconds: 42);
      await bridge.setDesktopLyricsEnabled(true, currentLyric: '星云在耳畔缓缓铺张');
      await bridge.updateDesktopLyricLine('穿过尘埃与微光');
    });
  });

  group('PlayerNotifier', () {
    test('records playHistory up to 50 entries without replacing queue', () {
      final notifier = PlayerNotifier();
      expect(notifier.state.playHistory, isEmpty);
      expect(notifier.state.recentQueues, isEmpty);

      for (var i = 0; i < 55; i++) {
        final track = sampleTracks[i % sampleTracks.length];
        notifier.playTrack(track.id);
      }

      expect(notifier.state.playHistory, hasLength(50));
      expect(notifier.state.recentQueues, isEmpty);
      expect(notifier.state.isPlaying, isTrue);
    });

    test('reorderQueue and removeFromQueue do NOT create recentQueues', () {
      final notifier = PlayerNotifier();
      notifier.playTrack('trk_02');
      final initialLength = notifier.state.queue.length;

      notifier.reorderQueue(0, 3);
      expect(notifier.state.queue, hasLength(initialLength));
      expect(notifier.state.currentTrackId, 'trk_02');
      expect(notifier.state.recentQueues, isEmpty);

      final indexToRemove = notifier.state.queue.indexOf('trk_03');
      notifier.removeFromQueue(indexToRemove);
      expect(notifier.state.queue, hasLength(initialLength - 1));
      expect(notifier.state.queue, isNot(contains('trk_03')));
      expect(notifier.state.recentQueues, isEmpty);
    });

    test(
      'replaceQueue caps recentQueues at 3 and switchRecentQueue restores it',
      () {
        final notifier = PlayerNotifier();

        notifier.replaceQueue('队列 A', ['trk_01', 'trk_02']);
        notifier.replaceQueue('队列 B', ['trk_03', 'trk_04']);
        notifier.replaceQueue('队列 C', ['trk_05', 'trk_06']);
        notifier.replaceQueue('队列 D', ['trk_07', 'trk_08']);

        expect(notifier.state.queueName, '队列 D');
        expect(notifier.state.recentQueues, hasLength(3));
        expect(notifier.state.recentQueues.map((q) => q.name).toList(), [
          '队列 C',
          '队列 B',
          '队列 A',
        ]);

        notifier.switchRecentQueue(1); // Restore '队列 B'
        expect(notifier.state.queueName, '队列 B');
        expect(notifier.state.queue, ['trk_03', 'trk_04']);
        expect(notifier.state.recentQueues.first.name, '队列 D');
      },
    );

    test('PlayMode loopList, loopOne, and playOnce behave as expected', () {
      final notifier = PlayerNotifier();
      notifier.replaceQueue('测试队列', ['trk_01', 'trk_02', 'trk_03']);

      // Default: PlayMode.loopList
      expect(notifier.state.playMode, PlayMode.loopList);
      notifier.nextTrack(auto: true);
      expect(notifier.state.currentTrackId, 'trk_02');
      notifier.nextTrack(auto: true);
      expect(notifier.state.currentTrackId, 'trk_03');
      notifier.nextTrack(auto: true);
      expect(notifier.state.currentTrackId, 'trk_01');

      // Cycle to PlayMode.loopOne
      notifier.cyclePlayMode();
      expect(notifier.state.playMode, PlayMode.loopOne);
      notifier.nextTrack(auto: true);
      expect(notifier.state.currentTrackId, 'trk_01');
      expect(notifier.state.isPlaying, isTrue);
      // Manual next still advances in loopOne
      notifier.nextTrack(auto: false);
      expect(notifier.state.currentTrackId, 'trk_02');

      // Cycle to PlayMode.playOnce
      notifier.cyclePlayMode();
      expect(notifier.state.playMode, PlayMode.playOnce);
      notifier.nextTrack(auto: true);
      expect(notifier.state.isPlaying, isFalse);

      // Cycle wraps back to loopList
      notifier.cyclePlayMode();
      expect(notifier.state.playMode, PlayMode.loopList);
    });

    test(
      'playlist, local scan, lyrics, and settings mutations work cleanly',
      () {
        final notifier = PlayerNotifier();
        notifier.createPlaylist('周末公路');
        expect(
          notifier.state.playlists.any(
            (p) => p.name == '周末公路' && p.type == PlaylistType.user,
          ),
          isTrue,
        );

        notifier.importPlaylist('导入歌单', ['trk_01', 'trk_05']);
        expect(
          notifier.state.playlists.any(
            (p) => p.name == '导入歌单' && p.type == PlaylistType.imported,
          ),
          isTrue,
        );

        final beforeCount = notifier.state.tracks.length;
        notifier.scanLocalMusic();
        expect(notifier.state.tracks.length, greaterThan(beforeCount));

        notifier.jumpLyric(2);
        expect(notifier.state.activeLyric, 2);

        final initialLiked = notifier.state.currentTrack!.liked;
        notifier.toggleLike();
        expect(notifier.state.currentTrack!.liked, !initialLiked);

        notifier.toggleAmbient();
        notifier.toggleDesktopLyrics();
        notifier.toggleTheme();
        notifier.toggleSmartLocalFilter();
        notifier.toggleOAuth('qq');
        expect(notifier.state.ambientEnabled, isFalse);
        expect(notifier.state.desktopLyrics, isTrue);
        expect(notifier.state.isDark, isFalse);
        expect(notifier.state.smartLocalFilter, isFalse);
        expect(
          notifier.state.sources.firstWhere((s) => s.id == 'qq').connected,
          isTrue,
        );
      },
    );

    test(
      'timed & word-synced lyrics update activeLyric and lineProgress',
      () async {
        final engine = NoopAudioEngine();
        final notifier = PlayerNotifier(audioEngine: engine);
        await notifier.init();

        final timedTrack = Track(
          id: 'trk_timed',
          title: '成都',
          artist: '赵雷',
          album: '成都',
          quality: 'Hi-Res',
          sourceId: 'local',
          durationSeconds: 300,
          colors: sampleTracks.first.colors,
          lyrics: const ['让我掉下眼泪的', '不止昨夜的酒'],
          lyricLines: const [
            LyricLine(
              timeSeconds: 10.0,
              text: '让我掉下眼泪的',
              words: [
                LyricWord(timeSeconds: 10.0, text: '让我'),
                LyricWord(timeSeconds: 11.0, text: '掉下'),
                LyricWord(timeSeconds: 12.0, text: '眼泪'),
                LyricWord(timeSeconds: 13.0, text: '的'),
              ],
            ),
            LyricLine(timeSeconds: 15.0, text: '不止昨夜的酒'),
          ],
        );
        expect(timedTrack.lineProgressAt(0, 11.5), closeTo(0.375, 0.01));
        expect(timedTrack.lineProgressAt(0, 12.0), closeTo(0.5, 0.01));

        notifier.state = notifier.state.copyWith(
          tracks: [...notifier.state.tracks, timedTrack],
        );
        notifier.playTrack('trk_timed');
        engine.emitPosition(const Duration(milliseconds: 11500));
        await Future<void>.delayed(Duration.zero);
        expect(notifier.state.activeLyric, 0);
        expect(notifier.state.lyricLineProgress, closeTo(0.375, 0.01));

        engine.emitPosition(const Duration(milliseconds: 16000));
        await Future<void>.delayed(Duration.zero);
        expect(notifier.state.activeLyric, 1);

        notifier.dispose();
      },
    );

    test(
      'unauthenticated OAuth sources default to disconnected and sanitize missing tokens',
      () async {
        final storage = AppStorage.memory();
        await storage.saveSources(const [
          SourcePlugin(
            id: 'netease',
            name: '网易云',
            version: '1.0.0',
            connected: true,
            tierLabel: 'Hi-Res',
          ),
        ]);

        final notifier = PlayerNotifier(storage: storage);
        expect(notifier.state.sources.every((s) => !s.connected), isTrue);

        await notifier.init();
        expect(
          notifier.state.sources.firstWhere((s) => s.id == 'netease').connected,
          isFalse,
        );

        await notifier.authorizeOAuth('netease', token: '   ');
        expect(
          notifier.state.sources.firstWhere((s) => s.id == 'netease').connected,
          isFalse,
        );

        notifier.dispose();
      },
    );

    test(
      'addTrackToPlaylist, playNextInQueue, toggleTrackLike, source enable/delete, and URL JS plugin import work cleanly',
      () async {
        final storage = AppStorage.memory();
        final notifier = PlayerNotifier(storage: storage);
        await notifier.init();

        // Initial hotTracks match sampleTracks and stay separate from searchResults.
        expect(notifier.state.hotTracks, hasLength(16));
        expect(notifier.state.searchResults, isEmpty);

        // Add track to specific user playlist.
        const customTrack = Track(
          id: 'trk_custom_url',
          title: 'Custom Sky',
          artist: 'Skyline',
          album: 'Horizon',
          quality: 'Hi-Res',
          sourceId: 'remote_js',
          durationSeconds: 205,
          colors: [Color(0xFF0EA5E9), Color(0xFFF472B6)],
          lyrics: ['Look up at the sky'],
          streamUrl: 'https://example.com/sky.flac',
        );
        notifier.createPlaylist('晨间咖啡');
        final targetPl = notifier.state.playlists.firstWhere(
          (p) => p.name == '晨间咖啡',
        );
        final added = notifier.addTrackToPlaylist(targetPl.id, customTrack);
        expect(added, isTrue);
        expect(
          notifier.state.playlists
              .firstWhere((p) => p.id == targetPl.id)
              .trackIds,
          contains('trk_custom_url'),
        );

        // Toggle like by ID.
        notifier.toggleTrackLike('trk_custom_url');
        expect(
          notifier.state.tracks
              .firstWhere((t) => t.id == 'trk_custom_url')
              .liked,
          isTrue,
        );

        // Play next in queue inserts right after queuePos without disrupting current track.
        notifier.replaceQueue('主队列', ['trk_01', 'trk_02']);
        notifier.playNextInQueue(customTrack);
        expect(notifier.state.queue[0], 'trk_01');
        expect(notifier.state.queue[1], 'trk_custom_url');
        expect(notifier.state.queue[2], 'trk_02');

        // Toggle source enabled & remove source.
        notifier.toggleSourceEnabled('qq');
        expect(
          notifier.state.sources.firstWhere((s) => s.id == 'qq').enabled,
          isFalse,
        );
        await notifier.removeSource('qq');
        expect(notifier.state.sources.any((s) => s.id == 'qq'), isFalse);

        // Import JS plugin from remote HTTP URL.
        final fakeClient = _FakeHttpClient(
          '// @id cloud_js\n// @name 云端音源\n// @version 2.1.0\n// @apiBase https://api.cloud.example.com',
        );
        final okUrl = await notifier.importPluginScript(
          'https://cdn.example.com/plugins/cloud_js.js',
          httpClient: fakeClient,
        );
        expect(okUrl, isTrue);
        final imported = notifier.state.sources.firstWhere(
          (s) => s.id == 'cloud_js',
        );
        expect(imported.name, '云端音源');
        expect(
          imported.importUrl,
          'https://cdn.example.com/plugins/cloud_js.js',
        );

        notifier.dispose();
      },
    );
  });
}

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this._body);

  final String _body;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = Uint8List.fromList(utf8.encode(_body));
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable([bytes]),
      200,
      contentLength: bytes.length,
    );
  }
}
