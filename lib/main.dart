import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_shell.dart';
import 'core/state/player_provider.dart';

void main() {
  runApp(const ProviderScope(child: AuraMusicApp()));
}

/// Root widget for the AuraMusic application.
class AuraMusicApp extends ConsumerWidget {
  /// Creates an [AuraMusicApp].
  const AuraMusicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
