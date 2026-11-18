import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura_music/design_system/liquid_dock.dart';
import 'package:aura_music/features/player/desktop_lyrics_overlay.dart';
import 'package:aura_music/features/player/immersive_player_page.dart';
import 'package:aura_music/features/search/search_page.dart';
import 'package:aura_music/features/settings/source_manager_page.dart';
import 'package:aura_music/main.dart';

void main() {
  testWidgets('Switches between 首页, 搜索, and 设置 tabs on mobile', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(420, 840);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: AuraMusicApp()));
    await tester.pump();

    expect(find.text('最近热播'), findsOneWidget);

    await tester.tap(find.text('搜索'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('搜索歌曲、歌手…'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '星云');
    await tester.pump();
    expect(
      find.descendant(of: find.byType(SearchPage), matching: find.text('星云漫游')),
      findsOneWidget,
    );

    await tester.tap(find.text('设置'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('音源插件与 OAuth'), findsOneWidget);
    expect(find.text('动态光感雾团'), findsOneWidget);
    expect(find.text('桌面歌词'), findsOneWidget);
    expect(find.text('浅色云感主题'), findsOneWidget);
    expect(find.text('本地音乐智能过滤'), findsOneWidget);

    // Toggle 桌面歌词 to verify DesktopLyricsOverlay appears.
    await tester.tap(find.text('桌面歌词'));
    await tester.pump();
    expect(find.byType(DesktopLyricsOverlay), findsOneWidget);
  });

  testWidgets(
    'Opens ImmersivePlayerPage from LiquidDock and switches to Lyrics page',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 840);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const ProviderScope(child: AuraMusicApp()));
      await tester.pump();

      await tester.tap(
        find.descendant(
          of: find.byType(LiquidDock),
          matching: find.text('星云漫游'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(ImmersivePlayerPage), findsOneWidget);
      expect(find.text('封面'), findsOneWidget);
      expect(find.text('歌词'), findsWidgets);

      // Tap the top '歌词' indicator dot to switch to the Lyrics slide.
      await tester.tap(find.text('歌词').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('星云在耳畔缓缓铺张'), findsOneWidget);
    },
  );

  testWidgets('Opens QueueSheet and switches to 播放历史 tab', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(420, 840);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: AuraMusicApp()));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.queue_music_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('推荐漫游队列 (16)'), findsOneWidget);
    expect(find.text('播放历史 (0)'), findsOneWidget);

    await tester.tap(find.text('播放历史 (0)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('暂无播放历史，点击任意歌曲开始聆听'), findsOneWidget);
  });

  testWidgets(
    'Navigates from SettingsPage to SourceManagerPage and toggles source',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 840);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const ProviderScope(child: AuraMusicApp()));
      await tester.pump();

      await tester.tap(find.text('设置'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      await tester.tap(find.text('进入音源管理页面'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(SourceManagerPage), findsOneWidget);
      expect(find.text('网易云音源插件'), findsOneWidget);
    },
  );

  testWidgets(
    'SearchPage renders immediate play, play next, and bubble menu actions',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(960, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const ProviderScope(child: AuraMusicApp()));
      await tester.pump();

      await tester.tap(find.text('搜索'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      await tester.enterText(find.byType(TextField), '星云');
      await tester.pump();

      expect(find.byTooltip('立即播放'), findsOneWidget);
      expect(find.byTooltip('下一首播放'), findsOneWidget);
      expect(find.byTooltip('菜单'), findsOneWidget);

      await tester.tap(find.byTooltip('菜单'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('分享'), findsOneWidget);
      expect(find.text('收藏'), findsOneWidget);
      expect(find.text('歌曲信息'), findsOneWidget);
    },
  );
}
