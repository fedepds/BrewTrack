import 'package:brewtrack_web/models.dart';
import 'package:brewtrack_web/providers.dart';
import 'package:brewtrack_web/stats_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Summary _summary(String month, String? loss) => Summary.fromJson({
      'month': month, 'lots_in_stock': 7, 'stock_kg': '412.500',
      'received': {'lots': 2, 'kg': '120.000'},
      'roasted': {'roasts': 18, 'green_kg': '95.000', 'roasted_kg': '80.750'},
      'loss_pct': loss,
    });

/// Mes actual del taller fijo en 2026-10. Devuelve los meses pedidos a la API.
Future<List<String?>> pump(WidgetTester t, {String? loss = '15.00', Object? error}) async {
  final asked = <String?>[];
  await t.pumpWidget(ProviderScope(
    overrides: [
      summaryProvider.overrideWith((ref, month) async {
        asked.add(month);
        if (error != null) throw error;
        return _summary(month ?? '2026-10', loss);
      }),
    ],
    child: const MaterialApp(home: Scaffold(body: StatsScreen())),
  ));
  await t.pumpAndSettle();
  return asked;
}

VoidCallback? _onPressed(WidgetTester t, IconData icon) =>
    t.widget<IconButton>(find.widgetWithIcon(IconButton, icon)).onPressed;

void main() {
  testWidgets('muestra las cinco cifras con formato', (t) async {
    await pump(t);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('412.500 kg'), findsOneWidget);
    expect(find.text('120.000 kg'), findsOneWidget);
    expect(find.text('2 lotes'), findsOneWidget);
    expect(find.text('95.000 kg → 80.750 kg'), findsOneWidget);
    expect(find.text('18 tuestes'), findsOneWidget);
    expect(find.text('15.00 %'), findsOneWidget);
    expect(find.textContaining('hoy'), findsNWidgets(2));
  });

  testWidgets('merma nula se muestra como guion', (t) async {
    await pump(t, loss: null);
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('las flechas cambian de mes; siguiente se desactiva en el mes actual', (t) async {
    final asked = await pump(t);
    expect(find.text('octubre 2026'), findsOneWidget);
    expect(_onPressed(t, Icons.chevron_right), isNull);

    await t.tap(find.byIcon(Icons.chevron_left));
    await t.pumpAndSettle();
    expect(find.text('septiembre 2026'), findsOneWidget);
    expect(asked, contains('2026-09'));
    expect(_onPressed(t, Icons.chevron_right), isNotNull);

    await t.tap(find.byIcon(Icons.chevron_right));
    await t.pumpAndSettle();
    expect(find.text('octubre 2026'), findsOneWidget);
    expect(_onPressed(t, Icons.chevron_right), isNull);
  });

  testWidgets('un error de la API muestra el mensaje del backend', (t) async {
    final ro = RequestOptions();
    await pump(t, error: DioException(requestOptions: ro, response: Response(
      requestOptions: ro, statusCode: 422,
      data: {'error': {'code': 'validation_error', 'message': 'month: formato inválido'}},
    )));
    expect(find.text('month: formato inválido'), findsOneWidget);
    expect(_onPressed(t, Icons.chevron_left), isNull);
  });
}
