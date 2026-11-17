import 'package:flutter/material.dart';

const Curve _kSpringCurve = Cubic(0.34, 1.56, 0.64, 1.0);

/// An animated play/pause icon that morphs with a spring scale and subtle
/// rotation transition when [isPlaying] changes.
class MorphPlayPauseIcon extends StatelessWidget {
  /// Creates a [MorphPlayPauseIcon].
  const MorphPlayPauseIcon({
    super.key,
    required this.isPlaying,
    this.size = 24.0,
    this.color,
  });

  /// Whether playback is currently active.
  final bool isPlaying;

  /// Logical icon size in pixels.
  final double size;

  /// Optional icon color; defaults to the ambient [IconTheme] color.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: _kSpringCurve,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (Widget child, Animation<double> animation) {
        final Animation<double> rotation = Tween<double>(
          begin: 0.12,
          end: 0.0,
        ).animate(animation);
        return RotationTransition(
          turns: rotation,
          child: ScaleTransition(scale: animation, child: child),
        );
      },
      child: Icon(
        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
        key: ValueKey<bool>(isPlaying),
        size: size,
        color: color,
      ),
    );
  }
}

/// An animated heart/like icon with a spring scale bounce on state change.
class MorphLikeIcon extends StatelessWidget {
  /// Creates a [MorphLikeIcon].
  const MorphLikeIcon({
    super.key,
    required this.isLiked,
    this.size = 24.0,
    this.likedColor = const Color(0xFFFF3B5C),
    this.unlikedColor,
  });

  /// Whether the current track is liked.
  final bool isLiked;

  /// Logical icon size in pixels.
  final double size;

  /// Color used when [isLiked] is true.
  final Color likedColor;

  /// Optional color used when [isLiked] is false.
  final Color? unlikedColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: _kSpringCurve,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return ScaleTransition(scale: animation, child: child);
      },
      child: Icon(
        isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        key: ValueKey<bool>(isLiked),
        size: size,
        color: isLiked ? likedColor : unlikedColor,
      ),
    );
  }
}

/// An animated playback-mode icon supporting `'loop_list'`, `'loop_one'`, and
/// `'play_once'`.
class MorphModeIcon extends StatelessWidget {
  /// Creates a [MorphModeIcon].
  const MorphModeIcon({
    super.key,
    required this.mode,
    this.size = 24.0,
    this.color,
  });

  /// Playback mode identifier: `'loop_list'`, `'loop_one'`, or `'play_once'`.
  final String mode;

  /// Logical icon size in pixels.
  final double size;

  /// Optional icon color; defaults to the ambient [IconTheme] color.
  final Color? color;

  IconData _iconForMode(String value) {
    return switch (value) {
      'loop_one' => Icons.repeat_one_rounded,
      'play_once' => Icons.arrow_right_alt_rounded,
      'loop_list' || _ => Icons.repeat_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: _kSpringCurve,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (Widget child, Animation<double> animation) {
        final Animation<double> rotation = Tween<double>(
          begin: -0.1,
          end: 0.0,
        ).animate(animation);
        return RotationTransition(
          turns: rotation,
          child: ScaleTransition(scale: animation, child: child),
        );
      },
      child: Icon(
        _iconForMode(mode),
        key: ValueKey<String>(mode),
        size: size,
        color: color,
      ),
    );
  }
}
