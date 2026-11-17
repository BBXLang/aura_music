import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/ohos_audio_bridge.dart';
import '../../core/models/track.dart';
import '../../core/state/player_provider.dart';
import '../../design_system/cover_art.dart';
import '../../design_system/squircle_border.dart';

/// Displays the modal bottom sheet for the active playback queue and history.
Future<void> showQueueSheet(BuildContext context, {int initialTab = 0}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _QueueSheet(initialTab: initialTab),
  );
}

class _QueueSheet extends ConsumerStatefulWidget {
  const _QueueSheet({required this.initialTab});

  final int initialTab;

  @override
  ConsumerState<_QueueSheet> createState() => _QueueSheetState();
}

class _QueueSheetState extends ConsumerState<_QueueSheet> {
  late int _tabIndex;

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTab.clamp(0, 1);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryColor = primaryColor.withValues(alpha: 0.64);
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.74;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: SizedBox(
        height: sheetHeight,
        child: SquircleCard(
          radius: 28,
          blurSigma: 32,
          backgroundColor: isDark
              ? const Color(0xFF0F172A).withValues(alpha: 0.88)
              : Colors.white.withValues(alpha: 0.92),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _buildHeader(state, notifier, primaryColor, isDark),
              if (state.recentQueues.isNotEmpty && _tabIndex == 0) ...[
                const SizedBox(height: 12),
                _buildRecentQueuesRow(state, notifier, primaryColor, isDark),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: _tabIndex == 0
                    ? _buildCurrentQueueList(
                        state,
                        notifier,
                        primaryColor,
                        secondaryColor,
                      )
                    : _buildHistoryList(
                        state,
                        notifier,
                        primaryColor,
                        secondaryColor,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    PlayerState state,
    PlayerNotifier notifier,
    Color primaryColor,
    bool isDark,
  ) {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _SheetTabChip(
                  label: '${state.queueName} (${state.queue.length})',
                  selected: _tabIndex == 0,
                  primaryColor: primaryColor,
                  isDark: isDark,
                  onTap: () => setState(() => _tabIndex = 0),
                ),
                const SizedBox(width: 8),
                _SheetTabChip(
                  label: '播放历史 (${state.playHistory.length})',
                  selected: _tabIndex == 1,
                  primaryColor: primaryColor,
                  isDark: isDark,
                  onTap: () => setState(() => _tabIndex = 1),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: notifier.cyclePlayMode,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: primaryColor.withValues(alpha: 0.16)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _playModeIcon(state.playMode),
                  size: 16,
                  color: primaryColor,
                ),
                const SizedBox(width: 6),
                Text(
                  state.playMode.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentQueuesRow(
    PlayerState state,
    PlayerNotifier notifier,
    Color primaryColor,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '最近列表',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: primaryColor.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: state.recentQueues.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final snapshot = state.recentQueues[index];
              return ActionChip(
                label: Text(
                  '${snapshot.name} (${snapshot.trackIds.length})',
                  style: TextStyle(fontSize: 12, color: primaryColor),
                ),
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
                side: BorderSide(color: primaryColor.withValues(alpha: 0.14)),
                onPressed: () => notifier.switchRecentQueue(index),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentQueueList(
    PlayerState state,
    PlayerNotifier notifier,
    Color primaryColor,
    Color secondaryColor,
  ) {
    if (state.queue.isEmpty) {
      return Center(
        child: Text(
          '当前播放队列为空',
          style: TextStyle(color: secondaryColor, fontSize: 14),
        ),
      );
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      itemCount: state.queue.length,
      onReorder: (oldIndex, newIndex) {
        final adjusted = newIndex > oldIndex ? newIndex - 1 : newIndex;
        notifier.reorderQueue(oldIndex, adjusted);
      },
      itemBuilder: (context, index) {
        final trackId = state.queue[index];
        final track = _findTrack(state.tracks, trackId);
        if (track == null) {
          return SizedBox.shrink(key: ValueKey('missing_${trackId}_$index'));
        }
        final isActive = index == state.queuePos;

        return Material(
          key: ValueKey('queue_${track.id}_$index'),
          color: Colors.transparent,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            onTap: () => notifier.playTrack(track.id),
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.drag_handle_rounded,
                      size: 20,
                      color: secondaryColor,
                    ),
                  ),
                ),
                ProceduralCoverArt(colors: track.colors, size: 42, radius: 11),
              ],
            ),
            title: Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? const Color(0xFF38BDF8) : primaryColor,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              '${track.artist} · ${track.quality}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: secondaryColor, fontSize: 12),
            ),
            trailing: IconButton(
              tooltip: '移除',
              icon: Icon(Icons.close_rounded, size: 18, color: secondaryColor),
              onPressed: () => notifier.removeFromQueue(index),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryList(
    PlayerState state,
    PlayerNotifier notifier,
    Color primaryColor,
    Color secondaryColor,
  ) {
    if (state.playHistory.isEmpty) {
      return Center(
        child: Text(
          '暂无播放历史，点击任意歌曲开始聆听',
          style: TextStyle(color: secondaryColor, fontSize: 14),
        ),
      );
    }

    return ListView.separated(
      itemCount: state.playHistory.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final entry = state.playHistory[index];
        final track = _findTrack(state.tracks, entry.trackId);
        if (track == null) return const SizedBox.shrink();

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          onTap: () => notifier.playTrack(track.id),
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
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            track.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: secondaryColor, fontSize: 12),
          ),
          trailing: Text(
            entry.timestampLabel,
            style: TextStyle(color: secondaryColor, fontSize: 12),
          ),
        );
      },
    );
  }

  Track? _findTrack(List<Track> tracks, String id) {
    for (final track in tracks) {
      if (track.id == id) return track;
    }
    return null;
  }

  IconData _playModeIcon(PlayMode mode) {
    return switch (mode) {
      PlayMode.loopList => Icons.repeat_rounded,
      PlayMode.loopOne => Icons.repeat_one_rounded,
      PlayMode.playOnce => Icons.arrow_right_alt_rounded,
    };
  }
}

class _SheetTabChip extends StatelessWidget {
  const _SheetTabChip({
    required this.label,
    required this.selected,
    required this.primaryColor,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color primaryColor;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? primaryColor
              : primaryColor.withValues(alpha: isDark ? 0.1 : 0.06),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected
                ? (isDark ? Colors.black : Colors.white)
                : primaryColor,
          ),
        ),
      ),
    );
  }
}
