import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/player_provider.dart';
import '../../design_system/squircle_border.dart';

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
        Text(
          '音源插件与 OAuth',
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
                    onPressed: () => notifier.toggleOAuth(state.sources[i].id),
                    style: FilledButton.styleFrom(
                      backgroundColor: state.sources[i].connected
                          ? const Color(0xFF10B981).withValues(alpha: 0.18)
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
