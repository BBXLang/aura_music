import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/track.dart';
import '../storage/app_storage.dart';

/// Frames and parses LSP-style `Content-Length` JSON-RPC 2.0 messages.
class JsonRpcFramer {
  final BytesBuilder _buffer = BytesBuilder(copy: false);

  /// Encodes [payload] into a `Content-Length` framed byte array.
  static Uint8List encode(Map<String, dynamic> payload) {
    final bodyBytes = utf8.encode(jsonEncode(payload));
    final headerBytes = ascii.encode(
      'Content-Length: ${bodyBytes.length}\r\n\r\n',
    );
    final out = BytesBuilder(copy: false)
      ..add(headerBytes)
      ..add(bodyBytes);
    return out.takeBytes();
  }

  /// Feeds incoming [chunk] bytes and yields any complete JSON messages.
  List<Map<String, dynamic>> addBytes(List<int> chunk) {
    _buffer.add(chunk);
    final messages = <Map<String, dynamic>>[];

    while (true) {
      final bytes = _buffer.toBytes();
      final sepIndex = _findHeaderEnd(bytes);
      if (sepIndex < 0) break;

      final headerText = ascii.decode(
        bytes.sublist(0, sepIndex),
        allowInvalid: true,
      );
      final contentLength = _parseContentLength(headerText);
      if (contentLength == null) {
        // Drop malformed header bytes.
        _resetBuffer(bytes.sublist(sepIndex + 4));
        continue;
      }

      final bodyStart = sepIndex + 4;
      if (bytes.length < bodyStart + contentLength) {
        break;
      }

      final bodyBytes = bytes.sublist(bodyStart, bodyStart + contentLength);
      final remaining = bytes.sublist(bodyStart + contentLength);
      _resetBuffer(remaining);

      try {
        final decoded = jsonDecode(utf8.decode(bodyBytes));
        if (decoded is Map<String, dynamic>) {
          messages.add(decoded);
        }
      } catch (_) {
        // Ignore malformed JSON frames.
      }
    }
    return messages;
  }

  void _resetBuffer(List<int> remaining) {
    _buffer.clear();
    if (remaining.isNotEmpty) {
      _buffer.add(remaining);
    }
  }

  static int _findHeaderEnd(Uint8List bytes) {
    for (int i = 0; i <= bytes.length - 4; i++) {
      if (bytes[i] == 13 &&
          bytes[i + 1] == 10 &&
          bytes[i + 2] == 13 &&
          bytes[i + 3] == 10) {
        return i;
      }
    }
    return -1;
  }

  static int? _parseContentLength(String header) {
    for (final line in header.split('\r\n')) {
      final idx = line.indexOf(':');
      if (idx <= 0) continue;
      if (line.substring(0, idx).trim().toLowerCase() == 'content-length') {
        return int.tryParse(line.substring(idx + 1).trim());
      }
    }
    return null;
  }
}

/// Callback invoked when the Sidecar requests `host.webview.open` for OAuth.
/// Should return the final redirected callback URL (e.g. `hms://redirect_uri?code=...`),
/// or `null` if cancelled.
typedef WebViewOpenCallback =
    Future<String?> Function(
      String url,
      String callbackScheme,
      String callbackHost,
    );

/// Manages a Sidecar native source binary (e.g. `huawei-source.exe` on Windows)
/// using bidirectional `Content-Length` JSON-RPC 2.0 over stdin/stdout.
class SidecarSourceClient {
  SidecarSourceClient({
    required this.sourceId,
    required this.storage,
    this.executablePath,
    this.onWebViewOpen,
  });

  final String sourceId;
  final AppStorage storage;
  String? executablePath;
  WebViewOpenCallback? onWebViewOpen;

  Process? _process;
  StreamSubscription<List<int>>? _stdoutSub;
  final JsonRpcFramer _framer = JsonRpcFramer();
  final Map<String, Completer<dynamic>> _pending = {};
  int _nextId = 1;

  bool get isRunning => _process != null;

  /// Starts the Sidecar process if [executablePath] exists on disk.
  Future<bool> start([String? pathOverride]) async {
    final path = pathOverride ?? executablePath;
    if (path == null || path.trim().isEmpty) return false;
    executablePath = path.trim();
    if (_process != null) return true;
    final file = File(executablePath!);
    if (!await file.exists()) return false;

    _process = await Process.start(executablePath!, const []);
    _stdoutSub = _process!.stdout.listen(_onStdoutBytes);
    return true;
  }

  void _onStdoutBytes(List<int> chunk) {
    for (final msg in _framer.addBytes(chunk)) {
      final hasMethod = msg.containsKey('method');
      final id = msg['id']?.toString();
      if (hasMethod && id != null) {
        // Sidecar -> Host callback request.
        _handleHostCallback(id, msg['method'] as String, msg['params']);
      } else if (id != null && _pending.containsKey(id)) {
        final completer = _pending.remove(id)!;
        if (msg.containsKey('error') && msg['error'] != null) {
          completer.completeError(msg['error']);
        } else {
          completer.complete(msg['result']);
        }
      }
    }
  }

