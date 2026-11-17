import 'dart:convert';
import 'dart:io';

import 'package:aura_music/core/models/track.dart';
import 'package:aura_music/core/playlist/playlist_codec.dart';
import 'package:aura_music/core/scanner/local_music_scanner.dart';
import 'package:aura_music/core/source/js_plugin_bridge.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalMusicScanner.scanDirectories', () {
    late Directory tempRoot;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('aura_scanner_test_');

      final musicDir = Directory(
        '${tempRoot.path}${Platform.pathSeparator}Music',
      )..createSync(recursive: true);
      final recordingsDir = Directory(
        '${tempRoot.path}${Platform.pathSeparator}Recordings',
      )..createSync(recursive: true);

      // Valid >= 500 KB MP3 with "Artist - Title" naming.
      final validMp3 = File(
        '${musicDir.path}${Platform.pathSeparator}林屿森 - 星云漫游.mp3',
      );
      await validMp3.writeAsBytes(List<int>.filled(520 * 1024, 1));

      // Tiny < 500 KB MP3 that should be filtered out when smartFilter is true.
      final tinyMp3 = File(
        '${musicDir.path}${Platform.pathSeparator}Tiny - Clip.mp3',
      );
      await tinyMp3.writeAsBytes(List<int>.filled(100 * 1024, 2));

      // Recording >= 500 KB inside /Recordings/ that should be black-filtered.
      final recordingMp3 = File(
        '${recordingsDir.path}${Platform.pathSeparator}rec.mp3',
      );
      await recordingMp3.writeAsBytes(List<int>.filled(600 * 1024, 3));

      // Non-audio file that should always be ignored.
      final textFile = File(
        '${musicDir.path}${Platform.pathSeparator}readme.txt',
      );
      await textFile.writeAsString('not audio');
    });

    tearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test(
      'finds valid >=500KB audio and filters recordings & tiny files',
      () async {
        final tracks = await LocalMusicScanner.scanDirectories([tempRoot.path]);

        expect(tracks, hasLength(1));
        expect(tracks.single.artist, '林屿森');
        expect(tracks.single.title, '星云漫游');
        expect(tracks.single.localPath, endsWith('林屿森 - 星云漫游.mp3'));
        expect(tracks.single.sourceId, 'local');
      },
    );

    test('returns all audio files when smartFilter is false', () async {
      final tracks = await LocalMusicScanner.scanDirectories([
        tempRoot.path,
      ], smartFilter: false);

      expect(tracks, hasLength(3));
    });

    test('defaultMusicDirectories returns platform paths', () {
      final dirs = LocalMusicScanner.defaultMusicDirectories();
      expect(dirs, isNotEmpty);
    });
  });

  group('PlaylistCodec', () {
    const sampleList = [
      Track(
        id: 'trk_local_1',
        title: '星云漫游',
        artist: '林屿森',
        album: '深空声景',
        quality: 'Hi-Res',
        sourceId: 'local',
        durationSeconds: 264,
        colors: [Color(0xFF1E1B4B), Color(0xFF4338CA), Color(0xFF38BDF8)],
        lyrics: ['穿过尘埃与微光'],
        localPath: '/music/林屿森 - 星云漫游.flac',
      ),
      Track(
        id: 'trk_remote_2',
        title: '落日玻璃海',
        artist: '苏知夏',
        album: '海岸折射率',
        quality: 'SQ',
        sourceId: 'external',
        durationSeconds: 238,
        colors: [Color(0xFF7C2D12), Color(0xFFEA580C), Color(0xFFFDE047)],
        lyrics: ['橘色潮汐漫过堤岸线'],
        streamUrl: 'https://example.com/audio/sunset.mp3',
      ),
    ];

    test('M3U export and parse round-trip preserves metadata and paths', () {
      final m3u = PlaylistCodec.toM3u('深夜精选', sampleList);
      expect(m3u, startsWith('#EXTM3U'));
      expect(m3u, contains('#EXTINF:264,林屿森 - 星云漫游'));

      final parsed = PlaylistCodec.parseM3u(m3u);
      expect(parsed.name, '深夜精选');
      expect(parsed.tracks, hasLength(2));

      expect(parsed.tracks[0].artist, '林屿森');
      expect(parsed.tracks[0].title, '星云漫游');
      expect(parsed.tracks[0].durationSeconds, 264);
      expect(parsed.tracks[0].localPath, '/music/林屿森 - 星云漫游.flac');

      expect(parsed.tracks[1].artist, '苏知夏');
      expect(parsed.tracks[1].title, '落日玻璃海');
      expect(parsed.tracks[1].durationSeconds, 238);
      expect(
        parsed.tracks[1].streamUrl,
        'https://example.com/audio/sunset.mp3',
      );
    });

    test('JSON export and parse round-trip preserves full track fields', () {
      final encoded = PlaylistCodec.toJson('我的收藏', sampleList);
      final decoded = PlaylistCodec.parseJson(encoded);

      expect(decoded.name, '我的收藏');
      expect(decoded.tracks, hasLength(2));
      expect(decoded.tracks[0].id, 'trk_local_1');
      expect(decoded.tracks[0].localPath, '/music/林屿森 - 星云漫游.flac');
      expect(
        decoded.tracks[1].streamUrl,
        'https://example.com/audio/sunset.mp3',
      );
    });
  });

  group('CommunityPluginManifest & OAuthPkceHelper', () {
    test('parses JS header metadata manifest', () {
      const jsScript = '''
// @id netease_community
// @name Netease Community
// @version 1.2.0
// @author AuraCommunity
// @apiBase https://api.example.com/music
// @oauthUrl https://auth.example.com/oauth/authorize
// @oauthTokenUrl https://auth.example.com/oauth/token
// @clientId aura_client_123

function search(q) { return []; }
''';

      final manifest = CommunityPluginManifest.parse(jsScript);
      expect(manifest.id, 'netease_community');
      expect(manifest.name, 'Netease Community');
      expect(manifest.version, '1.2.0');
      expect(manifest.author, 'AuraCommunity');
      expect(manifest.apiBase, 'https://api.example.com/music');
      expect(
        manifest.oauthAuthorizeUrl,
        'https://auth.example.com/oauth/authorize',
      );
      expect(manifest.oauthTokenUrl, 'https://auth.example.com/oauth/token');
      expect(manifest.clientId, 'aura_client_123');
      expect(manifest.scriptBody, contains('function search'));
    });

    test('parses JSON manifest', () {
      final jsonManifest = jsonEncode({
        'id': 'qq_community',
        'name': 'QQ Community',
        'version': '2.0.1',
        'author': 'CommunityDev',
        'apiBase': 'https://qq.example.com/v1',
        'oauthAuthorizeUrl': 'https://qq.example.com/oauth/authorize',
        'clientId': 'qq_client',
      });

      final manifest = CommunityPluginManifest.parse(jsonManifest);
      expect(manifest.id, 'qq_community');
      expect(manifest.name, 'QQ Community');
      expect(manifest.version, '2.0.1');
      expect(manifest.apiBase, 'https://qq.example.com/v1');
      expect(manifest.clientId, 'qq_client');
    });

    test(
      'OAuthPkceHelper generates valid S256 challenge and authorize URI',
      () {
        final verifier = OAuthPkceHelper.generateCodeVerifier();
        expect(verifier.length, greaterThanOrEqualTo(43));
        expect(verifier.length, lessThanOrEqualTo(128));
        expect(verifier, isNot(contains('=')));

        final challenge = OAuthPkceHelper.generateCodeChallenge(verifier);
        final expectedChallenge = base64UrlEncode(
          sha256.convert(utf8.encode(verifier)).bytes,
        ).replaceAll('=', '');
        expect(challenge, expectedChallenge);

        final uri = OAuthPkceHelper.buildAuthorizeUri(
          authorizeUrl: 'https://auth.example.com/oauth/authorize',
          clientId: 'client_abc',
          redirectUri: 'auramusic://oauth/callback',
          codeChallenge: challenge,
          state: 'xyz_state',
        );

        expect(uri.scheme, 'https');
        expect(uri.host, 'auth.example.com');
        expect(uri.queryParameters['response_type'], 'code');
        expect(uri.queryParameters['client_id'], 'client_abc');
        expect(uri.queryParameters['code_challenge'], challenge);
        expect(uri.queryParameters['code_challenge_method'], 'S256');
        expect(uri.queryParameters['state'], 'xyz_state');
      },
    );
  });
}
