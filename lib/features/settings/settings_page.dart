import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/player_provider.dart';
import '../../design_system/squircle_border.dart';
import 'source_manager_page.dart';

/// Settings page for music source OAuth plugins, source management, and display/playback toggles.
class SettingsPage extends ConsumerWidget {
  /// Creates a [SettingsPage].
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(playerProvider.select((s) => s.sources));
    final ambientEnabled = ref.watch(
      playerProvider.select((s) => s.ambientEnabled),
    );
    final desktopLyrics = ref.watch(
      playerProvider.select((s) => s.desktopLyrics),
    );
    final smartLocalFilter = ref.watch(
      playerProvider.select((s) => s.smartLocalFilter),
    );
    final isDarkState = ref.watch(playerProvider.select((s) => s.isDark));
    final notifier = ref.read(playerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryColor = primaryColor.withValues(alpha: 0.64);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            Text(
              '音源插件与 OAuth',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: primaryColor,
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SourceManagerPage(),
                    ),
                  ),
                  icon: const Icon(Icons.dns_rounded, size: 16),
                  label: const Text('音源管理'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => showSidecarDialog(context, notifier),
                  icon: const Icon(Icons.terminal_rounded, size: 16),
                  label: const Text('Sidecar'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => showImportPluginDialog(context, notifier),
                  icon: const Icon(Icons.extension_outlined, size: 16),
                  label: const Text('导入 JS'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        SquircleCard(
          radius: 22,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.tune_rounded, color: primaryColor),
                ),
                title: Text(
                  '进入音源管理页面',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: primaryColor,
                  ),
                ),
                subtitle: Text(
                  '共 ${sources.length} 个音源 · 支持开启、关闭、授权与删除',
                  style: TextStyle(fontSize: 12, color: secondaryColor),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: secondaryColor,
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SourceManagerPage(),
                  ),
                ),
              ),
              if (sources.isEmpty) ...[
                _divider(primaryColor),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    '暂未接入音源，请点击上方 Sidecar 或导入 JS 插件',
                    style: TextStyle(fontSize: 13, color: secondaryColor),
                  ),
                ),
              ] else
                for (var i = 0; i < sources.length; i++) ...[
                  _divider(primaryColor),
                  ListTile(
                    title: Text(
                      sources[i].name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: sources[i].enabled
                            ? primaryColor
                            : secondaryColor,
                      ),
                    ),
                    subtitle: Text(
                      'v${sources[i].version} · ${sources[i].tierLabel}${sources[i].enabled ? '' : ' · 已关闭'}',
                      style: TextStyle(fontSize: 12, color: secondaryColor),
                    ),
                    trailing: FilledButton.tonal(
                      onPressed: () =>
                          handleSourceAuthAction(context, notifier, sources[i]),
                      style: FilledButton.styleFrom(
                        backgroundColor: sources[i].connected
                            ? const Color(0xFF10B981).withValues(alpha: 0.18)
                            : primaryColor.withValues(alpha: 0.1),
                        foregroundColor: sources[i].connected
                            ? const Color(0xFF10B981)
                            : primaryColor,
                      ),
                      child: Text(
                        sources[i].connected ? '已授权' : 'OAuth 登录',
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
                value: ambientEnabled,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                onChanged: (_) => notifier.toggleAmbient(),
              ),
              _divider(primaryColor),
              _SettingsSwitchTile(
                title: '桌面歌词',
                subtitle: '在屏幕顶层悬浮显示实时滚动歌词',
                value: desktopLyrics,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                onChanged: (_) => notifier.toggleDesktopLyrics(),
              ),
              _divider(primaryColor),
              _SettingsSwitchTile(
                title: '浅色云感主题',
                subtitle: '切换纯净白昼云感毛玻璃视觉风格',
                value: !isDarkState,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                onChanged: (_) => notifier.toggleTheme(),
              ),
              _divider(primaryColor),
              _SettingsSwitchTile(
                title: '本地音乐智能过滤',
                subtitle: '自动排除通话录音、系统铃声与过短音频',
                value: smartLocalFilter,
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
