import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/track.dart';

/// Codec for importing and exporting playlists in M3U and JSON formats.
class PlaylistCodec {
  const PlaylistCodec._();

  static const List<Color> _defaultColors = [
    Color(0xFF1E1B4B),
    Color(0xFF4338CA),
    Color(0xFF38BDF8),
  ];

  /// Parses an M3U / M3U8 playlist [content] string into a playlist name and
  /// list of [Track] objects.
  static ({String name, List<Track> tracks}) parseM3u(
    String content, {
    String name = '导入歌单',
  }) {
    var playlistName = name;
    final tracks = <Track>[];

    int? pendingDuration;
    String? pendingArtist;
    String? pendingTitle;

    final lines = content.split(RegExp(r'\r?\n'));
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line == '#EXTM3U') {
        continue;
      }

      if (line.startsWith('#PLAYLIST:')) {
        final parsedName = line.substring('#PLAYLIST:'.length).trim();
        if (parsedName.isNotEmpty) {
          playlistName = parsedName;
        }
        continue;
      }

      if (line.startsWith('#EXTINF:')) {
        final extInfo = _parseExtInf(line.substring('#EXTINF:'.length));
        pendingDuration = extInfo.durationSeconds;
        pendingArtist = extInfo.artist;
        pendingTitle = extInfo.title;
        continue;
      }

      if (line.startsWith('#')) {
        continue;
      }

      final isRemote =
          line.startsWith('http://') || line.startsWith('https://');
      final fallback = _fallbackFromLocation(line);
      final title = pendingTitle ?? fallback.title;
      final artist = pendingArtist ?? fallback.artist;
      final duration = pendingDuration ?? 0;

      tracks.add(
        Track(
          id: 'm3u_${tracks.length}_${line.hashCode.abs()}',
          title: title,
          artist: artist,
          album: playlistName,
          quality: 'SQ',
          sourceId: isRemote ? 'external' : 'local',
          durationSeconds: duration < 0 ? 0 : duration,
          colors: _defaultColors,
          lyrics: const ['导入曲目'],
          localPath: isRemote ? null : line,
          streamUrl: isRemote ? line : null,
        ),
      );

      pendingDuration = null;
      pendingArtist = null;
      pendingTitle = null;
    }

    return (name: playlistName, tracks: tracks);
  }

  /// Exports [name] and [tracks] as an `#EXTM3U` playlist string.
  static String toM3u(String name, List<Track> tracks) {
    final buffer = StringBuffer()
      ..writeln('#EXTM3U')
      ..writeln('#PLAYLIST:$name');

    for (final track in tracks) {
      buffer.writeln(
        '#EXTINF:${track.durationSeconds},${track.artist} - ${track.title}',
      );
      final location =
          track.localPath ??
          track.streamUrl ??
          'aura://track/${track.sourceId}/${track.id}';
      buffer.writeln(location);
    }

    return buffer.toString().trimRight();
  }

  /// Parses a JSON-encoded playlist string into a playlist name and [Track] list.
  static ({String name, List<Track> tracks}) parseJson(String raw) {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final name = (decoded['name'] as String?)?.trim();
    final rawTracks = decoded['tracks'] as List<dynamic>? ?? const [];

    final tracks = rawTracks
        .whereType<Map<String, dynamic>>()
        .map(Track.fromJson)
        .toList(growable: false);

    return (
      name: (name == null || name.isEmpty) ? '导入歌单' : name,
      tracks: tracks,
    );
  }

  /// Serializes [name] and [tracks] into a JSON playlist string.
  static String toJson(String name, List<Track> tracks) {
    return jsonEncode({
      'name': name,
      'tracks': tracks.map((track) => track.toJson()).toList(growable: false),
    });
  }

  static ({int durationSeconds, String artist, String title}) _parseExtInf(
    String payload,
  ) {
    final commaIndex = payload.indexOf(',');
    if (commaIndex < 0) {
      return (durationSeconds: 0, artist: '未知艺术家', title: payload.trim());
    }

    final durationText = payload.substring(0, commaIndex).trim();
    final duration = int.tryParse(durationText) ?? 0;
    final titlePart = payload.substring(commaIndex + 1).trim();

    final parsed = _splitArtistTitle(titlePart);
    return (
      durationSeconds: duration < 0 ? 0 : duration,
      artist: parsed.artist,
      title: parsed.title,
    );
  }

  static ({String artist, String title}) _fallbackFromLocation(
    String location,
  ) {
    final lastSegment = location.split(RegExp(r'[/\\]')).last;
    final dotIndex = lastSegment.lastIndexOf('.');
    final baseName = dotIndex > 0
        ? lastSegment.substring(0, dotIndex)
        : lastSegment;
    return _splitArtistTitle(baseName.isEmpty ? location : baseName);
  }

  static ({String artist, String title}) _splitArtistTitle(String raw) {
    final separatorIndex = raw.indexOf(' - ');
    if (separatorIndex > 0) {
      final artist = raw.substring(0, separatorIndex).trim();
      final title = raw.substring(separatorIndex + 3).trim();
      if (artist.isNotEmpty && title.isNotEmpty) {
        return (artist: artist, title: title);
      }
    }
    return (artist: '未知艺术家', title: raw.trim());
  }
}
