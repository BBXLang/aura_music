import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// An immersive ambient background that renders three slow-moving, gently
/// breathing radial-gradient fog blobs over a pure black or pure white base.
class AmbientBackground extends StatefulWidget {
  /// Creates an [AmbientBackground].
  const AmbientBackground({
    super.key,
    required this.colors,
    this.enabled = true,
    this.isDark = true,
    required this.child,
  });

  /// Palette of three colors used to tint the three ambient fog blobs.
  final List<Color> colors;

  /// Whether the animated ambient fog layer is rendered.
  final bool enabled;

  /// Selects pure black (`#000000`) when true or pure white (`#FFFFFF`) when false.
  final bool isDark;

  /// Foreground content layered above the ambient background.
  final Widget child;

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool get _shouldAnimate =>
      widget.enabled && Platform.environment.containsKey('FLUTTER_TEST');

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
    if (_shouldAnimate) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(AmbientBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (_shouldAnimate) {
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

  List<Color> _normalizedColors() {
    if (widget.colors.isEmpty) {
      return const [Color(0xFF6B4EFF), Color(0xFF00C2FF), Color(0xFFFF4D8D)];
    }
    return List<Color>.generate(
      3,
      (int index) => widget.colors[index % widget.colors.length],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color baseColor = widget.isDark
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);
    final List<Color> blobColors = _normalizedColors();

    return ColoredBox(
      color: baseColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.enabled)
            IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (BuildContext context, Widget? _) {
                    return CustomPaint(
                      painter: _AmbientFogPainter(
                        progress: _controller.value,
                        colors: blobColors,
                        isDark: widget.isDark,
                      ),
                    );
                  },
                ),
              ),
            ),
          widget.child,
        ],
      ),
    );
  }
}

class _AmbientFogPainter extends CustomPainter {
  const _AmbientFogPainter({
    required this.progress,
    required this.colors,
    required this.isDark,
  });

  final double progress;
  final List<Color> colors;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final double t = progress * 2.0 * math.pi;
    final double baseOpacity = isDark ? 0.34 : 0.24;

    // Blob 1: top-left drifting fog
    _paintBlob(
      canvas,
      size,
      center: Offset(
        size.width * (0.18 + 0.08 * math.sin(t)),
        size.height * (0.14 + 0.07 * math.cos(t)),
      ),
      radius: size.longestSide * (0.52 + 0.05 * math.sin(t + 0.8)),
      color: colors[0].withValues(
        alpha: baseOpacity * (0.88 + 0.12 * math.sin(t)),
      ),
    );

    // Blob 2: mid-right breathing fog
    _paintBlob(
      canvas,
      size,
      center: Offset(
        size.width * (0.84 + 0.07 * math.cos(t + 1.4)),
        size.height * (0.42 + 0.08 * math.sin(t + 2.1)),
      ),
      radius: size.longestSide * (0.48 + 0.05 * math.cos(t + 1.2)),
      color: colors[1].withValues(
        alpha: baseOpacity * (0.85 + 0.15 * math.cos(t + 1.0)),
      ),
    );

    // Blob 3: bottom-center warm anchor fog
    _paintBlob(
      canvas,
      size,
      center: Offset(
        size.width * (0.46 + 0.09 * math.sin(t + 3.0)),
        size.height * (0.86 + 0.06 * math.cos(t + 2.5)),
      ),
      radius: size.longestSide * (0.54 + 0.06 * math.sin(t + 2.4)),
      color: colors[2].withValues(
        alpha: baseOpacity * (0.86 + 0.14 * math.sin(t + 2.0)),
      ),
    );
  }

  void _paintBlob(
    Canvas canvas,
    Size size, {
    required Offset center,
    required double radius,
    required Color color,
  }) {
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    final Paint paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color,
          color.withValues(alpha: color.a * 0.45),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_AmbientFogPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isDark != isDark ||
        oldDelegate.colors[0] != colors[0] ||
        oldDelegate.colors[1] != colors[1] ||
        oldDelegate.colors[2] != colors[2];
  }
}
