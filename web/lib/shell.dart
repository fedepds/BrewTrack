import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers.dart';

class Shell extends ConsumerWidget {
  const Shell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();
    final dests = [
      ('/lots', Icons.inventory_2, 'Lotes'),
      ('/roasts', Icons.local_fire_department, 'Tuestes'),
      if (user.isAdmin) ('/users', Icons.people, 'Usuarios'),
    ];
    final here = GoRouterState.of(context).matchedLocation;
    final idx = dests.indexWhere((d) => here.startsWith(d.$1)).clamp(0, dests.length - 1);
    return Scaffold(
      appBar: AppBar(
        title: const Text('BrewTrack'),
        actions: [
          Center(child: Text(user.name)),
          IconButton(
            tooltip: 'Salir',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) => context.go(dests[i].$1),
        destinations: [for (final d in dests) NavigationDestination(icon: Icon(d.$2), label: d.$3)],
      ),
    );
  }
}
