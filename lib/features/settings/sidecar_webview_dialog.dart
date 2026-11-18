import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

/// Opens an in-app WebView2 dialog on Windows to complete OAuth login for a
/// Sidecar source and capture its custom-scheme callback URL.
Future<String?> showSidecarWebViewLoginDialog(
  BuildContext context, {
  required String url,
  required String callbackScheme,
  required String callbackHost,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _SidecarWebViewDialog(
      url: url,
      callbackScheme: callbackScheme,
      callbackHost: callbackHost,
    ),
  );
}

class _SidecarWebViewDialog extends StatefulWidget {
  const _SidecarWebViewDialog({
    required this.url,
    required this.callbackScheme,
    required this.callbackHost,
  });

  final String url;
  final String callbackScheme;
  final String callbackHost;

  @override
  State<_SidecarWebViewDialog> createState() => _SidecarWebViewDialogState();
}

class _SidecarWebViewDialogState extends State<_SidecarWebViewDialog> {
  final WebviewController _controller = WebviewController();
  StreamSubscription<String>? _urlSub;
  bool _ready = false;
  String? _error;
  bool _completed = false;

  String get _callbackPrefix =>
      '${widget.callbackScheme}://${widget.callbackHost}';

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    if (!Platform.isWindows) {
      setState(() => _error = '当前平台暂不支持内置 WebView2，请使用回调链接粘贴。');
      return;
    }
    try {
      await _controller.initialize();
      _urlSub = _controller.url.listen((currentUrl) {
        if (_completed) return;
        if (currentUrl.startsWith(_callbackPrefix)) {
          _completed = true;
          if (mounted) {
            Navigator.of(context).pop(currentUrl);
          }
        }
      });
      await _controller.loadUrl(widget.url);
      if (mounted) {
        setState(() => _ready = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'WebView2 初始化失败：$e');
      }
    }
  }

  @override
  void dispose() {
    _urlSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openExternalFallback() async {
    await Process.run('cmd', ['/c', 'start', '', widget.url]);
    if (!mounted) return;
    final controller = TextEditingController();
    final pasted = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('粘贴登录回调链接'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: '$_callbackPrefix?code=...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (pasted != null && pasted.isNotEmpty && mounted) {
      _completed = true;
      Navigator.of(context).pop(pasted);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 520,
        height: 640,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'OAuth 账号授权登录',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _openExternalFallback,
                    child: const Text('浏览器登录'),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: _openExternalFallback,
                              child: const Text('使用系统浏览器登录'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _ready
                  ? Webview(_controller)
                  : const Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      ),
    );
  }
}
