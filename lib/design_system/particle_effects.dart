import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Renders slow, gentle outward-drifting luminous particles around an album
/// cover.
///
/// Drift animation runs while [isPlaying] is `true` and pauses when `false`.
class CoverParticleHalo extends StatefulWidget {
  /// Creates a [CoverParticleHalo].
  const CoverParticleHalo({
    super.key,
    required this.isPlaying,
    this.color = Colors.white,
    this.particleCount = 24,
    this.child,
  });

  /// Whether playback is active and particles should drift outward.
  final bool isPlaying;

  /// Base luminous tint of the halo particles.
  final Color color;

  /// Number of particles distributed around the cover perimeter.
  final int particleCount;

  /// Optional child widget (typically the album cover) centered in the halo.
  final Widget? child;

  @override
  State<CoverParticleHalo> createState() => _CoverParticleHaloState();
}

class _CoverParticleHaloState extends State<CoverParticleHalo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(CoverParticleHalo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (BuildContext context, Widget? _) {
                  return CustomPaint(
                    painter: _CoverParticleHaloPainter(
                      progress: _controller.value,
                      color: widget.color,
                      particleCount: widget.particleCount,
                      isPlaying: widget.isPlaying,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _CoverParticleHaloPainter extends CustomPainter {
  const _CoverParticleHaloPainter({
    required this.progress,
    required this.color,
    required this.particleCount,
    required this.isPlaying,
  });

  final double progress;
  final Color color;
  final int particleCount;
  final bool isPlaying;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || particleCount <= 0) return;

    final Offset center = Offset(size.width / 2.0, size.height / 2.0);
    final double baseRadius = size.shortestSide * 0.36;
    final double maxDrift = size.shortestSide * 0.18;
    final Paint paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < particleCount; i++) {
      final double seed = (i * 0.61803398875) % 1.0;
      final double life = (progress + seed) % 1.0;
      final double angle =
          (i / particleCount) * 2.0 * math.pi + seed * 0.4 + life * 0.15;
      final double dist = baseRadius + life * maxDrift;
      final Offset pos = Offset(
        center.dx + math.cos(angle) * dist,
        center.dy + math.sin(angle) * dist,
      );

      // Smooth fade-in then fade-out over the particle's outward drift.
      final double alphaEnvelope = math.sin(life * math.pi).clamp(0.0, 1.0);
      final double baseAlpha = isPlaying ? 0.65 : 0.25;
      final double particleRadius = 1.4 + (i % 3) * 0.7;

      paint.color = color.withValues(alpha: alphaEnvelope * baseAlpha);
      canvas.drawCircle(pos, particleRadius, paint);
    }
  }

  @override
  bool shouldRepaint(_CoverParticleHaloPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.particleCount != particleCount ||
        oldDelegate.isPlaying != isPlaying;
  }
}

/// A custom progress bar featuring a smooth right-large-left-small glowing
/// cone tip and slow backward-drifting trailing particles.
class ConeProgressBar extends StatefulWidget {
  /// Creates a [ConeProgressBar].
  const ConeProgressBar({
    super.key,
    required this.progress,
    required this.onSeek,
    this.accentColor = const Color(0xFF00C2FF),
    this.isPlaying = true,
    this.height = 32.0,
  });

  /// Normalized playback progress in `[0.0, 1.0]`.
  final double progress;

  /// Called with a normalized `[0.0, 1.0]` position when the user taps or
  /// drags along the bar.
  final ValueChanged<double> onSeek;

  /// Accent color blended into the progress fill and cone glow.
  final Color accentColor;

  /// Whether trailing particles should animate backward.
  final bool isPlaying;

  /// Interactive hit-test height of the slider widget.
  final double height;

  @override
  State<ConeProgressBar> createState() => _ConeProgressBarState();
}

class _ConeProgressBarState extends State<ConeProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(ConeProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSeek(Offset localPosition) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null || box.size.width <= 0.0) return;
    final double normalized = (localPosition.dx / box.size.width).clamp(
      0.0,
      1.0,
    );
    widget.onSeek(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final double clampedProgress = widget.progress.clamp(0.0, 1.0);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (TapDownDetails details) => _handleSeek(details.localPosition),
      onHorizontalDragStart: (DragStartDetails details) =>
          _handleSeek(details.localPosition),
      onHorizontalDragUpdate: (DragUpdateDetails details) =>
          _handleSeek(details.localPosition),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? _) {
            return CustomPaint(
              painter: _ConeProgressPainter(
                progress: clampedProgress,
                trailPhase: _controller.value,
                accentColor: widget.accentColor,
                isDark: isDark,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ConeProgressPainter extends CustomPainter {
  const _ConeProgressPainter({
    required this.progress,
    required this.trailPhase,
    required this.accentColor,
    required this.isDark,
  });

  final double progress;
  final double trailPhase;
  final Color accentColor;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final double centerY = size.height / 2.0;
    const double trackHeight = 4.5;
    final RRect trackRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2.0, centerY),
        width: size.width,
        height: trackHeight,
      ),
      const Radius.circular(trackHeight / 2.0),
    );

    // 1. Background track
    final Paint trackPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.16)
          : Colors.black.withValues(alpha: 0.12);
    canvas.drawRRect(trackRRect, trackPaint);

    final double fillWidth = (size.width * progress).clamp(0.0, size.width);
    if (fillWidth <= 0.5) return;

    // 2. Filled track gradient
    final Rect fillRect = Rect.fromLTWH(
      0.0,
      centerY - trackHeight / 2.0,
      fillWidth,
      trackHeight,
    );
    final RRect fillRRect = RRect.fromRectAndRadius(
      fillRect,
      const Radius.circular(trackHeight / 2.0),
    );
    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [accentColor, Colors.white],
      ).createShader(fillRect);
    canvas.drawRRect(fillRRect, fillPaint);

    // 3. Backward-drifting trailing particles behind the cone head
    const int trailCount = 10;
    final Paint particlePaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < trailCount; i++) {
      final double seed = (i * 0.37) % 1.0;
      final double life = (trailPhase + seed) % 1.0;
      final double px = fillWidth - life * math.min(56.0, fillWidth);
      if (px < 0.0) continue;

      final double yOffset =
          math.sin(i * 2.1 + life * 4.0) * (3.5 + life * 4.0);
      final double alpha = (1.0 - life) * 0.72;
      final double radius = (1.0 - life * 0.6) * 1.8;

      particlePaint.color = Color.lerp(
        Colors.white,
        accentColor,
        life,
      )!.withValues(alpha: alpha);
      canvas.drawCircle(Offset(px, centerY + yOffset), radius, particlePaint);
    }

    // 4. Smooth right-large-left-small glowing cone tip at fillWidth
    const double coneLength = 22.0;
    const double coneHalfHeight = 5.2;
    final double tipX = fillWidth;
    final double tailX = math.max(0.0, tipX - coneLength);

    final Path conePath = Path()
      ..moveTo(tailX, centerY)
      ..cubicTo(
        tailX + (tipX - tailX) * 0.35,
        centerY - coneHalfHeight * 0.18,
        tailX + (tipX - tailX) * 0.72,
        centerY - coneHalfHeight,
        tipX - 3.5,
        centerY - coneHalfHeight,
      )
      ..cubicTo(
        tipX - 1.2,
        centerY - coneHalfHeight,
        tipX,
        centerY - coneHalfHeight * 0.55,
        tipX,
        centerY,
      )
      ..cubicTo(
        tipX,
        centerY + coneHalfHeight * 0.55,
        tipX - 1.2,
        centerY + coneHalfHeight,
        tipX - 3.5,
        centerY + coneHalfHeight,
      )
      ..cubicTo(
        tailX + (tipX - tailX) * 0.72,
        centerY + coneHalfHeight,
        tailX + (tipX - tailX) * 0.35,
        centerY + coneHalfHeight * 0.18,
        tailX,
        centerY,
      )
      ..close();

    // Soft outer glow around the cone tip
    final Paint glowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.75)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7.0);
    canvas.drawPath(conePath, glowPaint);

    // Luminous core cone
    final Rect coneBounds = Rect.fromLTRB(
      tailX,
      centerY - coneHalfHeight,
      tipX,
      centerY + coneHalfHeight,
    );
    final Paint conePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.85),
          Colors.white,
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(coneBounds);
    canvas.drawPath(conePath, conePaint);
  }

  @override
  bool shouldRepaint(_ConeProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trailPhase != trailPhase ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isDark != isDark;
  }
}
