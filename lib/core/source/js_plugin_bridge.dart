import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/playlist.dart';
import '../models/track.dart';

/// Contract that every community JS music source plugin must implement.
abstract class MusicSourceAdapter {
  /// Unique identifier of the source plugin (e.g. `netease`, `qq`).
  String get sourceId;

  /// Searches tracks on the remote source.
  Future<List<Track>> search(String query, {int page = 1, int limit = 20});

  /// Resolves a playable stream URL for [trackId] at the requested [quality].
  Future<String?> getPlayableUrl(String trackId, {String quality = 'hiRes'});

  /// Fetches the authenticated user's playlists from the source.
  Future<List<Playlist>> getUserPlaylists();

  /// Refreshes the OAuth session token for this source.
  Future<bool> refreshOAuth();
}

/// Stub QuickJS runtime bridge for executing sandboxed community JS plugins.
class QuickJsPluginBridge implements MusicSourceAdapter {
  /// Creates a [QuickJsPluginBridge] bound to [sourceId] and optional [scriptPath].
  const QuickJsPluginBridge({required this.sourceId, this.scriptPath});

  @override
  final String sourceId;

  /// Optional local path to the community JS plugin script.
  final String? scriptPath;

  @override
  Future<List<Track>> search(
    String query, {
    int page = 1,
    int limit = 20,
  }) async {
    // Stub: QuickJS runtime integration is provided by native/FFI bindings.
    if (query.trim().isEmpty) {
      return const [];
    }
    final normalized = query.trim().toLowerCase();
    return sampleTracks
        .where(
          (track) =>
              track.sourceId == sourceId &&
              (track.title.toLowerCase().contains(normalized) ||
                  track.artist.toLowerCase().contains(normalized)),
        )
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<String?> getPlayableUrl(
    String trackId, {
    String quality = 'hiRes',
  }) async {
    // Stub: returns null when no live QuickJS runtime is attached.
    return null;
  }

  @override
  Future<List<Playlist>> getUserPlaylists() async {
    // Stub: returns empty list until OAuth & QuickJS runtime are active.
    return const [];
  }

  @override
  Future<bool> refreshOAuth() async {
    // Stub: simulates successful token refresh check in offline/test mode.
    return true;
  }
}

/// Parsed metadata and script payload for a community music source plugin.
class CommunityPluginManifest {
  /// Creates a [CommunityPluginManifest].
  const CommunityPluginManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.author,
    required this.apiBase,
    this.oauthAuthorizeUrl,
    this.oauthTokenUrl,
    this.clientId,
    this.scriptBody = '',
  });

  final String id;
  final String name;
  final String version;
  final String author;
  final String apiBase;
  final String? oauthAuthorizeUrl;
  final String? oauthTokenUrl;
  final String? clientId;
  final String scriptBody;

  /// Parses a community plugin from either a JSON manifest or a JS script with
  /// `// @key value` metadata headers (`@id`, `@name`, `@version`, `@author`,
  /// `@apiBase`, `@oauthUrl`, `@oauthAuthorizeUrl`, `@oauthTokenUrl`, `@clientId`).
  factory CommunityPluginManifest.parse(String jsOrJson) {
    final trimmed = jsOrJson.trim();
    if (trimmed.startsWith('{')) {
      final decoded = jsonDecode(trimmed) as Map<String, dynamic>;
      final name = (decoded['name'] as String?)?.trim() ?? 'Unnamed Plugin';
      final rawId = (decoded['id'] as String?)?.trim();
      final id = (rawId != null && rawId.isNotEmpty) ? rawId : _slugifyId(name);
      return CommunityPluginManifest(
        id: id,
        name: name,
        version: (decoded['version'] as String?)?.trim() ?? '1.0.0',
        author: (decoded['author'] as String?)?.trim() ?? 'Community',
        apiBase: (decoded['apiBase'] as String?)?.trim() ?? '',
        oauthAuthorizeUrl:
            (decoded['oauthAuthorizeUrl'] as String?)?.trim() ??
            (decoded['oauthUrl'] as String?)?.trim(),
        oauthTokenUrl: (decoded['oauthTokenUrl'] as String?)?.trim(),
        clientId: (decoded['clientId'] as String?)?.trim(),
        scriptBody: (decoded['scriptBody'] as String?) ?? '',
      );
    }

    final metadata = <String, String>{};
    final headerPattern = RegExp(r'^//\s*@([A-Za-z0-9_]+)\s+(.+)$');
    for (final rawLine in jsOrJson.split(RegExp(r'\r?\n'))) {
      final match = headerPattern.firstMatch(rawLine.trim());
      if (match != null) {
        metadata[match.group(1)!] = match.group(2)!.trim();
      }
    }

    final name = metadata['name'] ?? 'Unnamed Plugin';
    final rawId = metadata['id'];
    final id = (rawId != null && rawId.isNotEmpty) ? rawId : _slugifyId(name);

    return CommunityPluginManifest(
      id: id,
      name: name,
      version: metadata['version'] ?? '1.0.0',
      author: metadata['author'] ?? 'Community',
      apiBase: metadata['apiBase'] ?? '',
      oauthAuthorizeUrl: metadata['oauthAuthorizeUrl'] ?? metadata['oauthUrl'],
      oauthTokenUrl: metadata['oauthTokenUrl'],
      clientId: metadata['clientId'],
      scriptBody: jsOrJson,
    );
  }

  static String _slugifyId(String name) {
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return slug.isEmpty ? 'community_plugin' : slug;
  }
}

/// RFC 7636 PKCE helper for OAuth 2.0 authorization code flow.
class OAuthPkceHelper {
  const OAuthPkceHelper._();

