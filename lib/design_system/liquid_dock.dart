import 'dart:ui';

import 'package:flutter/material.dart';

import 'morph_icon.dart';
import 'squircle_border.dart';

/// A floating liquid-glass bottom playback dock with scroll-driven jelly
/// inertia spring rebound.
class LiquidDock extends StatelessWidget {
  /// Creates a [LiquidDock].
  const LiquidDock({
    super.key,
    this.scrollVelocity = 0.0,
    required this.cover,
    required this.title,
    required this.artist,
    required this.isPlaying,
    required this.onTap,
    required this.onPlayPause,
    required this.onNext,
    required this.onOpenQueue,
  });

  /// Scroll velocity (pixels/sec) driving the jelly inertia spring transform.
  final double scrollVelocity;

  /// Album cover widget displayed on the leading edge.
  final Widget cover;

  /// Current track title.
  final String title;

  /// Current track artist.
  final String artist;

  /// Whether playback is currently active.
  final bool isPlaying;

  /// Called when the dock body is tapped to open the full player.
  final VoidCallback onTap;

  /// Called when the play/pause button is pressed.
  final VoidCallback onPlayPause;

  /// Called when the next-track button is pressed.
  final VoidCallback onNext;

  /// Called when the queue button is pressed.
  final VoidCallback onOpenQueue;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double clampedVelocity = scrollVelocity.clamp(-1200.0, 1200.0);
    final double normalized = clampedVelocity / 1200.0;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: normalized),
      duration: const Duration(milliseconds: 420),
      curve: const Cubic(0.34, 1.56, 0.64, 1.0),
      builder: (BuildContext context, double value, Widget? child) {
        final double stretch = value.abs() * 0.045;
        final double scaleY = 1.0 + stretch;
        final double scaleX = 1.0 - stretch * 0.38;
        final double offsetY = value * 5.0;

        return Transform.translate(
          offset: Offset(0.0, offsetY),
          child: Transform.scale(
            scaleX: scaleX,
            scaleY: scaleY,
            alignment: Alignment.bottomCenter,
            child: child,
          ),
        );
      },
      child: _buildDockBody(context, isDark),
    );
  }

  Widget _buildDockBody(BuildContext context, bool isDark) {
    const SquircleBorder dockShape = SquircleBorder(radius: 33.0);
    final Color primaryText = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color secondaryText = isDark
        ? Colors.white.withValues(alpha: 0.68)
        : const Color(0xFF0F172A).withValues(alpha: 0.62);

    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: dockShape,
        shadows: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.42)
                : const Color(0xFF0F172A).withValues(alpha: 0.14),
            blurRadius: 36.0,
            offset: const Offset(0.0, 16.0),
          ),
        ],
      ),
      child: ClipPath(
        clipper: const ShapeBorderClipper(shape: dockShape),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 36.0, sigmaY: 36.0),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              height: 66.0,
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              decoration: ShapeDecoration(
                shape: dockShape.copyWith(
                  side: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.26)
                        : Colors.white.withValues(alpha: 0.92),
                    width: 1.0,
                  ),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          Colors.white.withValues(alpha: 0.16),
                          Colors.white.withValues(alpha: 0.06),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.86),
                          Colors.white.withValues(alpha: 0.58),
                        ],
                ),
              ),
              child: Row(
                children: [
                  ClipPath(
                    clipper: const ShapeBorderClipper(
                      shape: SquircleBorder(radius: 15.0),
                    ),
                    child: SizedBox(width: 46.0, height: 46.0, child: cover),
                  ),
                  const SizedBox(width: 11.0),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: primaryText,
                          ),
                        ),
                        const SizedBox(height: 1.0),
                        Text(
                          artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4.0),
                  _DockIconButton(
                    tooltip: isPlaying ? 'Pause' : 'Play',
                    onPressed: onPlayPause,
                    filled: true,
                    backgroundColor: primaryText,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    child: MorphPlayPauseIcon(
                      isPlaying: isPlaying,
                      size: 20.0,
                      color: isDark ? Colors.black : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4.0),
                  _DockIconButton(
                    tooltip: 'Next',
                    onPressed: onNext,
                    foregroundColor: primaryText,
                    child: Icon(
                      Icons.skip_next_rounded,
                      size: 22.0,
                      color: primaryText,
                    ),
                  ),
                  _DockIconButton(
                    tooltip: 'Queue',
                    onPressed: onOpenQueue,
                    foregroundColor: primaryText,
                    child: Icon(
                      Icons.queue_music_rounded,
                      size: 20.0,
                      color: primaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockIconButton extends StatelessWidget {
  const _DockIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.foregroundColor,
    required this.child,
    this.filled = false,
    this.backgroundColor,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final Color foregroundColor;
  final Widget child;
  final bool filled;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36.0,
      height: 36.0,
      child: Material(
        color: filled ? backgroundColor : Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Tooltip(
            message: tooltip,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
