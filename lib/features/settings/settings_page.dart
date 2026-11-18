import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/source_plugin.dart';
import '../../core/source/js_plugin_bridge.dart';
import '../../core/state/player_provider.dart';
import '../../design_system/squircle_border.dart';
import 'sidecar_webview_dialog.dart';

/// Settings page for music source OAuth plugins and display/playback toggles.
class SettingsPage extends ConsumerWidget {
  /// Creates a [SettingsPage].
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerProvider);
    final notifier = ref.read(playerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryColor = primaryColor.withValues(alpha: 0.64);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '音源插件与 OAuth',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: primaryColor,
                ),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _showSidecarDialog(context, notifier),
              icon: const Icon(Icons.terminal_rounded, size: 16),
              label: const Text('Sidecar'),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: () => _showImportPluginDialog(context, notifier),
              icon: const Icon(Icons.extension_outlined, size: 16),
              label: const Text('+ JS 插件'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SquircleCard(
          radius: 22,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: state.sources.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    '暂未接入音源，请点击上方 Sidecar 或 + JS 插件',
                    style: TextStyle(fontSize: 13, color: secondaryColor),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < state.sources.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: primaryColor.withValues(alpha: 0.08),
                        ),
                      ListTile(
                        title: Text(
                          state.sources[i].name,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: primaryColor,
                          ),
                        ),
                        subtitle: Text(
                          'v${state.sources[i].version} · ${state.sources[i].tierLabel}',
                          style: TextStyle(fontSize: 12, color: secondaryColor),
                        ),
                        trailing: FilledButton.tonal(
                          onPressed: () async {
                            final source = state.sources[i];
                            if (source.id == 'huawei' && !source.connected) {
                              final ok = await notifier.loginSidecar(
                                onWebViewOpen: (url, scheme, host) =>
                                    showSidecarWebViewLoginDialog(
                                      context,
                                      url: url,
                                      callbackScheme: scheme,
                                      callbackHost: host,
                                    ),
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ok
                                          ? 'Sidecar OAuth 登录成功'
                                          : 'Sidecar 登录未完成',
                                    ),
                                  ),
                                );
                              }
                              return;
                            }
                            if (source.connected) {
                              notifier.toggleOAuth(source.id);
                            } else {
                              _showOAuthPkceSheet(context, notifier, source);
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: state.sources[i].connected
                                ? const Color(
                                    0xFF10B981,
                                  ).withValues(alpha: 0.18)
                                : primaryColor.withValues(alpha: 0.1),
                            foregroundColor: state.sources[i].connected
                                ? const Color(0xFF10B981)
                                : primaryColor,
                          ),
                          child: Text(
                            state.sources[i].connected ? '已授权' : 'OAuth 登录',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 26),
        Text(
          '显示与播放',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 12),
        SquircleCard(
          radius: 22,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              _SettingsSwitchTile(
                title: '动态光感雾团',
                subtitle: '随专辑主色调流动的环境光晕背景',
                value: state.ambientEnabled,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                onChanged: (_) => notifier.toggleAmbient(),
              ),
              _divider(primaryColor),
              _SettingsSwitchTile(
                title: '桌面歌词',
                subtitle: '在屏幕顶层悬浮显示实时滚动歌词',
                value: state.desktopLyrics,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                onChanged: (_) => notifier.toggleDesktopLyrics(),
              ),
              _divider(primaryColor),
              _SettingsSwitchTile(
                title: '浅色云感主题',
                subtitle: '切换纯净白昼云感毛玻璃视觉风格',
                value: !state.isDark,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                onChanged: (_) => notifier.toggleTheme(),
              ),
              _divider(primaryColor),
              _SettingsSwitchTile(
                title: '本地音乐智能过滤',
                subtitle: '自动排除通话录音、系统铃声与过短音频',
                value: state.smartLocalFilter,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                onChanged: (_) => notifier.toggleSmartLocalFilter(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _divider(Color primaryColor) {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: primaryColor.withValues(alpha: 0.08),
    );
  }

  Future<void> _showImportPluginDialog(
    BuildContext context,
    PlayerNotifier notifier,
  ) async {
    final controller = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('导入社区 JS 插件'),
        content: TextField(
          controller: controller,
          maxLines: 7,
          minLines: 4,
          decoration: const InputDecoration(
            hintText:
                '// @id custom_source\n// @name 自定义音源\n// @version 1.0.0\n// @apiBase https://api.example.com',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('导入插件'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (raw == null || raw.isEmpty) return;

    final ok = await notifier.importPluginScript(raw);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'JS 插件导入成功' : '插件解析失败，请检查 JS 头部注释或 JSON 格式')),
    );
  }

  Future<void> _showOAuthPkceSheet(
    BuildContext context,
    PlayerNotifier notifier,
    SourcePlugin source,
  ) async {
    final verifier = OAuthPkceHelper.generateCodeVerifier();
    final challenge = OAuthPkceHelper.generateCodeChallenge(verifier);
    final authUri = OAuthPkceHelper.buildAuthorizeUri(
      authorizeUrl: 'https://auth.auramusic.dev/${source.id}/oauth/authorize',
      clientId: 'aura_music_${source.id}',
      redirectUri: 'auramusic://oauth/callback',
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
                    labelText: 'Access Token（可选）',
                    hintText: '粘贴授权回调 Token，或点击下方完成模拟授权',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await notifier.authorizeOAuth(
                            source.id,
                            token: tokenController.text.trim(),
                          );
                          if (!sheetContext.mounted) return;
                          Navigator.of(sheetContext).pop();
                        },
                        child: const Text('保存 Token'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          await notifier.authorizeOAuth(
                            source.id,
                            token: 'pkce_${source.id}_demo_token',
                          );
                          if (!sheetContext.mounted) return;
                          Navigator.of(sheetContext).pop();
                        },
                        child: const Text('完成模拟授权'),
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

  Future<void> _showSidecarDialog(
    BuildContext context,
    PlayerNotifier notifier,
  ) async {
    final controller = TextEditingController(
      text:
          r'D:\code\Music\docs\huawei-1.0.0-windows-x64\bin\huawei-source.exe',
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
                  content: Text(
                    ok ? 'Sidecar 音源已连接，请点击 OAuth 登录' : '启动失败，请检查路径',
                  ),
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
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.primaryColor,
    required this.secondaryColor,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final Color primaryColor;
  final Color secondaryColor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, color: primaryColor),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: secondaryColor),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}
