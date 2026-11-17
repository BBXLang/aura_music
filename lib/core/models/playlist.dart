/// Origin category for an AuraMusic playlist.
enum PlaylistType {
  /// Auto-scanned from local device storage.
  local,

  /// Created and curated by the user inside AuraMusic.
  user,

  /// Imported from an external music source or plugin.
  imported,
}

/// Represents a named collection of track IDs.
class Playlist {
  /// Creates an immutable [Playlist] instance.
  const Playlist({
    required this.id,
    required this.name,
    required this.type,
    required this.trackIds,
  });

  final String id;
  final String name;
  final PlaylistType type;
  final List<String> trackIds;

  /// Returns a copy of this playlist with the specified fields replaced.
  Playlist copyWith({
    String? id,
    String? name,
    PlaylistType? type,
    List<String>? trackIds,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      trackIds: trackIds ?? this.trackIds,
    );
  }
}
