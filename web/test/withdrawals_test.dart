import 'package:brewtrack_web/api.dart';
import 'package:brewtrack_web/edit_dialog.dart';
import 'package:brewtrack_web/models.dart';
import 'package:brewtrack_web/withdrawals.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAdapter implements HttpClientAdapter {
  final calls = <String>[];
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? body, Future<void>? cancel) async {
    calls.add('${o.method} ${o.path}');
    return ResponseBody.fromString('{}', 201, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

Withdrawal _w() => Withdrawal.fromJson({
      'id': 'w1',
      'roast_id': 'r1',
      'user_id': 'u1',
      'user_name': 'Ana',
      'withdrawn_at': '2026-02-01T10:00:00Z',
      'kg': 1.5,
      'reason': 'sale',
      'notes': 'Cliente X',
    });

Widget _list(bool isAdmin) => MaterialApp(
      home: Scaffold(body: WithdrawalList(withdrawals: [_w()], isAdmin: isAdmin, onDelete: (_) {})),
    );

void main() {
  testWidgets('el botón de borrar salida solo aparece para admin', (t) async {
    await t.pumpWidget(_list(false));
    expect(find.byTooltip('Eliminar salida'), findsNothing);
    expect(find.textContaining('Venta'), findsOneWidget);
    await t.pumpWidget(_list(true));
    expect(find.byTooltip('Eliminar salida'), findsOneWidget);
  });

  testWidgets('sin salidas muestra "Sin salidas"', (t) async {
    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: WithdrawalList(withdrawals: const [], isAdmin: true, onDelete: (_) {}))));
    expect(find.text('Sin salidas'), findsOneWidget);
  });

  testWidgets('salir con todo el stock (2,5) pasa; pasarse por 0,001 no', (t) async {
    SharedPreferences.setMockInitialValues({});
    final adapter = _FakeAdapter();
    final api = Api(await SharedPreferences.getInstance(),
        dio: Dio(BaseOptions(baseUrl: 'http://x'))..httpClientAdapter = adapter);
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showEditDialog(
              context,
              title: 'Registrar salida',
              fields: withdrawalFields,
              initial: const {'reason': 'sale', 'withdrawn_at': '2026-02-01 10:00'},
              footer: (_) => const Text('Disponible: 2,5 kg'),
              onSubmit: (v) => submitWithdrawal(api, 'r1', 2.5, v),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();

    await t.enterText(find.widgetWithText(TextFormField, 'Kg'), '2,501');
    await t.tap(find.text('Guardar'));
    await t.pumpAndSettle();
    expect(find.text('Stock tostado disponible: 2,5 kg'), findsOneWidget);
    expect(adapter.calls, isEmpty);

    await t.enterText(find.widgetWithText(TextFormField, 'Kg'), '2,5');
    await t.tap(find.text('Guardar'));
    await t.pumpAndSettle();
    expect(find.text('Registrar salida'), findsNothing);
    expect(adapter.calls, ['POST /roasts/r1/withdrawals']);
  });
}
