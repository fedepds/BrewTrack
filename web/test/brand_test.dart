import 'dart:io';

import 'package:brewtrack_web/api.dart';
import 'package:brewtrack_web/brand.dart';
import 'package:brewtrack_web/edit_dialog.dart';
import 'package:brewtrack_web/login_screen.dart';
import 'package:brewtrack_web/lots_screen.dart';
import 'package:brewtrack_web/stats_screen.dart';
import 'package:brewtrack_web/users_screen.dart';
import 'package:brewtrack_web/models.dart';
import 'package:brewtrack_web/providers.dart';
import 'package:brewtrack_web/roast_detail_screen.dart';
import 'package:brewtrack_web/roast_form.dart';
import 'package:brewtrack_web/roasts_screen.dart';
import 'package:brewtrack_web/lot_detail_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shell_test.dart' show FakeAuth, admin, setWidth;

Lot lot({double received = 100, double stock = 50, String code = 'GL-2026-014'}) => Lot.fromJson({
  'id': 'l1',
  'code': code,
  'origin_country': 'Colombia',
  'variety': 'Caturra',
  'process': 'Lavado',
  'harvest_year': 2026,
  'received_at': '2026-01-01',
  'received_kg': received,
  'stock_kg': stock,
});

Roast roast(String level) => Roast.fromJson({
  'id': 'r1',
  'lot_id': 'l1',
  'lot_code': 'GL-2026-014',
  'roaster_id': '2',
  'roaster_name': 'Ada',
  'roasted_at': '2026-02-01T10:00:00Z',
  'green_in_kg': 10,
  'roasted_out_kg': 8.5,
  'loss_pct': 15,
  'duration_s': 600,
  'drop_temp_c': 200,
  'roast_level': level,
});

Future<void> pumpIn(
  WidgetTester t,
  Widget child, {
  Brightness b = Brightness.light,
  List<Override> o = const [],
}) async {
  setWidth(t, 800);
  await t.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: o,
      child: MaterialApp(
        theme: brandTheme(b),
        home: Scaffold(body: child),
      ),
    ),
  );
  await t.pumpAndSettle();
}

Color fill(WidgetTester t, String key) =>
    (t.widget<Container>(find.byKey(Key(key))).decoration as BoxDecoration).color!;

final lotOverrides = [authProvider.overrideWith(() => FakeAuth(admin))];

