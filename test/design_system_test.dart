import 'package:aura_music/design_system/ambient_background.dart';
import 'package:aura_music/design_system/cover_art.dart';
import 'package:aura_music/design_system/liquid_dock.dart';
import 'package:aura_music/design_system/morph_icon.dart';
import 'package:aura_music/design_system/particle_effects.dart';
import 'package:aura_music/design_system/squircle_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const List<Color> testPalette = [
    Color(0xFF6B4EFF),
    Color(0xFF00C2FF),
    Color(0xFFFF4D8D),
  ];

  group('SquircleBorder & SquircleCard', () {
    test('SquircleBorder geometry, copyWith, scale, and lerp', () {
      const SquircleBorder border = SquircleBorder();
      expect(border.radius, 24.0);
      expect(border.side, BorderSide.none);

      final SquircleBorder modified = border.copyWith(
        radius: 32.0,
        side: const BorderSide(color: Colors.white, width: 2.0),
      );
      expect(modified.radius, 32.0);
      expect(modified.side.width, 2.0);

      final SquircleBorder scaled = modified.scale(0.5) as SquircleBorder;
      expect(scaled.radius, 16.0);
      expect(scaled.side.width, 1.0);

      final SquircleBorder? lerped =
          ShapeBorder.lerp(border, modified, 0.5) as SquircleBorder?;
      expect(lerped, isNotNull);
      expect(lerped!.radius, 28.0);
      expect(lerped, isNot(equals(border)));

      const Rect rect = Rect.fromLTWH(0, 0, 120, 120);
      final Path outer = modified.getOuterPath(rect);
      final Path inner = modified.getInnerPath(rect);
      expect(outer.getBounds(), rect);
      expect(inner.getBounds(), rect.deflate(2.0));
      expect(modified.getOuterPath(Rect.zero).getBounds(), Rect.zero);
    });

    testWidgets('SquircleCard renders frosted glass child', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SquircleCard(radius: 28.0, child: Text('Glass Content')),
          ),
        ),
      );

      expect(find.text('Glass Content'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.byType(ClipPath), findsOneWidget);
    });
  });

  group('AmbientBackground', () {
    testWidgets('renders dark and light base colors and toggles enabled', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AmbientBackground(
            colors: testPalette,
            enabled: true,
            isDark: true,
            child: Text('Foreground'),
          ),
        ),
      );

      expect(find.text('Foreground'), findsOneWidget);
      final ColoredBox darkBox = tester.widget<ColoredBox>(
        find.byType(ColoredBox).first,
      );
      expect(darkBox.color, const Color(0xFF000000));
      expect(find.byType(CustomPaint), findsWidgets);

      // Disable ambient fog and switch to light mode.
      await tester.pumpWidget(
        const MaterialApp(
          home: AmbientBackground(
            colors: testPalette,
            enabled: false,
            isDark: false,
            child: Text('Foreground'),
          ),
        ),
      );

      final ColoredBox lightBox = tester.widget<ColoredBox>(
        find.byType(ColoredBox).first,
      );
      expect(lightBox.color, const Color(0xFFFFFFFF));

      // Re-enable to verify controller restart path.
      await tester.pumpWidget(
        const MaterialApp(
          home: AmbientBackground(
            colors: testPalette,
            enabled: true,
            isDark: false,
            child: Text('Foreground'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Foreground'), findsOneWidget);
    });
  });

  group('MorphIcons', () {
    testWidgets('MorphPlayPauseIcon morphs between play and pause', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: MorphPlayPauseIcon(isPlaying: false)),
      );
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(home: MorphPlayPauseIcon(isPlaying: true)),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('MorphLikeIcon morphs between unliked and liked', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: MorphLikeIcon(isLiked: false)),
      );
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(home: MorphLikeIcon(isLiked: true)),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    });

    testWidgets('MorphModeIcon supports loop_list, loop_one, play_once', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: MorphModeIcon(mode: 'loop_list')),
      );
      expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(home: MorphModeIcon(mode: 'loop_one')),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.repeat_one_rounded), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(home: MorphModeIcon(mode: 'play_once')),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.arrow_right_alt_rounded), findsOneWidget);
    });
  });

  group('Particle effects & ConeProgressBar', () {
    testWidgets('CoverParticleHalo animates when playing and pauses on stop', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 240,
            height: 240,
            child: CoverParticleHalo(
              isPlaying: true,
              color: Color(0xFF00C2FF),
              child: SizedBox(width: 160, height: 160),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(CoverParticleHalo), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 240,
            height: 240,
            child: CoverParticleHalo(
              isPlaying: false,
              color: Color(0xFF00C2FF),
              child: SizedBox(width: 160, height: 160),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CoverParticleHalo), findsOneWidget);
    });

    testWidgets('ConeProgressBar supports tap and horizontal drag seek', (
      WidgetTester tester,
    ) async {
      double? soughtValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: ConeProgressBar(
                  progress: 0.35,
                  onSeek: (double value) => soughtValue = value,
                ),
              ),
            ),
          ),
        ),
      );

      final Finder barFinder = find.byType(ConeProgressBar);
      final Rect barRect = tester.getRect(barFinder);

      // Tap at 75% across the bar.
      await tester.tapAt(
        Offset(barRect.left + barRect.width * 0.75, barRect.center.dy),
      );
      expect(soughtValue, isNotNull);
      expect(soughtValue!, closeTo(0.75, 0.02));

      // Drag left past the start edge; value must clamp to 0.0.
      await tester.drag(barFinder, const Offset(-400, 0));
      expect(soughtValue, 0.0);
    });
  });

  group('LiquidDock', () {
    testWidgets('renders track info and triggers action callbacks', (
      WidgetTester tester,
    ) async {
      int tapCount = 0;
      int playPauseCount = 0;
      int nextCount = 0;
      int queueCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LiquidDock(
                  scrollVelocity: 400.0,
                  cover: const ProceduralCoverArt(
                    colors: testPalette,
                    size: 46,
                    radius: 15,
                  ),
                  title: 'Nebula Drift',
                  artist: 'Aura Artist',
                  isPlaying: true,
                  onTap: () => tapCount++,
                  onPlayPause: () => playPauseCount++,
                  onNext: () => nextCount++,
                  onOpenQueue: () => queueCount++,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Nebula Drift'), findsOneWidget);
      expect(find.text('Aura Artist'), findsOneWidget);

      await tester.tap(find.text('Nebula Drift'));
      expect(tapCount, 1);

      await tester.tap(find.byTooltip('Pause'));
      expect(playPauseCount, 1);

      await tester.tap(find.byTooltip('Next'));
      expect(nextCount, 1);

      await tester.tap(find.byTooltip('Queue'));
      expect(queueCount, 1);
    });
  });

  group('ProceduralCoverArt', () {
    testWidgets('renders sized squircle cover with gradient and fallback', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ProceduralCoverArt(colors: testPalette, size: 160, radius: 24),
                ProceduralCoverArt(colors: <Color>[], size: 80, radius: 12),
              ],
            ),
          ),
        ),
      );

      final Iterable<SizedBox> boxes = tester.widgetList<SizedBox>(
        find.descendant(
          of: find.byType(ProceduralCoverArt),
          matching: find.byType(SizedBox),
        ),
      );
      expect(boxes.first.width, 160);
      expect(boxes.first.height, 160);
      expect(boxes.last.width, 80);
      expect(boxes.last.height, 80);
    });
  });
}
