/// Metadata candidate discovered during a local device storage scan.
class LocalAudioCandidate {
  /// Creates a [LocalAudioCandidate].
  const LocalAudioCandidate({
    required this.path,
    required this.title,
    required this.artist,
    required this.durationSeconds,
    required this.sizeBytes,
  });

  final String path;
  final String title;
  final String artist;
  final int durationSeconds;
  final int sizeBytes;
}

/// Scans and filters local audio files following Huawei Music's
/// `MediaStoreHelper.isBlackFilterFile` convention.
class LocalMusicScanner {
  const LocalMusicScanner._();

  /// Directory segments excluded when smart filtering is enabled.
  static const List<String> blackDirectories = [
    '/Recordings/',
    '/Ringtones/',
    '/Notifications/',
    '/Sounds/',
    '/WeChat/',
  ];

  /// Minimum duration (in seconds) required for a valid music track.
  static const int minDurationSeconds = 60;

  /// Minimum file size (500 KB) required for a valid music track.
  static const int minSizeBytes = 500 * 1024;

  /// Returns `true` if [candidate] matches Huawei Music's black-filter rules:
  /// - Resides in `/Recordings/`, `/Ringtones/`, `/Notifications/`,
  ///   `/Sounds/`, or `/WeChat/`
  /// - Shorter than 60 seconds
  /// - Smaller than 500 KB
  static bool isBlackFilterFile(LocalAudioCandidate candidate) {
    if (candidate.durationSeconds < minDurationSeconds ||
        candidate.sizeBytes < minSizeBytes) {
      return true;
    }

    final normalizedPath = candidate.path.replaceAll('\\', '/').toLowerCase();
    for (final dir in blackDirectories) {
      if (normalizedPath.contains(dir.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  /// Filters [candidates] by removing recordings, ringtones, notifications,
  /// short clips (< 60s), and tiny files (< 500KB) when [smartFilter] is true.
  static List<LocalAudioCandidate> filterMusic(
    List<LocalAudioCandidate> candidates, {
    bool smartFilter = true,
  }) {
    if (!smartFilter) {
      return List<LocalAudioCandidate>.from(candidates);
    }
    return candidates
        .where((candidate) => !isBlackFilterFile(candidate))
        .toList(growable: false);
  }
}
