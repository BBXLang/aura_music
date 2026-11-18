import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/ohos_audio_bridge.dart';
import '../../core/models/track.dart';
import '../../core/state/player_provider.dart';
import '../../design_system/ambient_background.dart';
import '../../design_system/cover_art.dart';
import '../../design_system/morph_icon.dart';
import '../../design_system/particle_effects.dart';
import '../../design_system/squircle_border.dart';
import '../../design_system/windows_title_bar.dart';
import 'queue_sheet.dart';

/// Full-screen immersive player supporting mobile 2-slide Cover/Lyrics
/// navigation and desktop 2-column split layout.
class ImmersivePlayerPage extends ConsumerStatefulWidget {
  /// Creates an [ImmersivePlayerPage].
  const ImmersivePlayerPage({super.key});

  @override
  ConsumerState<ImmersivePlayerPage> createState() =>
      _ImmersivePlayerPageState();
}

class _ImmersivePlayerPageState extends ConsumerState<ImmersivePlayerPage> {
  final PageController _pageController = PageController();
  int _mobilePage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    setState(() => _mobilePage = index);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);
    final track = state.currentTrack;
    final colors =
        track?.colors ??
        const [Color(0xFF1E1B4B), Color(0xFF4338CA), Color(0xFF38BDF8)];
    final isDark = state.isDark;
    final primaryColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryColor = primaryColor.withValues(alpha: 0.66);
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;

    return AmbientBackground(
      colors: colors,
      enabled: state.ambientEnabled,
      isDark: isDark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              WindowsTitleBar(
                primaryColor: primaryColor,
                isDark: isDark,
                title: track?.title ?? 'AuraMusic',
              ),
              _buildTopBar(context, isDesktop, primaryColor, secondaryColor),
              Expanded(
                child: track == null
                    ? Center(
                        child: Text(
                          '暂无正在播放的歌曲',
                          style: TextStyle(color: secondaryColor),
                        ),
                      )
                    : isDesktop
                    ? _buildDesktopLayout(
                        context,
                        state,
                        notifier,
                        track,
                        primaryColor,
                        secondaryColor,
                      )
                    : PageView(
                        controller: _pageController,
                        onPageChanged: (index) =>
                            setState(() => _mobilePage = index),
                        children: [
                          _buildMobileCoverSlide(
                            context,
                            state,
                            notifier,
                            track,
                            primaryColor,
                            secondaryColor,
                          ),
                          _buildMobileLyricsSlide(
                            context,
                            state,
                            notifier,
                            track,
                            primaryColor,
                            secondaryColor,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    bool isDesktop,
    Color primaryColor,
    Color secondaryColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: '返回',
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 30,
              color: primaryColor,
            ),
          ),
          const Spacer(),
          if (!isDesktop)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PageIndicatorDot(
                  label: '封面',
                  active: _mobilePage == 0,
                  primaryColor: primaryColor,
                  onTap: () => _goToPage(0),
                ),
                const SizedBox(width: 8),
                _PageIndicatorDot(
                  label: '歌词',
                  active: _mobilePage == 1,
                  primaryColor: primaryColor,
                  onTap: () => _goToPage(1),
                ),
              ],
            ),
          const Spacer(),
          IconButton(
            tooltip: '播放队列',
            onPressed: () => showQueueSheet(context),
            icon: Icon(Icons.queue_music_rounded, color: primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCoverSlide(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
    Track track,
    Color primaryColor,
    Color secondaryColor,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final coverSize = (constraints.maxHeight * 0.34).clamp(150.0, 260.0);
        final haloSize = coverSize + 44;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 24).clamp(0.0, 2000.0),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: haloSize,
                  height: haloSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        width: coverSize + (state.isPlaying ? 28 : 14),
                        height: coverSize + (state.isPlaying ? 28 : 14),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              track.colors.last.withValues(alpha: 0.38),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      CoverParticleHalo(
                        isPlaying: state.isPlaying,
                        color: track.colors.last,
                        child: ProceduralCoverArt(
                          colors: track.colors,
                          size: coverSize,
                          radius: 28,
                          imageUrl: track.coverUrl,
                        ),
                      ),
                      Positioned(
                        bottom: 10,
                        child: GestureDetector(
                          onTap: () =>
                              _showQualitySheet(context, state, notifier),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.56),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.24),
                              ),
                            ),
                            child: Text(
                              state.quality.label,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${track.artist} · ${track.album}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: secondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: track.liked ? '取消红心' : '喜欢',
                      onPressed: notifier.toggleLike,
                      icon: MorphLikeIcon(
                        isLiked: track.liked,
                        size: 28,
                        unlikedColor: secondaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildProgressSection(
                  state,
                  notifier,
                  track,
                  primaryColor,
                  secondaryColor,
                ),
                const SizedBox(height: 12),
                _buildMainControls(context, state, notifier, primaryColor),
                const SizedBox(height: 12),
                _buildBottomUtilityBar(
                  context,
                  state,
                  notifier,
                  track,
                  primaryColor,
                  secondaryColor,
                  showLyricsSwitch: true,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileLyricsSlide(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
    Track track,
    Color primaryColor,
    Color secondaryColor,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 18),
      child: Column(
        children: [
          Row(
            children: [
              ProceduralCoverArt(
                colors: track.colors,
                size: 46,
                radius: 12,
                imageUrl: track.coverUrl,
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
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                    ),
                    Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: secondaryColor),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: track.liked ? '取消红心' : '喜欢',
                onPressed: notifier.toggleLike,
                icon: MorphLikeIcon(
                  isLiked: track.liked,
                  size: 24,
                  unlikedColor: secondaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _buildLyricsList(
              state,
              notifier,
              track,
              primaryColor,
              secondaryColor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: '上一首',
                onPressed: notifier.prevTrack,
                icon: Icon(
                  Icons.skip_previous_rounded,
                  size: 32,
                  color: primaryColor,
                ),
              ),
              _PlayPauseCircleButton(
                isPlaying: state.isPlaying,
                primaryColor: primaryColor,
                isDark: state.isDark,
                size: 54,
                onTap: notifier.togglePlay,
              ),
              IconButton(
                tooltip: '下一首',
                onPressed: notifier.nextTrack,
                icon: Icon(
                  Icons.skip_next_rounded,
                  size: 32,
                  color: primaryColor,
                ),
              ),
              IconButton(
                tooltip: '桌面歌词',
                onPressed: notifier.toggleDesktopLyrics,
                icon: Icon(
                  Icons.subtitles_rounded,
                  color: state.desktopLyrics
                      ? const Color(0xFF38BDF8)
                      : secondaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
    Track track,
    Color primaryColor,
    Color secondaryColor,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 12, 40, 28),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 280,
                    height: 280,
                    child: CoverParticleHalo(
                      isPlaying: state.isPlaying,
                      color: track.colors.last,
                      child: ProceduralCoverArt(
                        colors: track.colors,
                        size: 236,
                        radius: 30,
                        imageUrl: track.coverUrl,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: notifier.toggleLike,
                        icon: MorphLikeIcon(
                          isLiked: track.liked,
                          size: 26,
                          unlikedColor: secondaryColor,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${track.artist} · ${track.album}',
                    style: TextStyle(fontSize: 14, color: secondaryColor),
                  ),
                  const SizedBox(height: 18),
                  _buildProgressSection(
                    state,
                    notifier,
                    track,
                    primaryColor,
                    secondaryColor,
                  ),
                  const SizedBox(height: 12),
                  _buildMainControls(context, state, notifier, primaryColor),
                  const SizedBox(height: 10),
                  _buildBottomUtilityBar(
                    context,
                    state,
                    notifier,
                    track,
                    primaryColor,
                    secondaryColor,
                    showLyricsSwitch: false,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 40),
          Expanded(
            flex: 5,
            child: SquircleCard(
              radius: 28,
              padding: const EdgeInsets.all(24),
              child: _buildLyricsList(
                state,
                notifier,
                track,
                primaryColor,
                secondaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(
    PlayerState state,
    PlayerNotifier notifier,
    Track track,
    Color primaryColor,
    Color secondaryColor,
  ) {
    final elapsedSeconds = (track.durationSeconds * state.progress).round();
    return Column(
      children: [
        ConeProgressBar(
          progress: state.progress,
          onSeek: notifier.seek,
          accentColor: track.colors.last,
          isPlaying: state.isPlaying,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatSeconds(elapsedSeconds),
              style: TextStyle(fontSize: 11.5, color: secondaryColor),
            ),
            Text(
              track.formattedDuration,
              style: TextStyle(fontSize: 11.5, color: secondaryColor),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMainControls(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
    Color primaryColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          tooltip: state.playMode.label,
          onPressed: notifier.cyclePlayMode,
          icon: MorphModeIcon(
            mode: _modeKey(state.playMode),
            size: 24,
            color: primaryColor,
          ),
        ),
        IconButton(
          tooltip: '上一首',
          onPressed: notifier.prevTrack,
          icon: Icon(
            Icons.skip_previous_rounded,
            size: 38,
            color: primaryColor,
          ),
        ),
        _PlayPauseCircleButton(
          isPlaying: state.isPlaying,
          primaryColor: primaryColor,
          isDark: state.isDark,
          size: 66,
          onTap: notifier.togglePlay,
        ),
        IconButton(
          tooltip: '下一首',
          onPressed: notifier.nextTrack,
          icon: Icon(Icons.skip_next_rounded, size: 38, color: primaryColor),
        ),
        IconButton(
          tooltip: '队列',
          onPressed: () => showQueueSheet(context),
          icon: Icon(
            Icons.playlist_play_rounded,
            size: 28,
            color: primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomUtilityBar(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
    Track track,
    Color primaryColor,
    Color secondaryColor, {
    required bool showLyricsSwitch,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: () => _showQualitySheet(context, state, notifier),
          child: Text(
            state.quality.label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: primaryColor,
            ),
          ),
        ),
        IconButton(
          tooltip: '桌面歌词',
          onPressed: notifier.toggleDesktopLyrics,
          icon: Icon(
            Icons.subtitles_rounded,
            color: state.desktopLyrics
                ? const Color(0xFF38BDF8)
                : secondaryColor,
          ),
        ),
        if (showLyricsSwitch)
          TextButton.icon(
            onPressed: () => _goToPage(1),
            icon: Icon(Icons.lyrics_rounded, size: 18, color: primaryColor),
            label: Text(
              '歌词',
              style: TextStyle(fontSize: 12.5, color: primaryColor),
            ),
          ),
        IconButton(
          tooltip: '更多操作',
          onPressed: () =>
              _showMoreActionsDrawer(context, state, notifier, track),
          icon: Icon(Icons.more_horiz_rounded, color: primaryColor),
        ),
      ],
    );
  }

  Widget _buildLyricsList(
    PlayerState state,
    PlayerNotifier notifier,
    Track track,
    Color primaryColor,
    Color secondaryColor,
  ) {
    if (track.lyrics.isEmpty) {
      return Center(
        child: Text(
          '暂无歌词',
          style: TextStyle(fontFamily: 'HarmonyOS Sans', color: secondaryColor),
        ),
      );
    }

    return _AppleMusicLyricsView(
      trackId: track.id,
      lyrics: track.lyrics,
      activeLyric: state.activeLyric,
      lineProgress: state.lyricLineProgress,
      primaryColor: primaryColor,
      secondaryColor: secondaryColor,
      onJumpLyric: notifier.jumpLyric,
    );
  }

  void _showQualitySheet(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primaryColor = isDark ? Colors.white : const Color(0xFF0F172A);
        return Padding(
          padding: const EdgeInsets.all(12),
          child: SquircleCard(
            radius: 26,
            backgroundColor: isDark
                ? const Color(0xFF0F172A).withValues(alpha: 0.92)
                : Colors.white.withValues(alpha: 0.94),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '选择音质',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                for (final q in AudioQuality.values)
                  ListTile(
                    title: Text(q.label, style: TextStyle(color: primaryColor)),
                    trailing: state.quality == q
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF38BDF8),
                          )
                        : null,
                    onTap: () {
                      notifier.setQuality(q);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMoreActionsDrawer(
    BuildContext context,
    PlayerState state,
    PlayerNotifier notifier,
    Track track,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primaryColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final items = [
          (
            icon: Icons.high_quality_rounded,
            label: '音质',
            onTap: () {
              Navigator.of(sheetContext).pop();
              _showQualitySheet(context, state, notifier);
            },
          ),
          (
            icon: Icons.subtitles_rounded,
            label: '桌面歌词',
            onTap: () {
              notifier.toggleDesktopLyrics();
              Navigator.of(sheetContext).pop();
            },
          ),
          (
            icon: Icons.graphic_eq_rounded,
            label: '音效',
            onTap: () {
              Navigator.of(sheetContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已开启 AudioVivid 空间全景音效')),
              );
            },
          ),
          (
            icon: Icons.timer_outlined,
            label: '定时关闭',
            onTap: () {
              Navigator.of(sheetContext).pop();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('定时关闭已设为 30 分钟')));
            },
          ),
          (
            icon: Icons.playlist_add_rounded,
            label: '收藏到歌单',
            onTap: () {
              Navigator.of(sheetContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已将「${track.title}」加入红心收藏')),
              );
            },
          ),
          (
            icon: Icons.share_rounded,
            label: '分享',
            onTap: () {
              Navigator.of(sheetContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已生成「${track.title}」分享卡片')),
              );
            },
          ),
          (
            icon: Icons.reorder_rounded,
            label: '队列排序',
            onTap: () {
              Navigator.of(sheetContext).pop();
              showQueueSheet(context);
            },
          ),
          (
            icon: Icons.info_outline_rounded,
            label: '歌曲信息',
            onTap: () {
              Navigator.of(sheetContext).pop();
              showDialog<void>(
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
            },
          ),
        ];

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: SquircleCard(
            radius: 28,
            backgroundColor: isDark
                ? const Color(0xFF0F172A).withValues(alpha: 0.92)
                : Colors.white.withValues(alpha: 0.94),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '更多功能',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.95,
                  ),
                  itemBuilder: (context, index) {
                    final action = items[index];
                    return InkWell(
                      onTap: action.onTap,
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(action.icon, color: primaryColor),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            action.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _modeKey(PlayMode mode) {
    return switch (mode) {
      PlayMode.loopList => 'loop_list',
      PlayMode.loopOne => 'loop_one',
      PlayMode.playOnce => 'play_once',
    };
  }

  String _formatSeconds(int totalSeconds) {
    final safe = totalSeconds < 0 ? 0 : totalSeconds;
    final mins = (safe ~/ 60).toString().padLeft(2, '0');
    final secs = (safe % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }
}

class _PageIndicatorDot extends StatelessWidget {
  const _PageIndicatorDot({
    required this.label,
    required this.active,
    required this.primaryColor,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color primaryColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: EdgeInsets.symmetric(horizontal: active ? 12 : 8, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? primaryColor.withValues(alpha: 0.18)
              : primaryColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? primaryColor : primaryColor.withValues(alpha: 0.54),
          ),
        ),
      ),
    );
  }
}

class _PlayPauseCircleButton extends StatelessWidget {
  const _PlayPauseCircleButton({
    required this.isPlaying,
    required this.primaryColor,
    required this.isDark,
    required this.size,
    required this.onTap,
  });

  final bool isPlaying;
  final Color primaryColor;
  final bool isDark;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: primaryColor),
        child: Center(
          child: MorphPlayPauseIcon(
            isPlaying: isPlaying,
            size: size * 0.48,
            color: isDark ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _AppleMusicLyricsView extends StatefulWidget {
  const _AppleMusicLyricsView({
    required this.trackId,
    required this.lyrics,
    required this.activeLyric,
    required this.lineProgress,
    required this.primaryColor,
    required this.secondaryColor,
    required this.onJumpLyric,
  });

  final String trackId;
  final List<String> lyrics;
  final int activeLyric;
  final double lineProgress;
  final Color primaryColor;
  final Color secondaryColor;
  final ValueChanged<int> onJumpLyric;

  @override
  State<_AppleMusicLyricsView> createState() => _AppleMusicLyricsViewState();
}

class _AppleMusicLyricsViewState extends State<_AppleMusicLyricsView> {
  final ScrollController _scrollController = ScrollController();
  late List<GlobalKey> _lineKeys;
  DateTime? _lastUserInteraction;

  @override
  void initState() {
    super.initState();
    _lineKeys = List.generate(widget.lyrics.length, (_) => GlobalKey());
    _scheduleScrollToActive(immediate: true);
  }

  @override
  void didUpdateWidget(_AppleMusicLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lyrics.length != widget.lyrics.length ||
        oldWidget.trackId != widget.trackId) {
      _lineKeys = List.generate(widget.lyrics.length, (_) => GlobalKey());
    }
    if (oldWidget.activeLyric != widget.activeLyric ||
        oldWidget.trackId != widget.trackId) {
      _scheduleScrollToActive(immediate: oldWidget.trackId != widget.trackId);
    }
  }

  void _scheduleScrollToActive({bool immediate = false}) {
    final userPaused =
        _lastUserInteraction != null &&
        DateTime.now().difference(_lastUserInteraction!) <
            const Duration(milliseconds: 2500);
    if (userPaused && !immediate) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          widget.activeLyric < 0 ||
          widget.activeLyric >= _lineKeys.length) {
        return;
      }
      final ctx = _lineKeys[widget.activeLyric].currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.36,
        duration: immediate
            ? const Duration(milliseconds: 180)
            : const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollStartNotification>(
      onNotification: (notification) {
        if (notification.dragDetails != null) {
          _lastUserInteraction = DateTime.now();
        }
        return false;
      },
      child: ShaderMask(
        shaderCallback: (rect) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black,
              Colors.black,
              Colors.transparent,
            ],
            stops: [0.0, 0.04, 0.97, 1.0],
          ).createShader(rect);
        },
        blendMode: BlendMode.dstIn,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.only(
            top: 48,
            bottom: 28,
            left: 6,
            right: 6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < widget.lyrics.length; index++)
                _buildLine(index),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLine(int index) {
    final dist = (index - widget.activeLyric).abs();
    final isActive = dist == 0;
    final opacity = dist == 0
        ? 1.0
        : (dist == 1 ? 0.58 : (dist == 2 ? 0.38 : 0.22));
    final scale = isActive ? 1.04 : 0.96;

    Widget textWidget;
    if (isActive) {
      final targetProgress = widget.lineProgress.clamp(0.0, 1.0);
      textWidget = TweenAnimationBuilder<double>(
        key: ValueKey('active_lyric_${widget.trackId}_$index'),
        tween: Tween<double>(begin: 0.0, end: targetProgress),
        duration: const Duration(milliseconds: 220),
        curve: Curves.linear,
        builder: (context, p, child) {
          final pTail = (p + 0.06).clamp(0.0, 1.0);
          return ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                colors: [
                  widget.primaryColor,
                  widget.primaryColor,
                  widget.primaryColor.withValues(alpha: 0.42),
                  widget.primaryColor.withValues(alpha: 0.42),
                ],
                stops: [0.0, p, pTail, 1.0],
              ).createShader(bounds);
            },
            blendMode: BlendMode.srcIn,
            child: child,
          );
        },
        child: Text(
          widget.lyrics[index],
          style: TextStyle(
            fontFamily: 'HarmonyOS Sans',
            fontSize: 23,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.42,
            shadows: [
              Shadow(
                color: widget.primaryColor.withValues(alpha: 0.28),
                blurRadius: 14,
              ),
            ],
          ),
        ),
      );
    } else {
      textWidget = Text(
        widget.lyrics[index],
        style: TextStyle(
          fontFamily: 'HarmonyOS Sans',
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: widget.secondaryColor,
          height: 1.42,
        ),
      );
    }

    return RepaintBoundary(
      child: Padding(
        key: _lineKeys[index],
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _lastUserInteraction = null;
            widget.onJumpLyric(index);
          },
          child: AnimatedScale(
            scale: scale,
            alignment: Alignment.centerLeft,
            duration: const Duration(milliseconds: 340),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: opacity,
              duration: const Duration(milliseconds: 280),
              child: textWidget,
            ),
          ),
        ),
      ),
    );
  }
}