  /// Generates a cryptographically random PKCE `code_verifier` (64 chars).
  static String generateCodeVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(48, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  /// Derives the S256 `code_challenge` from [verifier].
  static String generateCodeChallenge(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  /// Builds an OAuth 2.0 authorization [Uri] with PKCE S256 parameters.
  static Uri buildAuthorizeUri({
    required String authorizeUrl,
    required String clientId,
    required String redirectUri,
    required String codeChallenge,
    String scope = 'read',
    String? state,
  }) {
    final baseUri = Uri.parse(authorizeUrl);
    final queryParams = Map<String, String>.from(baseUri.queryParameters)
      ..addAll({
        'response_type': 'code',
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        'scope': scope,
      });

    if (state != null && state.isNotEmpty) {
      queryParams['state'] = state;
    }

    return baseUri.replace(queryParameters: queryParams);
  }
}

/// HTTP-backed [MusicSourceAdapter] for community plugins exposing REST APIs
/// with optional OAuth Bearer token authentication.
class HttpSourceAdapter implements MusicSourceAdapter {
  /// Creates an [HttpSourceAdapter] from [manifest].
  HttpSourceAdapter({
    required this.manifest,
    this.accessToken,
    http.Client? httpClient,
  }) : _client = httpClient ?? http.Client();

  /// Plugin manifest defining API base URL and plugin metadata.
  final CommunityPluginManifest manifest;

  /// Optional OAuth 2.0 Bearer access token.
  final String? accessToken;

  final http.Client _client;

  static const List<Color> _defaultColors = [
    Color(0xFF1E1B4B),
    Color(0xFF4338CA),
    Color(0xFF38BDF8),
  ];

  @override
  String get sourceId => manifest.id;

  Map<String, String> _headers() {
    return {
      'Accept': 'application/json',
      if (accessToken != null && accessToken!.isNotEmpty)
        'Authorization': 'Bearer $accessToken',
    };
  }

  Uri _endpoint(String path, [Map<String, String>? queryParameters]) {
    final normalizedBase = manifest.apiBase.endsWith('/')
        ? manifest.apiBase.substring(0, manifest.apiBase.length - 1)
        : manifest.apiBase;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$normalizedBase$normalizedPath');
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }
    return uri.replace(queryParameters: queryParameters);
  }

  @override
  Future<List<Track>> search(
    String query, {
    int page = 1,
    int limit = 20,
  }) async {
    if (query.trim().isEmpty || manifest.apiBase.trim().isEmpty) {
      return const [];
    }

    try {
      final uri = _endpoint('/search', {
        'q': query.trim(),
        'page': page.toString(),
        'limit': limit.toString(),
      });
      final response = await _client.get(uri, headers: _headers());
      if (response.statusCode != 200) {
        return const [];
      }

      final decoded = jsonDecode(response.body);
      final rawList = switch (decoded) {
        final List<dynamic> list => list,
        final Map<String, dynamic> map =>
          (map['tracks'] as List<dynamic>?) ??
              (map['data'] as List<dynamic>?) ??
              const [],
        _ => const [],
      };

      return rawList
          .whereType<Map<String, dynamic>>()
          .take(limit)
          .map(_mapTrack)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<String?> getPlayableUrl(
    String trackId, {
    String quality = 'hiRes',
  }) async {
    if (trackId.trim().isEmpty || manifest.apiBase.trim().isEmpty) {
      return null;
    }

    try {
      final uri = _endpoint('/tracks/$trackId/stream', {'quality': quality});
      final response = await _client.get(uri, headers: _headers());
      if (response.statusCode != 200) {
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return (decoded['url'] as String?) ?? (decoded['streamUrl'] as String?);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Playlist>> getUserPlaylists() async {
    if (manifest.apiBase.trim().isEmpty ||
        accessToken == null ||
        accessToken!.isEmpty) {
      return const [];
    }

    try {
      final uri = _endpoint('/me/playlists');
      final response = await _client.get(uri, headers: _headers());
      if (response.statusCode != 200) {
        return const [];
      }

      final decoded = jsonDecode(response.body);
      final rawList = switch (decoded) {
        final List<dynamic> list => list,
        final Map<String, dynamic> map =>
          (map['playlists'] as List<dynamic>?) ??
              (map['data'] as List<dynamic>?) ??
              const [],
        _ => const [],
      };

      return rawList
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => Playlist(
              id: item['id']?.toString() ?? '',
              name: item['name']?.toString() ?? '导入歌单',
              type: PlaylistType.imported,
              trackIds: (item['trackIds'] as List<dynamic>? ?? const [])
                  .map((id) => id.toString())
                  .toList(growable: false),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<bool> refreshOAuth() async {
    final tokenUrl = manifest.oauthTokenUrl;
    if (tokenUrl == null || tokenUrl.trim().isEmpty) {
      return false;
    }

    try {
      final response = await _client.post(
        Uri.parse(tokenUrl),
        headers: _headers(),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Track _mapTrack(Map<String, dynamic> item) {
    return Track(
      id: item['id']?.toString() ?? '',
      title: item['title']?.toString() ?? '未知曲目',
      artist: item['artist']?.toString() ?? '未知艺术家',
      album: item['album']?.toString() ?? manifest.name,
      quality: item['quality']?.toString() ?? 'SQ',
      sourceId: sourceId,
      durationSeconds: (item['durationSeconds'] as num?)?.toInt() ?? 0,
      colors: _defaultColors,
      lyrics: const ['在线曲目'],
      streamUrl: item['streamUrl']?.toString() ?? item['url']?.toString(),
    );
  }
}
