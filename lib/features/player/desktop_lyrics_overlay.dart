import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/player_provider.dart';
import '../../design_system/morph_icon.dart';
import '../../design_system/squircle_border.dart';

/// Draggable floating translucent pill displaying live lyrics when
/// [PlayerState.desktopLyrics] is enabled.
class DesktopLyricsOverlay extends ConsumerStatefulWidget {
  /// Creates a [DesktopLyricsOverlay].
  const DesktopLyricsOverlay({super.key});

  @override
  ConsumerState<DesktopLyricsOverlay> createState() =>
      _DesktopLyricsOverlayState();
}

class _DesktopLyricsOverlayState extends ConsumerState<DesktopLyricsOverlay> {
  Offset _offset = const Offset(20, 76);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerProvider);
    if (!state.desktopLyrics) return const SizedBox.shrink();

    final notifier = ref.read(playerProvider.notifier);
    final track = state.currentTrack;
    final activeLine =
        (track != null &&
            track.lyrics.isNotEmpty &&
            state.activeLyric < track.lyrics.length)
        ? track.lyrics[state.activeLyric]
        : 'AuraMusic 桌面歌词';

    final size = MediaQuery.sizeOf(context);
    final maxWidth = (size.width - 32).clamp(220.0, 380.0);
    final clampedLeft = _offset.dx.clamp(
      12.0,
      (size.width - maxWidth - 12).clamp(12.0, size.width),
    );
    final clampedTop = _offset.dy.clamp(
      24.0,
      (size.height - 110).clamp(24.0, size.height),
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryColor = primaryColor.withValues(alpha: 0.68);

    return Positioned(
      left: clampedLeft,
      top: clampedTop,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _offset = Offset(
              clampedLeft + details.delta.dx,
              clampedTop + details.delta.dy,
            );
          });
        },
        child: SizedBox(
          width: maxWidth,
          child: SquircleCard(
            radius: 26,
            blurSigma: 28,
            backgroundColor: isDark
                ? const Color(0xFF0F172A).withValues(alpha: 0.72)
                : Colors.white.withValues(alpha: 0.84),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track?.title ?? 'AuraMusic',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: secondaryColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        activeLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: state.isPlaying ? '暂停' : '播放',
                  visualDensity: VisualDensity.compact,
                  onPressed: notifier.togglePlay,
                  icon: MorphPlayPauseIcon(
                    isPlaying: state.isPlaying,
                    size: 20,
                    color: primaryColor,
                  ),
                ),
                IconButton(
                  tooltip: '关闭桌面歌词',
                  visualDensity: VisualDensity.compact,
                  onPressed: notifier.toggleDesktopLyrics,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: secondaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
