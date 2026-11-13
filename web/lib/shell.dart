import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'brand.dart';
import 'providers.dart';

class Shell extends ConsumerStatefulWidget {
  const Shell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<Shell> {
  // (pantalla, avance): el avance de otra pantalla cuenta como 0 hasta que la nueva informe el suyo.
  final _progress = ValueNotifier<(String, double)>(('', 0));
  String _here = '';

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  bool _onScroll(Notification n) {
    // Solo el scroll vertical del contenido (profundidad 0); ignora tablas con scroll horizontal.
    final m = switch (n) {
      ScrollNotification(depth: 0) => n.metrics,
      ScrollMetricsNotification() => n.metrics,
      _ => null,
    };
    if (m != null && m.axis == Axis.vertical) {
      final max = m.maxScrollExtent;
      _progress.value = (
        _here,
        max > 0 ? (m.pixels / max).clamp(0.0, 1.0) : 0.0,
      );
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;
    if (user == null) return const SizedBox.shrink();
    final dests = [
      ('/lots', Icons.inventory_2, 'Lotes'),
      ('/roasts', Icons.local_fire_department, 'Tuestes'),
      ('/stats', Icons.bar_chart, 'Resumen'),
      if (user.isAdmin) ('/users', Icons.people, 'Usuarios'),
    ];
    final here = GoRouterState.of(context).matchedLocation;
    _here = here;
    final idx = dests
        .indexWhere((d) => here.startsWith(d.$1))
        .clamp(0, dests.length - 1);
    final wide = MediaQuery.sizeOf(context).width >= 760;
    void go(int i) => context.go(dests[i].$1);
    final body = NotificationListener<Notification>(
      onNotification: _onScroll,
      child: widget.child,
    );
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ValueListenableBuilder(
          valueListenable: _progress,
          builder: (context, v, _) {
            final p = v.$1 == here ? v.$2 : 0.0;
            final bg = stageColor(p);
            final fg = onColor(bg);
            // ColoredBox y no el fondo del AppBar: éste anima el color y el spec pide el mismo cuadro.
            return ColoredBox(
              key: const Key('header-bg'),
              color: bg,
              child: AppBar(
                backgroundColor: Colors.transparent,
                foregroundColor: fg,
                scrolledUnderElevation: 0,
                leading: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Image(image: AssetImage('assets/bean.png')),
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'BrewTrack',
                        overflow: TextOverflow.ellipsis,
                        style: stencil.copyWith(fontSize: 26, color: fg),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      stageName(p),
                      key: const Key('stage-label'),
                      style: TextStyle(fontSize: 13, color: fg),
                    ),
                  ],
                ),
                actions: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 96),
                    child: Center(
                      child: Text(
                        user.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: fg),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Salir',
                    icon: const Icon(Icons.logout),
                    onPressed: () => ref.read(authProvider.notifier).logout(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: idx,
                  onDestinationSelected: go,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final d in dests)
                      NavigationRailDestination(
                        icon: FocusRing(child: Icon(d.$2)),
                        label: Text(d.$3),
                      ),
                  ],
                ),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: idx,
              onDestinationSelected: go,
              destinations: [
                for (final d in dests)
                  NavigationDestination(
                    icon: FocusRing(child: Icon(d.$2)),
                    label: d.$3,
                  ),
              ],
            ),
    );
  }
}
