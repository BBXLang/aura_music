import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/track.dart';
import '../../core/state/player_provider.dart';
import '../../design_system/cover_art.dart';
import '../../design_system/squircle_border.dart';
import '../player/add_to_playlist_sheet.dart';

/// Live search page filtering local library and querying Sidecar online catalogs.
class SearchPage extends ConsumerStatefulWidget {
  /// Creates a [SearchPage].
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String _activeSidecarQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runSidecarSearch(PlayerNotifier notifier, String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;
    await notifier.searchSidecar(trimmed);
    if (mounted && _query.trim() == trimmed) {
      setState(() => _activeSidecarQuery = trimmed);
    }
  }

  void _playImmediate(PlayerNotifier notifier, Track track) {
    if (track.sourceId == 'huawei' &&
        (track.streamUrl == null || track.streamUrl!.isEmpty)) {
      notifier.playSidecarTrack(track);
    } else {
      notifier.playTrack(track.id);
    }
  }

  List<Track> _resolveDisplayedTracks(
    List<Track> searchResults,
    List<Track> tracks,
  ) {
    final normalized = _query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return searchResults;
    }

    final localMatches = tracks
        .where(
          (t) =>
              t.title.toLowerCase().contains(normalized) ||
              t.artist.toLowerCase().contains(normalized),
        )
        .toList(growable: false);

    if (_query.trim() == _activeSidecarQuery && searchResults.isNotEmpty) {
      final seen = <String>{};
      final combined = <Track>[];
      for (final track in [...searchResults, ...localMatches]) {
        if (seen.add(track.id)) {
          combined.add(track);
        }
      }
      return combined;
    }

    return localMatches;
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(
      playerProvider.select((s) => s.searchResults),
    );
    final tracks = ref.watch(playerProvider.select((s) => s.tracks));
    final currentTrackId = ref.watch(
      playerProvider.select((s) => s.currentTrackId),
    );
    final notifier = ref.read(playerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryColor = primaryColor.withValues(alpha: 0.64);
    final displayed = _resolveDisplayedTracks(searchResults, tracks);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        children: [
          SquircleCard(
            radius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            child: SizedBox(
              height: 44,
              child: Center(
                child: TextField(
                  controller: _controller,
                  textAlignVertical: TextAlignVertical.center,
                  onChanged: (value) {
                    setState(() => _query = value);
                    _debounce?.cancel();
                    if (value.trim().isNotEmpty) {
                      _debounce = Timer(
                        const Duration(milliseconds: 400),
                        () => _runSidecarSearch(notifier, value),
                      );
                    }
                  },
                  onSubmitted: (value) {
                    _debounce?.cancel();
                    _runSidecarSearch(notifier, value);
                  },
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 15,
                    height: 1.2,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    hintText: '搜索歌曲、歌手…',
                    hintStyle: TextStyle(color: secondaryColor, height: 1.2),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: secondaryColor,
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清空',
                            icon: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: secondaryColor,
                            ),
                            onPressed: () {
                              _controller.clear();
                              setState(() {
                                _query = '';
                                _activeSidecarQuery = '';
                              });
                            },
                          ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: displayed.isEmpty
                ? Center(
                    child: Text(
                      _query.trim().isEmpty
                          ? '输入歌名或歌手开始搜索'
                          : '未找到与「$_query」相关的曲目',
                      style: TextStyle(color: secondaryColor, fontSize: 14),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 120),
                    itemCount: displayed.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final track = displayed[index];
                      final isCurrent = currentTrackId == track.id;

                      return GestureDetector(
                        onTap: () => _playImmediate(notifier, track),
                        child: SquircleCard(
                          radius: 18,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              ProceduralCoverArt(
                                colors: track.colors,
                                size: 48,
                                radius: 13,
                                imageUrl: track.coverUrl,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          flex: 3,
                                          child: Text(
                                            track.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: isCurrent
                                                  ? const Color(0xFF38BDF8)
                                                  : primaryColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          flex: 2,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: primaryColor.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              track.quality,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                                color: primaryColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      track.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: secondaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                tooltip: '立即播放',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 32,
                                  height: 32,
                                ),
                                onPressed: () =>
                                    _playImmediate(notifier, track),
                                icon: Icon(
                                  Icons.play_arrow_rounded,
                                  size: 21,
                                  color: primaryColor,
                                ),
                              ),
                              IconButton(
                                tooltip: '下一首播放',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 32,
                                  height: 32,
                                ),
                                onPressed: () {
                                  notifier.playNextInQueue(track);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '已将「${track.title}」设为下一首播放',
                                      ),
                                    ),
                                  );
                                },
                                icon: Icon(
                                  Icons.queue_play_next_rounded,
                                  size: 18,
                                  color: secondaryColor,
                                ),
                              ),
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: PopupMenuButton<String>(
                                  tooltip: '菜单',
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    Icons.more_vert_rounded,
                                    size: 19,
                                    color: secondaryColor,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  onSelected: (action) => _handleMenuAction(
                                    context,
                                    notifier,
                                    track,
                                    action,
                                  ),
                                  itemBuilder: (_) => [
                                    PopupMenuItem<String>(
                                      value: 'like',
                                      child: Row(
                                        children: [
                                          Icon(
                                            track.liked
                                                ? Icons.favorite_rounded
                                                : Icons.favorite_border_rounded,
                                            size: 18,
                                            color: track.liked
                                                ? const Color(0xFFFF3B5C)
                                                : null,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(track.liked ? '取消喜欢' : '喜欢'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'share',
                                      child: Row(
                                        children: [
                                          Icon(Icons.share_rounded, size: 18),
                                          SizedBox(width: 10),
                                          Text('分享'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'collect',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.playlist_add_rounded,
                                            size: 18,
                                          ),
                                          SizedBox(width: 10),
                                          Text('收藏'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'info',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline_rounded,
                                            size: 18,
                                          ),
                                          SizedBox(width: 10),
                                          Text('歌曲信息'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                track.formattedDuration,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: secondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMenuAction(
    BuildContext context,
    PlayerNotifier notifier,
    Track track,
    String action,
  ) async {
    switch (action) {
      case 'like':
        notifier.toggleTrackLike(track.id);
        break;
      case 'share':
        await Clipboard.setData(
          ClipboardData(text: '${track.title} - ${track.artist}'),
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已复制「${track.title}」分享信息')));
        break;
      case 'collect':
        await showAddToPlaylistSheet(context, track);
        break;
      case 'info':
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(track.title),
            content: Text(
              '歌手：${track.artist}\n专辑：${track.album}\n音质：${track.quality}\n时长：${track.formattedDuration}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('关闭'),
              ),
            ],
          ),
        );
        break;
    }
  }
}
