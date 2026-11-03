import 'package:brewtrack_web/brand.dart';
import 'package:brewtrack_web/models.dart';
import 'package:brewtrack_web/providers.dart';
import 'package:brewtrack_web/shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class FakeAuth extends AuthController {
  FakeAuth(this.u);
  final User? u;
  @override
  Future<User?> build() async => u;
}

const roaster = User(id: '1', email: 'r@x.com', name: 'Rita', role: 'roaster', active: true);
const admin = User(id: '2', email: 'a@x.com', name: 'Ada', role: 'admin', active: true);

/// Ventana de [width] px lógicos (la ventana por defecto, 800, ya es ancha).
void setWidth(WidgetTester t, double width) {
  t.view.physicalSize = Size(width, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<void> pumpShell(
  WidgetTester t,
  User u, {
  double width = 400,
  Widget? lots,
  Brightness brightness = Brightness.light,
  bool reduceMotion = false,
}) async {
  setWidth(t, width);
  final router = GoRouter(
    initialLocation: '/lots',
    routes: [
      ShellRoute(
        builder: (_, _, child) => Shell(child: child),
        routes: [
          GoRoute(path: '/lots', builder: (_, _) => lots ?? const Text('lots-page')),
          GoRoute(path: '/roasts', builder: (_, _) => const Text('roasts-page')),
          GoRoute(path: '/stats', builder: (_, _) => const Text('stats-page')),
          GoRoute(path: '/users', builder: (_, _) => const Text('users-page')),
        ],
      ),
    ],
  );
  await t.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [authProvider.overrideWith(() => FakeAuth(u))],
      child: MaterialApp.router(
        routerConfig: router,
        theme: brandTheme(brightness),
        builder: (c, w) => MediaQuery(
          data: MediaQuery.of(c).copyWith(disableAnimations: reduceMotion),
          child: w!,
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

List<String> labels(WidgetTester t) => [
  for (final d in t.widgetList<NavigationDestination>(find.byType(NavigationDestination))) d.label,
];

Color headerBg(WidgetTester t) => t.widget<ColoredBox>(find.byKey(const Key('header-bg'))).color;
Color headerFg(WidgetTester t) => t.widget<AppBar>(find.byType(AppBar)).foregroundColor!;
String stage(WidgetTester t) => t.widget<Text>(find.byKey(const Key('stage-label'))).data!;

/// Lista larga (más alta que la ventana); devuelve el controlador para mover el scroll.
Widget longList(ScrollController c) => ListView.builder(
  controller: c,
  itemCount: 80,
  itemBuilder: (_, i) => SizedBox(height: 60, child: Text('fila $i')),
);

Future<void> at(WidgetTester t, ScrollController c, double p) async {
  c.jumpTo(c.position.maxScrollExtent * p);
  await t.pump();
}

void main() {
  testWidgets('roaster no ve Usuarios', (t) async {
    await pumpShell(t, const User(id: '1', email: 'r@x.com', name: 'Rita', role: 'roaster', active: true));
    expect(find.text('Lotes'), findsOneWidget);
    expect(find.text('Tuestes'), findsOneWidget);
    expect(find.text('Usuarios'), findsNothing);
  });

  testWidgets('admin ve Usuarios', (t) async {
    await pumpShell(t, const User(id: '2', email: 'a@x.com', name: 'Ada', role: 'admin', active: true));
    expect(find.text('Usuarios'), findsOneWidget);
  });

  testWidgets('roaster ve Resumen después de Tuestes', (t) async {
    await pumpShell(t, const User(id: '1', email: 'r@x.com', name: 'Rita', role: 'roaster', active: true));
    expect(labels(t), ['Lotes', 'Tuestes', 'Resumen']);
  });

  testWidgets('admin ve Resumen entre Tuestes y Usuarios', (t) async {
    await pumpShell(t, const User(id: '2', email: 'a@x.com', name: 'Ada', role: 'admin', active: true));
    expect(labels(t), ['Lotes', 'Tuestes', 'Resumen', 'Usuarios']);
  });

  testWidgets('CA-1/2/3: el encabezado se tuesta con el avance', (t) async {
    final c = ScrollController();
    await pumpShell(t, roaster, lots: longList(c));
    await t.pump();
    expect(headerBg(t), const Color(0xFF9FA57A));
    expect(stage(t), 'Verde');
    await at(t, c, 0.5);
    expect(headerBg(t), const Color(0xFFB5793F));
    expect(stage(t), 'Canela');
    await at(t, c, 1);
    expect(headerBg(t), const Color(0xFF3A2318));
    expect(stage(t), 'Oscuro');
    await at(t, c, 0.55);
    expect(stage(t), 'Canela');
  });

  testWidgets('CA-4: sin scroll el encabezado queda en Verde', (t) async {
    await pumpShell(t, roaster);
    await t.pump();
    expect(headerBg(t), const Color(0xFF9FA57A));
    expect(stage(t), 'Verde');
  });

  testWidgets('CA-5: texto negro o blanco con contraste de 4,5:1 o más', (t) async {
    final c = ScrollController();
    await pumpShell(t, roaster, lots: longList(c));
    await t.pump();
    expect(headerFg(t), const Color(0xFF000000));
    await at(t, c, 1);
    expect(headerFg(t), const Color(0xFFFFFFFF));
    for (var i = 0; i <= 20; i++) {
      await at(t, c, i / 20);
      final bg = headerBg(t), fg = headerFg(t);
      final other = fg == Colors.black ? Colors.white : Colors.black;
      expect(fg == Colors.black || fg == Colors.white, isTrue);
      expect(contrast(fg, bg), greaterThanOrEqualTo(4.5), reason: 'avance ${i / 20}');
      expect(contrast(fg, bg), greaterThanOrEqualTo(contrast(other, bg)));
    }
  });

  testWidgets('CA-13: barra lateral desde 760 px, inferior con menos', (t) async {
    await pumpShell(t, roaster, width: 1024);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await pumpShell(t, roaster, width: 759);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('CA-14: visibilidad por rol en 1024 y 400 px', (t) async {
    for (final w in [1024.0, 400.0]) {
      await pumpShell(t, roaster, width: w);
      expect(
        [
          for (final x in ['Lotes', 'Tuestes', 'Resumen', 'Usuarios']) find.text(x).evaluate().length,
        ],
        [1, 1, 1, 0],
      );
      await pumpShell(t, admin, width: w);
      expect(find.text('Usuarios'), findsOneWidget);
    }
  });

  testWidgets('RF-29: el encabezado cabe en 400 px con un nombre largo', (t) async {
    await pumpShell(
      t,
      const User(id: '3', email: 'x@x.com', name: 'Maria Fernanda de los Angeles', role: 'admin', active: true),
    );
    expect(t.takeException(), isNull);
  });

  /// Anillos de foco activos (borde no transparente) bajo [root].
  List<Color> activeRings(WidgetTester t, Finder root) => [
    for (final r in t.widgetList<FocusRing>(find.descendant(of: root, matching: find.byType(FocusRing))))
      if ((t
                      .widget<DecoratedBox>(
                        find.descendant(of: find.byWidget(r), matching: find.byType(DecoratedBox)).first,
                      )
                      .decoration
                  as BoxDecoration)
              .border!
              .top
              .color
              .a >
          0)
        (t
                    .widget<DecoratedBox>(
                      find.descendant(of: find.byWidget(r), matching: find.byType(DecoratedBox)).first,
                    )
                    .decoration
                as BoxDecoration)
            .border!
            .top
            .color,
  ];

  testWidgets('CA-17: foco visible en barra lateral e inferior con contraste de 3:1 o más, en los dos temas', (
    t,
  ) async {
    for (final b in Brightness.values) {
      for (final (w, nav) in [(1024.0, NavigationRail), (400.0, NavigationBar)]) {
        await t.pumpWidget(const SizedBox()); // suelta el foco de la vuelta anterior
        await pumpShell(t, roaster, width: w, brightness: b);
        final root = find.byType(nav);
        // El foco va al InkWell que contiene el segundo icono (el tab del teclado no avanza en el entorno de pruebas).
        Focus.of(t.element(find.descendant(of: root, matching: find.byType(FocusRing)).at(1))).requestFocus();
        await t.pumpAndSettle();
        final rings = activeRings(t, root);
        expect(rings.length, 1, reason: '$nav $b');
        final theme = brandTheme(b);
        expect(contrast(rings.single, theme.colorScheme.surface), greaterThanOrEqualTo(3));
        expect(contrast(rings.single, theme.scaffoldBackgroundColor), greaterThanOrEqualTo(3));
      }
    }
  });

  testWidgets('CA-18: con reducir movimiento el color del encabezado cambia en el mismo cuadro', (t) async {
    final c = ScrollController();
    await pumpShell(t, roaster, lots: longList(c), reduceMotion: true);
    await t.pump();
    expect(headerBg(t), const Color(0xFF9FA57A));
    c.jumpTo(c.position.maxScrollExtent);
    await t.pump(); // un solo cuadro, sin avanzar el reloj
    expect(headerBg(t), const Color(0xFF3A2318));
    expect(
      find.descendant(of: find.byKey(const Key('header-bg')), matching: find.byType(AnimatedContainer)),
      findsNothing,
    );
  });
}
