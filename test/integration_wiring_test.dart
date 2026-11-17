import 'package:flutter_test/flutter_test.dart';

import 'package:aura_music/core/audio/audio_engine.dart';
import 'package:aura_music/core/audio/ohos_audio_bridge.dart';
import 'package:aura_music/core/models/playlist.dart';
import 'package:aura_music/core/state/player_provider.dart';
import 'package:aura_music/core/storage/app_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayerNotifier persistence & audio wiring', () {
    test(
      'persists playlists, playHistory, and settings across fresh PlayerNotifier instances',
      () async {
        final storage = AppStorage.memory();
        final engine1 = NoopAudioEngine();
        final notifier1 = PlayerNotifier(
          audioEngine: engine1,
          storage: storage,
        );
        await notifier1.init();

        notifier1.createPlaylist('夜晚飞行歌单');
        notifier1.playTrack('trk_02');
        notifier1.toggleTheme();
        notifier1.toggleAmbient();
        notifier1.cyclePlayMode();
        notifier1.setQuality(AudioQuality.sqLossless);

        // Allow fire-and-forget async storage writes to settle.
        await Future<void>.delayed(Duration.zero);

        final engine2 = NoopAudioEngine();
        final notifier2 = PlayerNotifier(
          audioEngine: engine2,
          storage: storage,
        );
        await notifier2.init();

        expect(
          notifier2.state.playlists.any((pl) => pl.name == '夜晚飞行歌单'),
          isTrue,
        );
        expect(notifier2.state.playHistory, isNotEmpty);
        expect(notifier2.state.playHistory.first.trackId, 'trk_02');
        expect(notifier2.state.isDark, isFalse);
        expect(notifier2.state.ambientEnabled, isFalse);
        expect(notifier2.state.playMode, PlayMode.loopOne);
        expect(notifier2.state.quality, AudioQuality.sqLossless);

        notifier1.dispose();
        notifier2.dispose();
        await engine1.dispose();
        await engine2.dispose();
      },
    );

    test(
      'importPlaylistRaw parses #EXTM3U, adds tracks and playlist, and persists',
      () async {
        final storage = AppStorage.memory();
        final engine = NoopAudioEngine();
        final notifier = PlayerNotifier(audioEngine: engine, storage: storage);
        await notifier.init();

        const m3u = '''
#EXTM3U
#PLAYLIST:星河漫游
#EXTINF:215,Aura Artist - Midnight Orbit
https://stream.example.com/midnight_orbit.flac
#EXTINF:180,Local Band - Dawn Echo
/music/dawn_echo.mp3
''';

        final imported = await notifier.importPlaylistRaw(m3u);
        expect(imported, isTrue);

        final playlist = notifier.state.playlists.firstWhere(
          (pl) => pl.name == '星河漫游',
        );
        expect(playlist.type, PlaylistType.imported);
        expect(playlist.trackIds.length, 2);

        final firstTrack = notifier.state.tracks.firstWhere(
          (t) => t.id == playlist.trackIds.first,
        );
        expect(firstTrack.title, 'Midnight Orbit');
        expect(firstTrack.artist, 'Aura Artist');
        expect(
          firstTrack.streamUrl,
          'https://stream.example.com/midnight_orbit.flac',
        );

        // Verify driving NoopAudioEngine when playing an imported track with streamUrl.
        notifier.playTrack(firstTrack.id);
        expect(engine.currentSource, firstTrack.streamUrl);
        expect(engine.isPlaying, isTrue);

        // Verify position/duration/completion stream wiring.
        engine.emitDuration(const Duration(seconds: 215));
        engine.emitPosition(const Duration(seconds: 100));
        await Future<void>.delayed(Duration.zero);
        expect(notifier.state.progress, closeTo(100 / 215, 0.01));

        final secondId = playlist.trackIds[1];
        notifier.replaceQueue('星河漫游', playlist.trackIds);
        engine.emitCompleted();
        await Future<void>.delayed(Duration.zero);
        expect(notifier.state.currentTrackId, secondId);

        notifier.dispose();
        await engine.dispose();
      },
    );

    test(
      'importPluginScript parses // @name JS plugin header and persists across reload',
      () async {
        final storage = AppStorage.memory();
        final engine = NoopAudioEngine();
        final notifier = PlayerNotifier(audioEngine: engine, storage: storage);
        await notifier.init();

        const jsPlugin = '''
// @id bilibili_audio
// @name 哔哩哔哩音频插件
// @version 1.2.3
// @author AuraCommunity
// @apiBase https://api.bili-audio.example.com
function search(q) { return []; }
''';

        final ok = await notifier.importPluginScript(jsPlugin);
        expect(ok, isTrue);
        expect(
          notifier.state.sources.any(
            (s) =>
                s.id == 'bilibili_audio' &&
                s.name == '哔哩哔哩音频插件' &&
                s.version == '1.2.3',
          ),
          isTrue,
        );

        await notifier.authorizeOAuth(
          'bilibili_audio',
          token: 'test_pkce_token',
        );

        final reloaded = PlayerNotifier(
          audioEngine: NoopAudioEngine(),
          storage: storage,
        );
        await reloaded.init();

        final loadedPlugin = reloaded.state.sources.firstWhere(
          (s) => s.id == 'bilibili_audio',
        );
        expect(loadedPlugin.connected, isTrue);
        expect(storage.loadOAuthTokens()?['bilibili_audio'], 'test_pkce_token');

        notifier.dispose();
        reloaded.dispose();
        await engine.dispose();
      },
    );
  });
}
