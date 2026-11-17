import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/playlist.dart';
import '../../core/models/track.dart';
import '../../core/playlist/playlist_codec.dart';
import '../../core/state/player_provider.dart';
import '../../design_system/cover_art.dart';
import '../../design_system/squircle_border.dart';
import '../player/queue_sheet.dart';

/// Home discovery page featuring 最近热播 carousel and 我的歌单 grid.
class HomePage extends ConsumerWidget {
  /// Creates a [HomePage].
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryColor = primaryColor.withValues(alpha: 0.65);
    final topTracks = state.tracks.take(10).toList(growable: false);
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 900 ? 3 : 2;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      children: [
        _buildHotHeader(context, primaryColor, isDark),
        const SizedBox(height: 14),
        SizedBox(
          height: 192,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: topTracks.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final track = topTracks[index];
              final isCurrent = state.currentTrackId == track.id;
              return _HotTrackCard(
                track: track,
                isCurrent: isCurrent,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                onTap: () => notifier.playTrack(track.id),
              );
            },
          ),
        ),
        const SizedBox(height: 28),
        _buildPlaylistHeader(context, notifier, primaryColor, isDark),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: state.playlists.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.05,
          ),
          itemBuilder: (context, index) {
            final playlist = state.playlists[index];
            return _PlaylistCard(
              playlist: playlist,
              tracks: state.tracks,
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
              onTap: () => _showPlaylistSheet(context, playlist),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHotHeader(
    BuildContext context,
    Color primaryColor,
    bool isDark,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '最近热播',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: primaryColor,
              letterSpacing: -0.3,
            ),
          ),
        ),
        _HeaderActionButton(
          icon: Icons.history_rounded,
          label: '播放历史',
          primaryColor: primaryColor,
          isDark: isDark,
          onTap: () => showQueueSheet(context, initialTab: 1),
        ),
        const SizedBox(width: 8),
        _HeaderActionButton(
          icon: Icons.leaderboard_rounded,
          label: 'Top 100',
          primaryColor: primaryColor,
          isDark: isDark,
          onTap: () => _showTop100Sheet(context),
        ),
      ],
    );
  }

  Widget _buildPlaylistHeader(
    BuildContext context,
    PlayerNotifier notifier,
    Color primaryColor,
    bool isDark,
  ) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        Text(
          '我的歌单',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: primaryColor,
            letterSpacing: -0.3,
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _HeaderActionButton(
              icon: Icons.radar_rounded,
              label: '扫描本地',
              primaryColor: primaryColor,
              isDark: isDark,
              onTap: () => _showScanLocalDialog(context, notifier),
            ),
            _HeaderActionButton(
              icon: Icons.file_download_outlined,
              label: '导入',
              primaryColor: primaryColor,
              isDark: isDark,
              onTap: () => _showImportDialog(context, notifier),
            ),
            _HeaderActionButton(
              icon: Icons.add_rounded,
              label: '+ 新建',
              primaryColor: primaryColor,
              isDark: isDark,
              onTap: () => _showCreateDialog(context, notifier),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showCreateDialog(
    BuildContext context,
    PlayerNotifier notifier,
  ) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('新建歌单'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '输入歌单名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.isNotEmpty) {
      notifier.createPlaylist(name);
    }
  }

  Future<void> _showScanLocalDialog(
    BuildContext context,
    PlayerNotifier notifier,
  ) async {
    final controller = TextEditingController();
    final customPath = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('扫描本地音乐'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('默认扫描系统 Music 与 Downloads 目录，也可指定自定义目录：'),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: '可选：输入自定义目录路径',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(''),
            child: const Text('扫描默认目录'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('扫描指定目录'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (customPath == null) return;

    final dirs = customPath.isEmpty ? null : <String>[customPath];
    final count = await notifier.scanLocalMusicReal(directories: dirs);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('本地扫描完成，发现 $count 首音频曲目')));
  }

  Future<void> _showImportDialog(
    BuildContext context,
    PlayerNotifier notifier,
  ) async {
    final controller = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('导入 M3U / JSON 歌单'),
        content: TextField(
          controller: controller,
          maxLines: 6,
          minLines: 4,
          decoration: const InputDecoration(
            hintText:
                '#EXTM3U\n#PLAYLIST:深夜精选\n#EXTINF:240,Artist - Title\n...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('导入'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (raw == null || raw.isEmpty) return;

    final ok = await notifier.importPlaylistRaw(raw);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '歌单导入成功' : '导入失败：请检查 M3U 或 JSON 格式')),
    );
  }

  void _showTop100Sheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _Top100Sheet(),
    );
  }

  void _showPlaylistSheet(BuildContext context, Playlist playlist) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlaylistDetailSheet(playlistId: playlist.id),
    );
  }
}

class _HotTrackCard extends StatelessWidget {
  const _HotTrackCard({
    required this.track,
    required this.isCurrent,
    required this.primaryColor,
    required this.secondaryColor,
    required this.onTap,
  });

