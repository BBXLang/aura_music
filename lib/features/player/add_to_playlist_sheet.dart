import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/track.dart';
import '../../core/state/player_provider.dart';
import '../../design_system/cover_art.dart';
import '../../design_system/squircle_border.dart';

/// Opens a bottom sheet letting the user pick which playlist to add [track] into.
Future<void> showAddToPlaylistSheet(BuildContext context, Track track) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddToPlaylistSheet(track: track),
  );
}

class _AddToPlaylistSheet extends ConsumerWidget {
  const _AddToPlaylistSheet({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryColor = primaryColor.withValues(alpha: 0.64);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.62;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SquircleCard(
          radius: 28,
          blurSigma: 32,
          backgroundColor: isDark
              ? const Color(0xFF0F172A).withValues(alpha: 0.92)
              : Colors.white.withValues(alpha: 0.95),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ProceduralCoverArt(
                    colors: track.colors,
                    size: 40,
                    radius: 10,
                    imageUrl: track.coverUrl,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '收藏到歌单',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: primaryColor,
                          ),
                        ),
                        Text(
                          '${track.title} · ${track.artist}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: secondaryColor),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        _createAndAddPlaylist(context, ref, notifier),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('新建歌单'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Flexible(
                child: state.playlists.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          child: Text(
                            '暂无歌单，请先点击右上角新建歌单',
                            style: TextStyle(color: secondaryColor),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: state.playlists.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: primaryColor.withValues(alpha: 0.08),
                        ),
                        itemBuilder: (context, index) {
                          final playlist = state.playlists[index];
                          final alreadyAdded = playlist.trackIds.contains(
                            track.id,
                          );
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            leading: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.queue_music_rounded,
                                color: primaryColor,
                              ),
                            ),
                            title: Text(
                              playlist.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${playlist.trackIds.length} 首曲目',
                              style: TextStyle(
                                color: secondaryColor,
                                fontSize: 12,
                              ),
                            ),
                            trailing: alreadyAdded
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF10B981),
                                    size: 20,
                                  )
                                : Icon(
                                    Icons.add_circle_outline_rounded,
                                    color: secondaryColor,
                                    size: 20,
                                  ),
                            onTap: () {
                              final added = notifier.addTrackToPlaylist(
                                playlist.id,
                                track,
                              );
                              final messenger = ScaffoldMessenger.maybeOf(
                                context,
                              );
                              Navigator.of(context).pop();
                              messenger?.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    added
                                        ? '已将「${track.title}」添加到「${playlist.name}」'
                                        : '「${track.title}」已在「${playlist.name}」中',
                                  ),
                                ),
                              );
                            },
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

  Future<void> _createAndAddPlaylist(
    BuildContext context,
    WidgetRef ref,
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
            child: const Text('创建并收藏'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !context.mounted) return;

    notifier.createPlaylist(name);
    final updatedPlaylists = ref.read(playerProvider).playlists;
    if (updatedPlaylists.isNotEmpty) {
      notifier.addTrackToPlaylist(updatedPlaylists.last.id, track);
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.of(context).pop();
    messenger?.showSnackBar(
      SnackBar(content: Text('已创建歌单「$name」并收藏「${track.title}」')),
    );
  }
}
