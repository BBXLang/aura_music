import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/source_plugin.dart';
import '../../core/source/js_plugin_bridge.dart';
import '../../core/state/player_provider.dart';
import '../../design_system/ambient_background.dart';
import '../../design_system/squircle_border.dart';
import '../../design_system/windows_title_bar.dart';
import 'sidecar_webview_dialog.dart';

/// Dedicated management page for enabling, disabling, authorizing, importing,
/// and removing music source plugins.
class SourceManagerPage extends ConsumerWidget {
  /// Creates a [SourceManagerPage].
  const SourceManagerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);
    final track = state.currentTrack;
    final colors =
        track?.colors ??
        const [Color(0xFF1E1B4B), Color(0xFF4338CA), Color(0xFF38BDF8)];
    final isDark = state.isDark;
    final primaryColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryColor = primaryColor.withValues(alpha: 0.64);

    return AmbientBackground(
      colors: colors,
      enabled: state.ambientEnabled,
      isDark: isDark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              WindowsTitleBar(
                primaryColor: primaryColor,
                isDark: isDark,
                title: '音源管理',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: '返回',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.arrow_back_rounded, color: primaryColor),
                    ),
                    Expanded(
                      child: Text(
                        '音源管理 (${state.sources.length})',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => showSidecarDialog(context, notifier),
                      icon: const Icon(Icons.terminal_rounded, size: 16),
                      label: const Text('Sidecar'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: () =>
                          showImportPluginDialog(context, notifier),
                      icon: const Icon(Icons.extension_outlined, size: 16),
                      label: const Text('导入 JS'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: state.sources.isEmpty
                    ? Center(
                        child: Text(
                          '暂无已接入音源，可通过右上角导入 JS 插件或接入 Sidecar',
                          style: TextStyle(color: secondaryColor, fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        itemCount: state.sources.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final source = state.sources[index];
                          return _SourceManagerCard(
                            source: source,
                            primaryColor: primaryColor,
                            secondaryColor: secondaryColor,
                            onToggleEnabled: () =>
                                notifier.toggleSourceEnabled(source.id),
                            onAuthPressed: () => handleSourceAuthAction(
                              context,
                              notifier,
                              source,
                            ),
                            onDelete: () =>
                                _confirmRemoveSource(context, notifier, source),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRemoveSource(
    BuildContext context,
    PlayerNotifier notifier,
    SourcePlugin source,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除音源'),
        content: Text('确定删除音源「${source.name}」？已保存的该音源授权令牌也将一并清除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await notifier.removeSource(source.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已删除音源「${source.name}」')));
  }
}

class _SourceManagerCard extends StatelessWidget {
  const _SourceManagerCard({
    required this.source,
    required this.primaryColor,
    required this.secondaryColor,
    required this.onToggleEnabled,
    required this.onAuthPressed,
    required this.onDelete,
  });

  final SourcePlugin source;
  final Color primaryColor;
  final Color secondaryColor;
  final VoidCallback onToggleEnabled;
  final VoidCallback onAuthPressed;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final authBg = source.connected
        ? const Color(0xFF10B981).withValues(alpha: 0.18)
        : primaryColor.withValues(alpha: 0.08);
    final authFg = source.connected ? const Color(0xFF10B981) : secondaryColor;

    return SquircleCard(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            source.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: source.enabled
                                  ? primaryColor
                                  : secondaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: authBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            source.connected ? '已授权' : '未授权',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: authFg,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'v${source.version} · ${source.tierLabel}${source.enabled ? '' : ' · 已停用'}',
                      style: TextStyle(fontSize: 12, color: secondaryColor),
                    ),
                    if (source.importUrl != null &&
                        source.importUrl!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        source.importUrl!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: secondaryColor),
                      ),
                    ],
                  ],
                ),
              ),
              Switch(
                value: source.enabled,
                onChanged: (_) => onToggleEnabled(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              FilledButton.tonal(
                onPressed: onAuthPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: authBg,
                  foregroundColor: authFg,
                ),
                child: Text(source.connected ? '退出 / 取消授权' : 'OAuth 登录'),
              ),
              const Spacer(),
              IconButton(
                tooltip: '删除音源',
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: const Color(0xFFEF4444).withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shared OAuth / Sidecar login trigger for a [SourcePlugin].
Future<void> handleSourceAuthAction(
  BuildContext context,
  PlayerNotifier notifier,
  SourcePlugin source,
) async {
  if (source.id == 'huawei' && !source.connected) {
    final ok = await notifier.loginSidecar(
      onWebViewOpen: (url, scheme, host) => showSidecarWebViewLoginDialog(
        context,
        url: url,
        callbackScheme: scheme,
        callbackHost: host,
      ),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Sidecar OAuth 登录成功' : 'Sidecar 登录未完成')),
      );
    }
    return;
  }
  if (source.connected) {
    notifier.toggleOAuth(source.id);
  } else {
    await showOAuthPkceSheet(context, notifier, source);
  }
}

/// Shared dialog supporting importing community JS plugins from URL or script/JSON.
Future<void> showImportPluginDialog(
  BuildContext context,
  PlayerNotifier notifier,
) async {
  final urlController = TextEditingController();
  final scriptController = TextEditingController();
  final payload = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('导入社区 JS 音源'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: '插件 URL（支持 http / https 远程导入）',
                  hintText: 'https://example.com/music-source.js',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: scriptController,
                maxLines: 6,
                minLines: 4,
                decoration: const InputDecoration(
                  labelText: '或粘贴 JS 脚本 / JSON 清单（URL 留空时生效）',
                  hintText:
                      '// @id custom_source\n// @name 自定义音源\n// @version 1.0.0\n// @apiBase https://api.example.com',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final urlText = urlController.text.trim();
            final scriptText = scriptController.text.trim();
            Navigator.of(
              dialogContext,
            ).pop(urlText.isNotEmpty ? urlText : scriptText);
          },
          child: const Text('导入插件'),
        ),
      ],
    ),
  );
  urlController.dispose();
  scriptController.dispose();
  if (payload == null || payload.isEmpty) return;

  final ok = await notifier.importPluginScript(payload);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(ok ? 'JS 音源导入成功' : '导入失败，请检查远程 URL 连通性或 JS / JSON 格式'),
    ),
  );
}

