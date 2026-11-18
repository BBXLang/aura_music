import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/player_provider.dart';
import '../../design_system/cover_art.dart';
import '../../design_system/squircle_border.dart';

/// Live search page filtering tracks by title or artist.
class SearchPage extends ConsumerStatefulWidget {
  /// Creates a [SearchPage].
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryColor = primaryColor.withValues(alpha: 0.64);

    final normalized = _query.trim().toLowerCase();
    final filtered = normalized.isEmpty
        ? state.tracks
        : state.tracks
              .where(
                (t) =>
                    t.title.toLowerCase().contains(normalized) ||
                    t.artist.toLowerCase().contains(normalized),
              )
              .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        children: [
          SquircleCard(
            radius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: TextField(
              controller: _controller,
              onChanged: (value) => setState(() => _query = value),
              onSubmitted: (value) => notifier.searchSidecar(value),
              style: TextStyle(color: primaryColor, fontSize: 15),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: '搜索歌曲、歌手…',
                hintStyle: TextStyle(color: secondaryColor),
                icon: Icon(Icons.search_rounded, color: secondaryColor),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清空',
                        icon: Icon(Icons.close_rounded, color: secondaryColor),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      '未找到与「$_query」相关的曲目',
                      style: TextStyle(color: secondaryColor, fontSize: 14),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 120),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final track = filtered[index];
                      final isCurrent = state.currentTrackId == track.id;

                      return GestureDetector(
                        onTap: () {
                          if (track.sourceId == 'huawei' &&
                              track.streamUrl == null) {
                            notifier.playSidecarTrack(track);
                          } else {
                            notifier.playTrack(track.id);
                          }
                        },
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
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
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
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  track.quality,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
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
}
