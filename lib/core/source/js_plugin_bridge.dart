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
