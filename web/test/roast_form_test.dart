import 'package:brewtrack_web/edit_dialog.dart';
import 'package:brewtrack_web/roast_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('el formulario de tueste muestra la merma en vivo', (t) async {
    await t.pumpWidget(MaterialApp(
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
    ));
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();

    final input = find.widgetWithText(TextFormField, 'Kg verde (entrada)');
    final output = find.widgetWithText(TextFormField, 'Kg tostado (salida)');

    expect(find.text('Merma: —'), findsOneWidget);
    await t.enterText(input, '10');
    await t.enterText(output, '8.5');
    await t.pump();
    expect(find.text('Merma: 15.0 %'), findsOneWidget);

    await t.enterText(input, '0'); // peso en cero: no debe romper ni dividir por cero
    await t.pump();
    expect(find.text('Merma: —'), findsOneWidget);

    await t.enterText(input, '5'); // salida mayor que entrada
    await t.pump();
    expect(find.text('Merma: —'), findsOneWidget);
  });
}