  final Track track;
  final bool isCurrent;
  final Color primaryColor;
  final Color secondaryColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 136,
        child: SquircleCard(
          radius: 22,
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ProceduralCoverArt(
                    colors: track.colors,
                    size: 116,
                    radius: 16,
                  ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.52),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        track.quality,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isCurrent ? const Color(0xFF38BDF8) : primaryColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: secondaryColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({
    required this.playlist,
    required this.tracks,
    required this.primaryColor,
    required this.secondaryColor,
    required this.onTap,
  });

  final Playlist playlist;
  final List<Track> tracks;
  final Color primaryColor;
  final Color secondaryColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final coverColors = _resolveCoverColors();
    final typeLabel = switch (playlist.type) {
      PlaylistType.local => '本地无损',
      PlaylistType.user => '自建歌单',
      PlaylistType.imported => '已导入',
    };

    return GestureDetector(
      onTap: onTap,
      child: SquircleCard(
        radius: 22,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProceduralCoverArt(colors: coverColors, size: 52, radius: 14),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: secondaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              playlist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${playlist.trackIds.length} 首歌曲',
              style: TextStyle(fontSize: 12, color: secondaryColor),
            ),
          ],
        ),
      ),
    );
  }

  List<Color> _resolveCoverColors() {
    if (playlist.trackIds.isNotEmpty) {
      final firstId = playlist.trackIds.first;
      for (final track in tracks) {
        if (track.id == firstId) return track.colors;
      }
    }
    return const [Color(0xFF4F46E5), Color(0xFF06B6D4), Color(0xFFEC4899)];
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.icon,
    required this.label,
    required this.primaryColor,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color primaryColor;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: isDark ? 0.1 : 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: primaryColor.withValues(alpha: 0.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: primaryColor),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Top100Sheet extends ConsumerWidget {
  const _Top100Sheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryColor = primaryColor.withValues(alpha: 0.64);
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.72;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: SizedBox(
        height: sheetHeight,
        child: SquircleCard(
          radius: 28,
          blurSigma: 32,
          backgroundColor: isDark
              ? const Color(0xFF0F172A).withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: 0.94),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'AuraMusic Top 100',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      notifier.replaceQueue(
                        'Top 100 榜单',
                        state.tracks.map((t) => t.id).toList(growable: false),
                      );
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('全部播放'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: state.tracks.length,
                  itemBuilder: (context, index) {
                    final track = state.tracks[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      onTap: () => notifier.playTrack(track.id),
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text(
                              '${index + 1}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: index < 3
                                    ? const Color(0xFF38BDF8)
                                    : secondaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ProceduralCoverArt(
                            colors: track.colors,
                            size: 40,
                            radius: 10,
                          ),
                        ],
                      ),
                      title: Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${track.artist} · ${track.quality}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: secondaryColor, fontSize: 12),
                      ),
                      trailing: Text(
                        track.formattedDuration,
                        style: TextStyle(color: secondaryColor, fontSize: 12),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistDetailSheet extends ConsumerWidget {
  const _PlaylistDetailSheet({required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);
    final playlist = state.playlists.firstWhere(
      (pl) => pl.id == playlistId,
      orElse: () => const Playlist(
        id: '',
        name: '歌单',
        type: PlaylistType.user,
        trackIds: [],
      ),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryColor = primaryColor.withValues(alpha: 0.64);
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.72;
    final playlistTracks = playlist.trackIds
        .map((id) => state.tracks.where((t) => t.id == id).firstOrNull)
        .whereType<Track>()
        .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: SizedBox(
        height: sheetHeight,
        child: SquircleCard(
          radius: 28,
          blurSigma: 32,
          backgroundColor: isDark
              ? const Color(0xFF0F172A).withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: 0.94),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playlist.name,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${playlistTracks.length} 首曲目',
                          style: TextStyle(color: secondaryColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: playlistTracks.isEmpty
                            ? null
                            : () async {
                                final m3u = PlaylistCodec.toM3u(
                                  playlist.name,
                                  playlistTracks,
                                );
                                await Clipboard.setData(
                                  ClipboardData(text: m3u),
                                );
                                if (!context.mounted) return;
                                await showDialog<void>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: Text('导出 M3U · ${playlist.name}'),
                                    content: SingleChildScrollView(
                                      child: SelectableText(m3u),
                                    ),
                                    actions: [
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.of(dialogContext).pop(),
                                        child: const Text('已复制并关闭'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                        icon: const Icon(Icons.file_upload_outlined, size: 16),
                        label: const Text('导出 M3U'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('已复制歌单「${playlist.name}」分享链接'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.share_rounded, size: 16),
                        label: const Text('分享'),
                      ),
                      FilledButton.icon(
                        onPressed: playlist.trackIds.isEmpty
                            ? null
                            : () {
                                notifier.replaceQueue(
                                  playlist.name,
                                  playlist.trackIds,
                                );
                                Navigator.of(context).pop();
                              },
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('全部播放'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: playlistTracks.isEmpty
                    ? Center(
                        child: Text(
                          '歌单暂无曲目',
                          style: TextStyle(color: secondaryColor),
                        ),
                      )
                    : ListView.builder(
                        itemCount: playlistTracks.length,
                        itemBuilder: (context, index) {
                          final track = playlistTracks[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            onTap: () {
                              notifier.replaceQueue(
                                playlist.name,
                                playlist.trackIds,
                                startPos: index,
                              );
                            },
                            leading: ProceduralCoverArt(
                              colors: track.colors,
                              size: 42,
                              radius: 11,
                            ),
                            title: Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${track.artist} · ${track.quality}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: secondaryColor,
                                fontSize: 12,
                              ),
                            ),
                            trailing: Text(
                              track.formattedDuration,
                              style: TextStyle(
                                color: secondaryColor,
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
