import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'squircle_border.dart';

/// Lite Music brand logo featuring a pure white squircle base, an irregular
/// blue-pink organic circular mist blob, and the equalizer waveform icon.
class LiteMusicLogo extends StatelessWidget {
  /// Creates a [LiteMusicLogo] of square [size].
  const LiteMusicLogo({super.key, this.size = 32.0});

  /// Width and height of the logo badge in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    final shape = SquircleBorder(radius: size * 0.34);

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: shape,
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: size * 0.25,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: SizedBox(
          width: size,
          height: size,
          child: ColoredBox(
            color: Colors.white,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size.square(size),
                  painter: const _BluePinkMistPainter(),
                ),
                Icon(
                  Icons.graphic_eq_rounded,
                  size: size * 0.56,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.18),
                      blurRadius: size * 0.12,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BluePinkMistPainter extends CustomPainter {
  const _BluePinkMistPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w * 0.5, h * 0.5);
    final blurSigma = (w * 0.085).clamp(1.5, 18.0);

    void drawMistLobe(
      Offset offset,
      double rx,
      double ry,
      double angleRad,
      Color inner,
      Color outer,
    ) {
      canvas.save();
      canvas.translate(center.dx + offset.dx * w, center.dy + offset.dy * h);
      canvas.rotate(angleRad);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: rx * 2 * w,
        height: ry * 2 * h,
      );
      final paint = Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          (rx > ry ? rx : ry) * w,
          [inner, outer],
          const [0.15, 1.0],
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);
      canvas.drawOval(rect, paint);
      canvas.restore();
    }

    // Irregular circular fog composition: overlapping sky-blue and rose-pink lobes.
    drawMistLobe(
      const Offset(-0.08, -0.06),
      0.34,
      0.31,
      -0.35,
      const Color(0xF038BDF8),
      const Color(0x0038BDF8),
    );
    drawMistLobe(
      const Offset(0.11, 0.07),
      0.35,
      0.30,
      0.42,
      const Color(0xF0F472B6),
      const Color(0x00F472B6),
    );
    drawMistLobe(
      const Offset(-0.05, 0.11),
      0.27,
      0.24,
      0.2,
      const Color(0xD860A5FA),
      const Color(0x003B82F6),
    );
    drawMistLobe(
      const Offset(0.08, -0.09),
      0.25,
      0.22,
      -0.5,
      const Color(0xCCFB7185),
      const Color(0x00EC4899),
    );
    drawMistLobe(
      Offset.zero,
      0.28,
      0.26,
      0.15,
      const Color(0xC0818CF8),
      const Color(0x00C084FC),
    );
  }

  @override
  bool shouldRepaint(covariant _BluePinkMistPainter oldDelegate) => false;
}
