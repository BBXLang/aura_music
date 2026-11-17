import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura_music/design_system/liquid_dock.dart';
import 'package:aura_music/main.dart';

void main() {
  testWidgets('AuraMusicApp boots cleanly with ProviderScope', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: AuraMusicApp()));
    await tester.pump();

    expect(find.text('最近热播'), findsOneWidget);
    expect(find.text('我的歌单'), findsOneWidget);
    expect(find.byType(LiquidDock), findsOneWidget);
  });
}
