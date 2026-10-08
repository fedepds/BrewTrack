import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';

Widget asyncBody<T>(AsyncValue<T> v, Widget Function(T) build) => v.when(
      data: build,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(apiMessage(e)))),
    );

Future<bool> confirm(BuildContext context, String text) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(content: Text(text), actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar')),
      ]),
    ) ??
    false;

void toast(BuildContext context, Object e) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiMessage(e))));

/// Tabla en pantallas anchas, tarjetas en estrechas. No hace scroll por sí misma.
class ResponsiveTable<T> extends StatelessWidget {
  const ResponsiveTable({
    super.key,
    required this.items,
    required this.columns,
    required this.cells,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final List<T> items;
  final List<String> columns;
  final List<String> Function(T) cells;
  final String Function(T) title, subtitle;
  final void Function(T) onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Sin resultados')));
    }
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < 720) {
        return Column(children: [
          for (final i in items)
            Card(child: ListTile(title: Text(title(i)), subtitle: Text(subtitle(i)), onTap: () => onTap(i))),
        ]);
      }
      return SizedBox(
        width: double.infinity,
        child: DataTable(
          showCheckboxColumn: false,
          columns: [for (final c in columns) DataColumn(label: Text(c))],
          rows: [
            for (final i in items)
              DataRow(onSelectChanged: (_) => onTap(i), cells: [for (final s in cells(i)) DataCell(Text(s))]),
          ],
        ),
      );
    });
  }
}
