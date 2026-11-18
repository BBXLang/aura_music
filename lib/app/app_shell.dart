import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/state/player_provider.dart';
import '../design_system/ambient_background.dart';
import '../design_system/cover_art.dart';
import '../design_system/liquid_dock.dart';
import '../design_system/lite_music_logo.dart';
import '../design_system/squircle_border.dart';
import '../design_system/windows_title_bar.dart';
import '../features/home/home_page.dart';
import '../features/player/desktop_lyrics_overlay.dart';
import '../features/player/immersive_player_page.dart';
import '../features/player/queue_sheet.dart';
import '../features/search/search_page.dart';
import '../features/settings/settings_page.dart';

/// Root responsive application shell for AuraMusic.
class AuraAppShell extends ConsumerStatefulWidget {
  /// Creates an [AuraAppShell].
  const AuraAppShell({super.key});

  @override
  ConsumerState<AuraAppShell> createState() => _AuraAppShellState();
}

class _AuraAppShellState extends ConsumerState<AuraAppShell> {
  static const List<({String label, IconData icon})> _navItems = [
    (label: '首页', icon: Icons.home_rounded),
    (label: '搜索', icon: Icons.search_rounded),
    (label: '设置', icon: Icons.tune_rounded),
  ];

  final PageController _pageController = PageController();
  int _tabIndex = 0;
  double _scrollVelocity = 0.0;
  DateTime _lastScrollTime = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (_tabIndex == index) return;
    setState(() => _tabIndex = index);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;

    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0.0;
      final now = DateTime.now();
      final elapsedMs = now
          .difference(_lastScrollTime)
          .inMilliseconds
          .clamp(8, 250);
      _lastScrollTime = now;
      final nextVelocity = (delta / elapsedMs) * 1000.0;
      if ((nextVelocity - _scrollVelocity).abs() > 40) {
        setState(() => _scrollVelocity = nextVelocity.clamp(-1200.0, 1200.0));
      }
    } else if (notification is ScrollEndNotification &&
        _scrollVelocity != 0.0) {
      setState(() => _scrollVelocity = 0.0);
    }
    return false;
  }

  void _openImmersivePlayer(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ImmersivePlayerPage()),
    );
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
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;

    return AmbientBackground(
      colors: colors,
      enabled: state.ambientEnabled,
      isDark: isDark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  WindowsTitleBar(primaryColor: primaryColor, isDark: isDark),
                  Expanded(
                    child: NotificationListener<ScrollNotification>(
                      onNotification: _handleScrollNotification,
                      child: isDesktop
                          ? _buildDesktopBody(primaryColor, isDark)
                          : _buildMobileBody(primaryColor, isDark),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: isDesktop ? 248 : 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 820 : 680,
                    ),
                    child: LiquidDock(
                      scrollVelocity: _scrollVelocity,
                      cover: ProceduralCoverArt(
                        colors: colors,
                        size: 46,
                        radius: 14,
                        imageUrl: track?.coverUrl,
                      ),
                      title: track?.title ?? 'Lite Music',
                      artist: track?.artist ?? '点击探索音乐',
                      isPlaying: state.isPlaying,
                      progress: state.progress,
                      currentLyric:
                          (track != null &&
                              track.lyrics.isNotEmpty &&
                              state.activeLyric < track.lyrics.length)
                          ? track.lyrics[state.activeLyric]
                          : '',
                      lyricKey: '${track?.id ?? ''}_${state.activeLyric}',
                      onSeek: notifier.seek,
                      onTap: () => _openImmersivePlayer(context),
                      onPlayPause: notifier.togglePlay,
                      onNext: notifier.nextTrack,
                      onOpenQueue: () => showQueueSheet(context),
                    ),
                  ),
                ),
              ),
            ),
            if (state.desktopLyrics &&
                (!Platform.isWindows ||
                    Platform.environment.containsKey('FLUTTER_TEST')))
              const DesktopLyricsOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileBody(Color primaryColor, bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
          child: _MobileSegmentedTabBar(
            items: _navItems.map((e) => e.label).toList(growable: false),
            selectedIndex: _tabIndex,
            primaryColor: primaryColor,
            isDark: isDark,
            onSelect: _selectTab,
          ),
        ),
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _tabIndex = index),
            children: const [HomePage(), SearchPage(), SettingsPage()],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopBody(Color primaryColor, bool isDark) {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
          child: SizedBox(
            width: 216,
            child: SquircleCard(
              radius: 26,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        const LiteMusicLogo(size: 30),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Lite Music',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: primaryColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  for (var i = 0; i < _navItems.length; i++) ...[
                    _DesktopSidebarItem(
                      label: _navItems[i].label,
                      icon: _navItems[i].icon,
                      selected: _tabIndex == i,
                      primaryColor: primaryColor,
                      isDark: isDark,
                      onTap: () => setState(() => _tabIndex = i),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _tabIndex,
            children: const [HomePage(), SearchPage(), SettingsPage()],
          ),
        ),
      ],
    );
  }
}

class _MobileSegmentedTabBar extends StatelessWidget {
  const _MobileSegmentedTabBar({
    required this.items,
    required this.selectedIndex,
    required this.primaryColor,
    required this.isDark,
    required this.onSelect,
  });

  final List<String> items;
  final int selectedIndex;
  final Color primaryColor;
  final bool isDark;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SquircleCard(
      radius: 22,
      padding: const EdgeInsets.all(4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / items.length;
          return SizedBox(
            height: 40,
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  left: segmentWidth * selectedIndex,
                  top: 0,
                  bottom: 0,
                  width: segmentWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(
                        alpha: isDark ? 0.18 : 0.12,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onSelect(i),
                          child: Center(
                            child: Text(
                              items[i],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: selectedIndex == i
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: selectedIndex == i
                                    ? primaryColor
                                    : primaryColor.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DesktopSidebarItem extends StatelessWidget {
  const _DesktopSidebarItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.primaryColor,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color primaryColor;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? primaryColor.withValues(alpha: isDark ? 0.16 : 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: selected
                  ? primaryColor
                  : primaryColor.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? primaryColor
                    : primaryColor.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
