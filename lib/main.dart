import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_shell.dart';
import 'core/audio/audio_engine.dart';
import 'core/state/player_provider.dart';
import 'core/storage/app_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await AppStorage.create();
  final AudioEngineAdapter engine = Platform.operatingSystem == 'ohos'
      ? OhosAudioEngine()
      : AudioPlayersEngine();

  runApp(
    ProviderScope(
      overrides: [
        appStorageProvider.overrideWithValue(storage),
        audioEngineProvider.overrideWithValue(engine),
      ],
      child: const AuraMusicApp(),
    ),
  );
}

/// Root widget for the AuraMusic application.
class AuraMusicApp extends ConsumerStatefulWidget {
  /// Creates an [AuraMusicApp].
  const AuraMusicApp({super.key});

  @override
  ConsumerState<AuraMusicApp> createState() => _AuraMusicAppState();
}

class _AuraMusicAppState extends ConsumerState<AuraMusicApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        ref.read(playerProvider.notifier).init();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(playerProvider.select((state) => state.isDark));

    return MaterialApp(
      title: 'AuraMusic',
      debugShowCheckedModeBanner: false,
      theme: isDark
          ? ThemeData.dark(useMaterial3: true)
          : ThemeData.light(useMaterial3: true),
      home: const AuraAppShell(),
    );
  }
}
