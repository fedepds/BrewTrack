import 'package:brewtrack_web/edit_dialog.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('valida requeridos, muestra error del backend y devuelve true al guardar', (t) async {
    var calls = 0;
    Map<String, dynamic>? sent;
    bool? result;
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (c) => TextButton(
          onPressed: () async => result = await showEditDialog(
            c,
            title: 'T',
            fields: const [FieldSpec('name', 'Nombre'), FieldSpec('kg', 'Kg', kind: Kind.decimal)],
            onSubmit: (v) async {
              calls++;
              sent = v;
              if (calls == 1) {
                throw DioException(
                  requestOptions: RequestOptions(),
                  response: Response(
                    requestOptions: RequestOptions(),
                    data: {'error': {'message': 'Stock insuficiente'}},
                  ),
                );
              }
            },
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();

    await t.tap(find.text('Guardar'));
    await t.pumpAndSettle();
    expect(find.text('Requerido'), findsNWidgets(2));
    expect(calls, 0);

    await t.enterText(find.byType(TextFormField).at(0), 'x');
    await t.enterText(find.byType(TextFormField).at(1), '1,5');
    await t.tap(find.text('Guardar'));
    await t.pumpAndSettle();
    expect(find.text('Stock insuficiente'), findsOneWidget);

    await t.tap(find.text('Guardar'));
    await t.pumpAndSettle();
    expect(sent, {'name': 'x', 'kg': 1.5});
    expect(result, true);
  });
}