/// Shared OAuth2 PKCE token entry & browser launch sheet.
Future<void> showOAuthPkceSheet(
  BuildContext context,
  PlayerNotifier notifier,
  SourcePlugin source,
) async {
  final verifier = OAuthPkceHelper.generateCodeVerifier();
  final challenge = OAuthPkceHelper.generateCodeChallenge(verifier);
  final authUri = OAuthPkceHelper.buildAuthorizeUri(
    authorizeUrl: 'https://auth.auramusic.dev/${source.id}/oauth/authorize',
    clientId: 'lite_music_${source.id}',
    redirectUri: 'litemusic://oauth/callback',
    codeChallenge: challenge,
    state: source.id,
  );
  final tokenController = TextEditingController();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
      final primaryColor = isDark ? Colors.white : const Color(0xFF0F172A);
      final secondaryColor = primaryColor.withValues(alpha: 0.68);
      return Padding(
        padding: EdgeInsets.fromLTRB(
          12,
          0,
          12,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 12,
        ),
        child: SquircleCard(
          radius: 26,
          blurSigma: 30,
          backgroundColor: isDark
              ? const Color(0xFF0F172A).withValues(alpha: 0.92)
              : Colors.white.withValues(alpha: 0.96),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${source.name} · OAuth2 PKCE 授权',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '授权地址 (S256 PKCE)：',
                style: TextStyle(fontSize: 12, color: secondaryColor),
              ),
              const SizedBox(height: 4),
              SelectableText(
                authUri.toString(),
                style: TextStyle(fontSize: 11.5, color: secondaryColor),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tokenController,
                decoration: const InputDecoration(
                  labelText: 'Access Token（必填）',
                  hintText: '请完成浏览器授权后粘贴有效 Access Token',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (Platform.isWindows)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Process.run('rundll32', [
                            'url.dll,FileProtocolHandler',
                            authUri.toString(),
                          ]);
                        },
                        icon: const Icon(
                          Icons.open_in_browser_rounded,
                          size: 16,
                        ),
                        label: const Text('打开授权页'),
                      ),
                    ),
                  if (Platform.isWindows) const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        final token = tokenController.text.trim();
                        if (token.isEmpty) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(content: Text('请先填写有效 Token 再确认授权')),
                          );
                          return;
                        }
                        await notifier.authorizeOAuth(source.id, token: token);
                        if (!sheetContext.mounted) return;
                        Navigator.of(sheetContext).pop();
                      },
                      child: const Text('保存 Token 并授权'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  tokenController.dispose();
}

/// Shared dialog to connect a Windows desktop Sidecar source executable.
Future<void> showSidecarDialog(
  BuildContext context,
  PlayerNotifier notifier,
) async {
  final controller = TextEditingController(
    text: r'D:\code\Music\docs\huawei-1.0.0-windows-x64\bin\huawei-source.exe',
  );
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('接入 Windows Sidecar 音源'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          labelText: '可执行文件路径',
          hintText: r'...\bin\huawei-source.exe',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () async {
            final ok = await notifier.connectSidecar(
              controller.text.trim(),
              onWebViewOpen: (url, scheme, host) =>
                  showSidecarWebViewLoginDialog(
                    context,
                    url: url,
                    callbackScheme: scheme,
                    callbackHost: host,
                  ),
            );
            if (!dialogContext.mounted) return;
            Navigator.of(dialogContext).pop();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(ok ? 'Sidecar 音源已连接，请点击 OAuth 登录' : '启动失败，请检查路径'),
              ),
            );
          },
          child: const Text('连接'),
        ),
      ],
    ),
  );
  controller.dispose();
}
