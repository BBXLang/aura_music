import 'package:flutter/material.dart';

import 'squircle_border.dart';

/// Paints a procedural offline album cover using a multi-stop diagonal gradient
/// and layered geometric glow circles clipped to a [SquircleBorder].
class ProceduralCoverArt extends StatelessWidget {
  /// Creates a [ProceduralCoverArt] widget.
  const ProceduralCoverArt({
    super.key,
    required this.colors,
    this.size = 200.0,
    this.radius = 24.0,
    this.imageUrl,
  });

  /// Palette of three colors used for the gradient and geometric glow circles.
  final List<Color> colors;

  /// Width and height of the square cover art in logical pixels.
  final double size;

  /// Corner radius of the [SquircleBorder] clip.
  final double radius;

  /// Optional network cover image URL overlaid on the procedural background.
  final String? imageUrl;

  List<Color> _normalizedColors() {
    if (colors.isEmpty) {
      return const [Color(0xFF6B4EFF), Color(0xFF00C2FF), Color(0xFFFF4D8D)];
    }
    return List<Color>.generate(
      3,
      (int index) => colors[index % colors.length],
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Color> palette = _normalizedColors();

    final String? url = imageUrl?.trim();

    return ClipPath(
      clipper: ShapeBorderClipper(shape: SquircleBorder(radius: radius)),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _ProceduralCoverPainter(colors: palette)),
            if (url != null && url.isNotEmpty)
              Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProceduralCoverPainter extends CustomPainter {
  const _ProceduralCoverPainter({required this.colors});

  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final Rect rect = Offset.zero & size;
    final double unit = size.shortestSide;
    final Color c1 = colors[0];
    final Color c2 = colors[1];
    final Color c3 = colors[2];

    // Base multi-stop diagonal gradient
    final Paint bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [c1, c2, c3],
        stops: const [0.0, 0.52, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // Top-right geometric glow circle
    canvas.drawCircle(
      Offset(size.width * 0.725, size.height * 0.275),
      unit * 0.28,
      Paint()..color = c3.withValues(alpha: 0.40),
    );

    // Bottom-left geometric glow circle
    canvas.drawCircle(
      Offset(size.width * 0.27, size.height * 0.74),
      unit * 0.32,
      Paint()..color = c1.withValues(alpha: 0.48),
    );

    // Center luminous orb
    canvas.drawCircle(
      Offset(size.width * 0.50, size.height * 0.50),
      unit * 0.12,
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );
  }

  @override
  bool shouldRepaint(_ProceduralCoverPainter oldDelegate) {
    return oldDelegate.colors[0] != colors[0] ||
        oldDelegate.colors[1] != colors[1] ||
        oldDelegate.colors[2] != colors[2];
  }
}