  Future<void> _handleHostCallback(
    String id,
    String method,
    dynamic params,
  ) async {
    dynamic result;
    if (method == 'host.session.get') {
      final key =
          (params is Map ? params['key']?.toString() : null) ?? 'session';
      final tokens = storage.loadOAuthTokens() ?? const <String, String>{};
      result = {'value': tokens['sidecar_${sourceId}_$key']};
    } else if (method == 'host.session.set') {
      final key =
          (params is Map ? params['key']?.toString() : null) ?? 'session';
      final val = params is Map ? params['value']?.toString() : null;
      final tokens = Map<String, String>.from(
        storage.loadOAuthTokens() ?? const <String, String>{},
      );
      if (val == null) {
        tokens.remove('sidecar_${sourceId}_$key');
      } else {
        tokens['sidecar_${sourceId}_$key'] = val;
      }
      await storage.saveOAuthTokens(tokens);
      result = {'ok': true};
    } else if (method == 'host.webview.open') {
      final url = (params is Map ? params['url']?.toString() : null) ?? '';
      final cb = (params is Map && params['callback'] is Map)
          ? params['callback'] as Map
          : const {};
      final scheme = cb['scheme']?.toString() ?? 'hms';
      final host = cb['host']?.toString() ?? 'redirect_uri';
      final callbackUrl = await onWebViewOpen?.call(url, scheme, host);
      if (callbackUrl != null && callbackUrl.isNotEmpty) {
        result = {'callbackUrl': callbackUrl};
      } else {
        _sendRaw({
          'jsonrpc': '2.0',
          'id': id,
          'error': {'code': -32001, 'message': 'login cancelled'},
        });
        return;
      }
    } else {
      result = null;
    }

    _sendRaw({'jsonrpc': '2.0', 'id': id, 'result': result});
  }

  void _sendRaw(Map<String, dynamic> payload) {
    _process?.stdin.add(JsonRpcFramer.encode(payload));
  }

  /// Calls a JSON-RPC method on the Sidecar process.
  Future<dynamic> call(
    String method, [
    Map<String, dynamic> params = const {},
    Duration timeout = const Duration(seconds: 20),
  ]) async {
    if (_process == null) {
      final ok = await start();
      if (!ok) {
        throw StateError('Sidecar binary not started or not found');
      }
    }
    final id = (_nextId++).toString();
    final completer = Completer<dynamic>();
    _pending[id] = completer;
    _sendRaw({'jsonrpc': '2.0', 'id': id, 'method': method, 'params': params});
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _pending.remove(id);
        throw TimeoutException('Sidecar RPC timeout: $method');
      },
    );
  }

  /// Triggers the Sidecar's native WebView OAuth login flow.
  Future<bool> login() async {
    try {
      await call('source.auth.login', {
        'kind': 'webview',
      }, const Duration(minutes: 5));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Verifies whether the stored session is still valid.
  Future<bool> verifySession() async {
    try {
      final res = await call('source.auth.verify');
      return res is Map && (res['authenticated'] == true || res['ok'] == true);
    } catch (_) {
      return false;
    }
  }

  /// Searches tracks via `source.catalog.search`.
  Future<List<Track>> search(
    String query, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final res = await call('source.catalog.search', {
      'query': query,
      'page': page,
      'pageSize': pageSize,
    });
    if (res is! Map || res['items'] is! List) return const [];
    final items = res['items'] as List;
    return items.whereType<Map<String, dynamic>>().map((item) {
      final artists =
          (item['artists'] as List?)
              ?.whereType<Map>()
              .map((a) => a['name']?.toString() ?? '')
              .where((n) => n.isNotEmpty)
              .join(' / ') ??
          '未知歌手';
      final album = (item['album'] is Map)
          ? (item['album']['title']?.toString() ?? '未知专辑')
          : '未知专辑';
      return Track(
        id: 'hw_${item['id']}',
        title: item['title']?.toString() ?? '未知曲目',
        artist: artists,
        album: album,
        quality: 'Hi-Res',
        sourceId: sourceId,
        durationSeconds: (item['durationSeconds'] as num?)?.toInt() ?? 240,
        colors: const [Color(0xFFC7000B), Color(0xFF6B4EFF), Color(0xFF00C2FF)],
        lyrics: const ['正在加载歌词...'],
      );
    }).toList();
  }

  /// Resolves a playable audio stream URL via `source.library.resolve`.
  Future<String?> resolveStreamUrl(String trackId) async {
    final rawId = trackId.startsWith('hw_') ? trackId.substring(3) : trackId;
    try {
      final res = await call('source.library.resolve', {'id': rawId});
      if (res is Map) {
        return res['url']?.toString() ?? res['streamUrl']?.toString();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Fetches lyrics via `source.lyrics.get`.
  Future<List<String>> fetchLyrics(String trackId) async {
    final rawId = trackId.startsWith('hw_') ? trackId.substring(3) : trackId;
    try {
      final res = await call('source.lyrics.get', {'id': rawId});
      if (res is Map && res['lines'] is List) {
        return (res['lines'] as List).map((e) => e.toString()).toList();
      }
      if (res is Map && res['lrc'] is String) {
        return (res['lrc'] as String)
            .split('\n')
            .map((l) => l.replaceAll(RegExp(r'\[[^\]]*\]'), '').trim())
            .where((l) => l.isNotEmpty)
            .toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  /// Stops the Sidecar process cleanly.
  Future<void> dispose() async {
    await _stdoutSub?.cancel();
    _process?.kill();
    _process = null;
  }
}
