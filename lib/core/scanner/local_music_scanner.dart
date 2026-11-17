import 'dart:io';

import 'package:flutter/material.dart';

import '../models/track.dart';

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

  /// Supported audio file extensions for local filesystem scanning.
  static const List<String> supportedExtensions = [
    '.mp3',
    '.flac',
    '.wav',
    '.m4a',
    '.aac',
    '.ogg',
  ];

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

  static const List<Color> _defaultLocalColors = [
    Color(0xFF1E1B4B),
    Color(0xFF4338CA),
    Color(0xFF38BDF8),
  ];

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

  /// Returns platform-appropriate Music and Downloads directories.
  static List<String> defaultMusicDirectories() {
    if (Platform.isAndroid) {
      return const [
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Download',
      ];
    }

    if (Platform.isWindows) {
      final home = Platform.environment['USERPROFILE'];
      if (home == null || home.isEmpty) {
        return const [];
      }
      return ['$home\\Music', '$home\\Downloads'];
    }

    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) {
      return const [];
    }
    return ['$home/Music', '$home/Downloads'];
  }

  /// Recursively scans [directories] for supported audio files and returns
  /// discovered [Track] entries with `localPath` populated.
  ///
  /// When [smartFilter] is `true`, files matching [isBlackFilterFile] or
  /// smaller than [minSizeBytes] (500 KB) are excluded.
  static Future<List<Track>> scanDirectories(
    List<String> directories, {
    bool smartFilter = true,
  }) async {
    final tracks = <Track>[];
    final seenPaths = <String>{};

    for (final dirPath in directories) {
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        continue;
      }

      try {
        await for (final entity in dir.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is! File) {
            continue;
          }

          final filePath = entity.path;
          if (!seenPaths.add(filePath)) {
            continue;
          }

          final extension = _extractExtension(filePath);
          if (!supportedExtensions.contains(extension)) {
            continue;
          }

          final stat = await entity.stat();
          final sizeBytes = stat.size;
          final parsed = _parseArtistAndTitle(filePath);

          if (smartFilter) {
            final candidate = LocalAudioCandidate(
              path: filePath,
              title: parsed.title,
              artist: parsed.artist,
              // Real file stat does not expose audio duration without a decoder;
              // use minDurationSeconds so path and size rules still apply.
              durationSeconds: minDurationSeconds,
              sizeBytes: sizeBytes,
            );
            if (isBlackFilterFile(candidate) || sizeBytes < minSizeBytes) {
              continue;
            }
          }

          tracks.add(
            Track(
              id: 'local_${filePath.hashCode.abs()}',
              title: parsed.title,
              artist: parsed.artist,
              album: '本地音乐',
              quality: _qualityForExtension(extension),
              sourceId: 'local',
              durationSeconds: 0,
              colors: _defaultLocalColors,
              lyrics: const ['本地音频文件'],
              localPath: filePath,
            ),
          );
        }
      } on FileSystemException {
        // Ignore directories that cannot be listed due to permissions.
      }
    }

    return tracks;
  }

  static String _extractExtension(String filePath) {
    final dotIndex = filePath.lastIndexOf('.');
    if (dotIndex < 0) {
      return '';
    }
    return filePath.substring(dotIndex).toLowerCase();
  }

  static String _qualityForExtension(String extension) {
    if (extension == '.flac' || extension == '.wav') {
      return 'Hi-Res';
    }
    return 'SQ';
  }

  static ({String artist, String title}) _parseArtistAndTitle(String filePath) {
    final fileName = filePath.split(RegExp(r'[/\\]')).last;
    final dotIndex = fileName.lastIndexOf('.');
    final baseName = dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;

    final separatorIndex = baseName.indexOf(' - ');
    if (separatorIndex > 0) {
      final artist = baseName.substring(0, separatorIndex).trim();
      final title = baseName.substring(separatorIndex + 3).trim();
      if (artist.isNotEmpty && title.isNotEmpty) {
        return (artist: artist, title: title);
      }
    }

    return (artist: '本地艺术家', title: baseName.isEmpty ? fileName : baseName);
  }
}
