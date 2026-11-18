import 'dart:io';

import 'package:flutter/material.dart';

import '../core/audio/ohos_audio_bridge.dart';
import 'lite_music_logo.dart';

/// Seamlessly integrated custom frameless title bar rendered on Windows desktop.
///
/// Returns [SizedBox.shrink] on non-Windows platforms and during `flutter test`
/// runs so mobile layouts and widget tests remain unchanged.
class WindowsTitleBar extends StatelessWidget {
  /// Creates a [WindowsTitleBar].
  const WindowsTitleBar({
    super.key,
    required this.primaryColor,
    required this.isDark,
    this.title = 'Lite Music',
  });

  final Color primaryColor;
  final bool isDark;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (!Platform.isWindows ||
        Platform.environment.containsKey('FLUTTER_TEST')) {
      return const SizedBox.shrink();
    }

    const bridge = OhosAudioBridge();

    return SizedBox(
      height: 36,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => bridge.startWindowDrag(),
              onDoubleTap: bridge.maximizeOrRestoreWindow,
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Row(
                  children: [
                    const LiteMusicLogo(size: 20),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        color: primaryColor.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _WindowCaptionButton(
            tooltip: '最小化',
            icon: Icons.remove_rounded,
            primaryColor: primaryColor,
            isDark: isDark,
            onPressed: bridge.minimizeWindow,
          ),
          _WindowCaptionButton(
            tooltip: '最大化 / 还原',
            icon: Icons.crop_square_rounded,
            iconSize: 14,
            primaryColor: primaryColor,
            isDark: isDark,
            onPressed: bridge.maximizeOrRestoreWindow,
          ),
          _WindowCaptionButton(
            tooltip: '关闭',
            icon: Icons.close_rounded,
            primaryColor: primaryColor,
            isDark: isDark,
            isClose: true,
            onPressed: bridge.closeWindow,
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

class _WindowCaptionButton extends StatefulWidget {
  const _WindowCaptionButton({
    required this.tooltip,
    required this.icon,
    required this.primaryColor,
    required this.isDark,
    required this.onPressed,
    this.iconSize = 16,
    this.isClose = false,
  });

  final String tooltip;
  final IconData icon;
  final double iconSize;
  final Color primaryColor;
  final bool isDark;
  final bool isClose;
  final VoidCallback onPressed;

  @override
  State<_WindowCaptionButton> createState() => _WindowCaptionButtonState();
}

class _WindowCaptionButtonState extends State<_WindowCaptionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = _hovered
        ? (widget.isClose
              ? const Color(0xFFE81123).withValues(alpha: 0.85)
              : widget.primaryColor.withValues(
                  alpha: widget.isDark ? 0.14 : 0.10,
                ))
        : Colors.transparent;
    final fgColor = (_hovered && widget.isClose)
        ? Colors.white
        : widget.primaryColor.withValues(alpha: _hovered ? 0.96 : 0.72);

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 38,
            height: 28,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.icon, size: widget.iconSize, color: fgColor),
          ),
        ),
      ),
    );
  }
}
