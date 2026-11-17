import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

/// A continuous-curvature squircle border inspired by HarmonyOS NEXT.
///
/// Uses cubic Bézier corner transitions so curvature blends smoothly from
/// straight edges into rounded corners without abrupt tangent discontinuities.
class SquircleBorder extends OutlinedBorder {
  /// Creates a [SquircleBorder] with the given corner [radius] and [side].
  const SquircleBorder({this.radius = 24.0, super.side = BorderSide.none});

  /// The nominal corner radius of the squircle.
  final double radius;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  SquircleBorder copyWith({BorderSide? side, double? radius}) {
    return SquircleBorder(
      side: side ?? this.side,
      radius: radius ?? this.radius,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return SquircleBorder(side: side.scale(t), radius: radius * t);
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is SquircleBorder) {
      return SquircleBorder(
        side: BorderSide.lerp(a.side, side, t),
        radius: lerpDouble(a.radius, radius, t) ?? radius,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is SquircleBorder) {
      return SquircleBorder(
        side: BorderSide.lerp(side, b.side, t),
        radius: lerpDouble(radius, b.radius, t) ?? radius,
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    final double inset = side.width;
    final Rect innerRect = rect.deflate(inset);
    final double innerRadius = math.max(0.0, radius - inset);
    return _buildSquirclePath(innerRect, innerRadius);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return _buildSquirclePath(rect, radius);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width <= 0.0) {
      return;
    }
    final Path path = getOuterPath(rect.deflate(side.width / 2.0));
    final Paint paint = side.toPaint();
    canvas.drawPath(path, paint);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SquircleBorder &&
        other.side == side &&
        other.radius == radius;
  }

  @override
  int get hashCode => Object.hash(side, radius);

  /// Builds a closed continuous-curvature squircle [Path] inside [rect].
  static Path _buildSquirclePath(Rect rect, double cornerRadius) {
    final Path path = Path();
    if (rect.isEmpty) {
      return path;
    }

    final double maxRadius = math.min(rect.width, rect.height) / 2.0;
    final double r = cornerRadius.clamp(0.0, maxRadius);
    if (r <= 0.0) {
      path.addRect(rect);
      return path;
    }

    // Extend the tangent transition slightly beyond `r` for superellipse smoothness.
    final double s = math.min(r * 1.28, maxRadius);
    final double c1 = s * 0.48;
    final double c2 = r * 0.45;

    final double left = rect.left;
    final double top = rect.top;
    final double right = rect.right;
    final double bottom = rect.bottom;

    path.moveTo(left + s, top);

    // Top edge -> Top-right corner
    path.lineTo(right - s, top);
    path.cubicTo(right - c1, top, right, top + c2, right, top + s);

    // Right edge -> Bottom-right corner
    path.lineTo(right, bottom - s);
    path.cubicTo(right, bottom - c1, right - c2, bottom, right - s, bottom);

    // Bottom edge -> Bottom-left corner
    path.lineTo(left + s, bottom);
    path.cubicTo(left + c1, bottom, left, bottom - c2, left, bottom - s);

    // Left edge -> Top-left corner
    path.lineTo(left, top + s);
    path.cubicTo(left, top + c1, left + c2, top, left + s, top);

    path.close();
    return path;
  }
}

/// A frosted-glass container clipped to a [SquircleBorder] with a specular
/// top-edge highlight.
class SquircleCard extends StatelessWidget {
  /// Creates a [SquircleCard].
  const SquircleCard({
    super.key,
    required this.child,
    this.radius = 24.0,
    this.blurSigma = 24.0,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1.0,
    this.padding,
  });

  /// The widget displayed inside the card.
  final Widget child;

  /// Corner radius of the [SquircleBorder].
  final double radius;

  /// Gaussian blur sigma applied to the backdrop.
  final double blurSigma;

  /// Translucent fill color behind [child].
  final Color? backgroundColor;

  /// Optional explicit border color; defaults to a subtle specular highlight.
  final Color? borderColor;

  /// Width of the card's outer border.
  final double borderWidth;

  /// Optional inner padding around [child].
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color fill =
        backgroundColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.72));
    final Color topSpecular =
        borderColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.28)
            : Colors.white.withValues(alpha: 0.90));
    final Color bottomSpecular =
        borderColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.35));

    final SquircleBorder shape = SquircleBorder(radius: radius);

    return ClipPath(
      clipper: ShapeBorderClipper(shape: shape),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: CustomPaint(
          painter: _SpecularSquirclePainter(
            shape: shape,
            topColor: topSpecular,
            bottomColor: bottomSpecular,
            strokeWidth: borderWidth,
          ),
          child: DecoratedBox(
            decoration: ShapeDecoration(color: fill, shape: shape),
            child: padding != null
                ? Padding(padding: padding!, child: child)
                : child,
          ),
        ),
      ),
    );
  }
}

class _SpecularSquirclePainter extends CustomPainter {
  const _SpecularSquirclePainter({
    required this.shape,
    required this.topColor,
    required this.bottomColor,
    required this.strokeWidth,
  });

  final SquircleBorder shape;
  final Color topColor;
  final Color bottomColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (strokeWidth <= 0.0 || size.isEmpty) return;
    final Rect rect = Offset.zero & size;
    final Path path = shape.getOuterPath(rect.deflate(strokeWidth / 2.0));
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [topColor, bottomColor],
      ).createShader(rect);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SpecularSquirclePainter oldDelegate) {
    return oldDelegate.shape != shape ||
        oldDelegate.topColor != topColor ||
        oldDelegate.bottomColor != bottomColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