void main() {
  testWidgets('CA-6: chip de nivel con nombre y punto de color, en lista y detalle', (t) async {
    for (final (level, name, color) in [
      ('light', 'Claro', 0xFFB5793F),
      ('medium', 'Medio', 0xFF7A4A2A),
      ('dark', 'Oscuro', 0xFF3A2318),
    ]) {
      await pumpIn(
        t,
        const RoastsScreen(),
        o: [
          ...lotOverrides,
          lotsProvider.overrideWith((ref, f) async => [lot()]),
          roastsProvider.overrideWith((ref, f) async => [roast(level)]),
        ],
      );
      expect(find.text(name), findsOneWidget);
      expect(fill(t, 'level-dot'), Color(color));

      await pumpIn(
        t,
        const RoastDetailScreen('r1'),
        o: [
          ...lotOverrides,
          roastProvider.overrideWith(
            (ref, id) async => RoastDetail.fromJson({
              ...{
                'id': 'r1',
                'lot_id': 'l1',
                'lot_code': 'GL-2026-014',
                'roaster_id': '2',
                'roaster_name': 'Ada',
                'roasted_at': '2026-02-01T10:00:00Z',
                'green_in_kg': 10,
                'roasted_out_kg': 8.5,
                'loss_pct': 15,
                'duration_s': 600,
                'drop_temp_c': 200,
                'roast_level': level,
              },
              'lot': {
                'id': 'l1',
                'code': 'GL-2026-014',
                'origin_country': 'Colombia',
                'variety': 'Caturra',
                'process': 'Lavado',
                'harvest_year': 2026,
                'received_at': '2026-01-01',
                'received_kg': 100,
                'stock_kg': 50,
              },
            }),
          ),
        ],
      );
      expect(find.text(name), findsOneWidget);
      expect(fill(t, 'level-dot'), Color(color));
    }
  });

  testWidgets('CA-6: el punto Oscuro se distingue de la superficie (3:1) en los dos temas', (t) async {
    const surfaces = {Brightness.light: Color(0xFFF8F9F3), Brightness.dark: Color(0xFF241D17)};
    for (final b in Brightness.values) {
      await pumpIn(t, const LevelChip('dark'), b: b);
      expect(fill(t, 'level-dot'), const Color(0xFF3A2318));
      final border =
          ((t.widget<Container>(find.byKey(const Key('level-dot'))).decoration as BoxDecoration).border as Border)
              .top
              .color;
      expect(contrast(border, surfaces[b]!), greaterThanOrEqualTo(3));
    }
  });

  test('CA-16: ningún texto de lib usa caracteres sin fuente empaquetada (flecha)', () {
    // Public Sans no trae U+2192; Flutter pediría una fuente a fonts.gstatic.com.
    for (final f in Directory('lib').listSync().whereType<File>()) {
      final code = f.readAsLinesSync().where((l) => !l.trimLeft().startsWith('///'));
      expect(code.any((l) => l.contains('\u2192')), isFalse, reason: f.path);
    }
  });

  testWidgets('CA-7: barra al 50 % con cifra y texto para lectores de pantalla', (t) async {
    final h = t.ensureSemantics();
    await pumpIn(t, StockBar(lot(received: 60, stock: 30)));
    expect(find.text('30,0 kg'), findsOneWidget);
    expect(
      t
          .widget<FractionallySizedBox>(
            find.ancestor(of: find.byKey(const Key('stock-fill')), matching: find.byType(FractionallySizedBox)),
          )
          .widthFactor,
      0.5,
    );
    expect(find.bySemanticsLabel('Quedan 50 % de lo recibido'), findsOneWidget);
    h.dispose();
  });

  testWidgets('CA-7: la lista y el detalle del lote muestran la barra', (t) async {
    await pumpIn(
      t,
      const LotsScreen(),
      o: [
        lotsProvider.overrideWith((ref, f) async => [lot(received: 60, stock: 30)]),
      ],
    );
    expect(find.text('30,0 kg'), findsOneWidget);
    await pumpIn(
      t,
      const LotDetailScreen('l1'),
      o: [
        ...lotOverrides,
        lotProvider.overrideWith(
          (ref, id) async => LotDetail.fromJson({
            'id': 'l1',
            'code': 'GL-1',
            'origin_country': 'Colombia',
            'variety': 'Caturra',
            'process': 'Lavado',
            'harvest_year': 2026,
            'received_at': '2026-01-01',
            'received_kg': 60,
            'stock_kg': 30,
            'roasts': [],
          }),
        ),
      ],
    );
    expect(find.text('30,0 kg'), findsOneWidget);
  });

  testWidgets('CA-8 y CA-8b: aviso bajo el 15 % con contraste de 3:1 o más', (t) async {
    const surfaces = {
      Brightness.light: [Color(0xFFF8F9F3), Color(0xFFEEF0E6)],
      Brightness.dark: [Color(0xFF241D17), Color(0xFF1A1511)],
    };
    for (final b in Brightness.values) {
      await pumpIn(t, StockBar(lot(stock: 14)), b: b);
      expect(fill(t, 'stock-fill'), const Color(0xFFD6BE6E));
      final border =
          ((t.widget<Container>(find.byKey(const Key('stock-fill'))).decoration as BoxDecoration).border as Border)
              .top
              .color;
      for (final s in surfaces[b]!) {
        expect(contrast(border, s), greaterThanOrEqualTo(3));
      }
      await pumpIn(t, StockBar(lot(stock: 15)), b: b);
      expect(fill(t, 'stock-fill'), isNot(const Color(0xFFD6BE6E)));
    }
  });

  Future<void> openRoastForm(WidgetTester t) async {
    setWidth(t, 800);
    await t.pumpWidget(
      MaterialApp(
        theme: brandTheme(Brightness.light),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showEditDialog(
                context,
                title: 'Tueste',
                fields: roastFields(const {'a': 'Lote A'}),
                footer: roastLossFooter,
                onSubmit: (_) async {},
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
  }

  double factor(WidgetTester t, String key) => t
      .widget<FractionallySizedBox>(
        find.ancestor(of: find.byKey(Key(key)), matching: find.byType(FractionallySizedBox)),
      )
      .widthFactor!;

  testWidgets('CA-9: barras Entra y Sale con el color del nivel', (t) async {
    await openRoastForm(t);
    expect(find.text('Entra'), findsNothing);
    await t.enterText(find.widgetWithText(TextFormField, 'Kg verde (entrada)'), '10');
    await t.enterText(find.widgetWithText(TextFormField, 'Kg tostado (salida)'), '8.5');
    await t.tap(find.byType(DropdownButtonFormField<String>).last);
    await t.pumpAndSettle();
    await t.tap(find.text('Oscuro').last);
    await t.pumpAndSettle();
    expect(find.text('Entra'), findsOneWidget);
    expect(find.text('Sale'), findsOneWidget);
    expect(factor(t, 'bar-in'), 1);
    expect(factor(t, 'bar-out'), closeTo(0.85, 1e-9));
    expect(fill(t, 'bar-out'), const Color(0xFF3A2318));
    expect(find.text('Merma: 15,0 %'), findsOneWidget);
  });

  testWidgets('CA-10: aviso cuando sale más de lo que entra', (t) async {
    await openRoastForm(t);
    await t.enterText(find.widgetWithText(TextFormField, 'Kg verde (entrada)'), '10');
    await t.enterText(find.widgetWithText(TextFormField, 'Kg tostado (salida)'), '11');
    await t.pump();
    expect(find.text('Sale más café del que entra'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('CA-11: sin resultados con filtros, Quitar filtros recarga sin filtros', (t) async {
    final asked = <LotFilter>[];
    await pumpIn(
      t,
      const LotsScreen(),
      o: [
        lotsProvider.overrideWith((ref, f) async {
          asked.add(f);
          return [];
        }),
      ],
    );
    expect(find.text('Aún no hay lotes'), findsOneWidget); // CA-12
    await t.enterText(find.widgetWithText(TextField, 'País'), 'Narnia');
    await t.tap(find.text('Filtrar'));
    await t.pumpAndSettle();
    expect(find.text('Ningún lote coincide con estos filtros'), findsOneWidget);
    await t.tap(find.text('Quitar filtros'));
    await t.pumpAndSettle();
    expect(t.widget<TextField>(find.widgetWithText(TextField, 'País')).controller!.text, '');
    expect(asked.last, (country: '', process: ''));
    expect(find.text('Aún no hay lotes'), findsOneWidget);
  });

  testWidgets('CA-11 y CA-12: lista de tuestes vacía', (t) async {
    final asked = <RoastFilter>[];
    await pumpIn(
      t,
      const RoastsScreen(),
      o: [
        lotsProvider.overrideWith((ref, f) async => []),
        roastsProvider.overrideWith((ref, f) async {
          asked.add(f);
          return [];
        }),
      ],
    );
    expect(find.text('Aún no hay tuestes'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Nuevo tueste'), findsOneWidget);
    await t.tap(find.byType(DropdownButton<String>).last);
    await t.pumpAndSettle();
    await t.tap(find.text('Claro').last);
    await t.pumpAndSettle();
    expect(find.text('Ningún tueste coincide con estos filtros'), findsOneWidget);
    await t.tap(find.text('Quitar filtros'));
    await t.pumpAndSettle();
    expect(asked.last, (lotId: '', level: '', from: '', to: ''));
    expect(find.text('Aún no hay tuestes'), findsOneWidget);
  });

  testWidgets('CA-12: el botón de lista vacía abre el formulario de alta', (t) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await pumpIn(
      t,
      const LotsScreen(),
      o: [
        apiProvider.overrideWithValue(Api(prefs, dio: Dio(BaseOptions(baseUrl: 'http://localhost')))),
        lotsProvider.overrideWith((ref, f) async => []),
      ],
    );
    await t.tap(find.widgetWithText(OutlinedButton, 'Nuevo lote'));
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('RF-29: la lista de lotes cabe en 400 px', (t) async {
    setWidth(t, 400);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          lotsProvider.overrideWith((ref, f) async => [lot(stock: 14)]),
        ],
        child: MaterialApp(
          theme: brandTheme(Brightness.dark),
          home: const Scaffold(body: LotsScreen()),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('14,0 kg'), findsOneWidget);
  });

  Map<String, dynamic> roastJson({double temp = 205.5}) => {
    'id': 'r1',
    'lot_id': 'l1',
    'lot_code': 'GL-2026-014',
    'roaster_id': '2',
    'roaster_name': 'Ada',
    'roasted_at': '2026-02-01T10:00:00Z',
    'green_in_kg': 10,
    'roasted_out_kg': 8.5,
    'loss_pct': 15,
    'duration_s': 600,
    'drop_temp_c': temp,
    'roast_level': 'medium',
  };
  Map<String, dynamic> lotJson() => {
    'id': 'l1',
    'code': 'GL-2026-014',
    'origin_country': 'Colombia',
    'variety': 'Caturra',
    'process': 'Lavado',
    'harvest_year': 2026,
    'received_at': '2026-01-01',
    'received_kg': 10,
    'stock_kg': 10,
  };

  List<String> allTexts(WidgetTester t) => [
    for (final w in t.widgetList<Text>(find.byType(Text))) w.data ?? w.textSpan?.toPlainText() ?? '',
  ];

  testWidgets('CA-9b: coma decimal en lotes, tuestes y formulario, sin separador de miles', (t) async {
    final shown = <String>[];
    final screens = <(Widget, List<Override>)>[
      (
        const LotsScreen(),
        [
          lotsProvider.overrideWith((ref, f) async => [Lot.fromJson(lotJson())]),
        ],
      ),
      (
        const LotDetailScreen('l1'),
        [
          lotProvider.overrideWith(
            (ref, id) async => LotDetail.fromJson({
              ...lotJson(),
              'roasts': [roastJson()],
            }),
          ),
        ],
      ),
      (
        const RoastsScreen(),
        [
          lotsProvider.overrideWith((ref, f) async => [Lot.fromJson(lotJson())]),
          roastsProvider.overrideWith((ref, f) async => [Roast.fromJson(roastJson())]),
        ],
      ),
      (
        const RoastDetailScreen('r1'),
        [
          roastProvider.overrideWith((ref, id) async => RoastDetail.fromJson({...roastJson(), 'lot': lotJson()})),
        ],
      ),
    ];
    for (final (w, o) in screens) {
      await pumpIn(t, w, o: [...lotOverrides, ...o]);
      shown.addAll(allTexts(t));
    }
    final text = shown.join('\n');
    for (final x in ['10,0 kg', '8,5 kg', '15,0 %', '205,5 °C']) {
      expect(text, contains(x));
    }
    expect(text, isNot(contains('10.000 kg')));
    expect(text, isNot(matches(RegExp(r'\d\.\d'))));

    await openRoastForm(t);
    await t.enterText(find.widgetWithText(TextFormField, 'Kg verde (entrada)'), '10');
    for (final out in ['8,5', '8.5']) {
      await t.enterText(find.widgetWithText(TextFormField, 'Kg tostado (salida)'), out);
      await t.pump();
      expect(find.text('Merma: 15,0 %'), findsOneWidget);
    }
  });

  testWidgets('CA-17: foco visible en las filas de la tabla de tuestes', (t) async {
    for (final b in Brightness.values) {
      await pumpIn(
        t,
        const RoastsScreen(),
        b: b,
        o: [
          ...lotOverrides,
          lotsProvider.overrideWith((ref, f) async => [Lot.fromJson(lotJson())]),
          roastsProvider.overrideWith((ref, f) async => [Roast.fromJson(roastJson())]),
        ],
      );
      Iterable<Color> rings() => [
        for (final r in t.widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(DataTable),
            matching: find.descendant(of: find.byType(FocusRing), matching: find.byType(DecoratedBox)),
          ),
        ))
          (r.decoration as BoxDecoration).border!.top.color,
      ].where((c) => c.a > 0);
      Focus.of(
        t.element(find.descendant(of: find.byType(DataTable), matching: find.byType(FocusRing)).first),
      ).requestFocus();
      await t.pump();
      expect(rings(), isNotEmpty, reason: '$b');
      final theme = brandTheme(b);
      expect(contrast(rings().first, theme.colorScheme.surface), greaterThanOrEqualTo(3));
      expect(contrast(rings().first, theme.scaffoldBackgroundColor), greaterThanOrEqualTo(3));
    }
  });

  testWidgets('CA-19: las demás pantallas caben en 400 px', (t) async {
    final summary = Summary.fromJson({
      'month': '2026-10',
      'lots_in_stock': 7,
      'stock_kg': '412.500',
      'received': {'lots': 2, 'kg': '120.000'},
      'roasted': {'roasts': 18, 'green_kg': '95.000', 'roasted_kg': '80.750'},
      'loss_pct': '15.00',
    });
    final screens = <(String, Widget, List<Override>)>[
      (
        'tuestes',
        const RoastsScreen(),
        [
          lotsProvider.overrideWith((ref, f) async => [Lot.fromJson(lotJson())]),
          roastsProvider.overrideWith((ref, f) async => [Roast.fromJson(roastJson())]),
        ],
      ),
      ('resumen', const StatsScreen(), [summaryProvider.overrideWith((ref, m) async => summary)]),
      (
        'usuarios',
        const UsersScreen(),
        [
          usersProvider.overrideWith(
            (ref) async => [
              admin,
              const User(
                id: '3',
                email: 'maria.fernanda.de.los.angeles@example.com',
                name: 'Maria Fernanda de los Angeles',
                role: 'roaster',
                active: true,
              ),
            ],
          ),
        ],
      ),
      (
        'detalle de lote',
        const LotDetailScreen('l1'),
        [
          lotProvider.overrideWith(
            (ref, id) async => LotDetail.fromJson({
              ...lotJson(),
              'roasts': [roastJson()],
            }),
          ),
        ],
      ),
      (
        'detalle de tueste',
        const RoastDetailScreen('r1'),
        [
          roastProvider.overrideWith((ref, id) async => RoastDetail.fromJson({...roastJson(), 'lot': lotJson()})),
        ],
      ),
      ('login', const LoginScreen(), []),
    ];
    for (final (name, w, o) in screens) {
      setWidth(t, 400);
      await t.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [...lotOverrides, ...o],
          child: MaterialApp(
            theme: brandTheme(Brightness.dark),
            home: Scaffold(body: w),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: name);
    }
  });
}
