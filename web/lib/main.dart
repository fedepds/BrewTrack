import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [prefsProvider.overrideWithValue(prefs)],
    child: const BrewTrackApp(),
  ));
}

class BrewTrackApp extends ConsumerWidget {
  const BrewTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        title: 'BrewTrack',
        theme: ThemeData(colorSchemeSeed: const Color(0xFF6F4E37), useMaterial3: true),
        routerConfig: ref.watch(routerProvider),
      );
}
