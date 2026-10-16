import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';
import 'brand.dart';

Widget asyncBody<T>(AsyncValue<T> v, Widget Function(T) build) => v.when(
  data: build,
  loading: () => const Center(child: CircularProgressIndicator()),
  error: (e, _) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text(apiMessage(e)),
    ),
  ),
);

Future<bool> confirm(BuildContext context, String text) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    ) ??
    false;

void toast(BuildContext context, Object e) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(apiMessage(e))));

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
    this.cardExtra,
    this.empty,
  });
  final List<T> items;
  final List<String> columns;

  /// Cada celda es un String (texto) o un Widget.
  final List<Object> Function(T) cells;
  final Widget Function(T) title;
  final String Function(T) subtitle;
  final void Function(T) onTap;
  final Widget Function(T)? cardExtra; // bajo el subtítulo, solo en tarjetas
  final Widget? empty; // sustituye 'Sin resultados'

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: empty ?? const Text('Sin resultados')),
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < 720) {
          return Column(
            children: [
              for (final i in items)
                Card(
                  child: ListTile(
                    title: title(i),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(subtitle(i)),
                        if (cardExtra != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: cardExtra!(i),
                          ),
                      ],
                    ),
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          );
        }
        return SizedBox(
          width: double.infinity,
          child: DataTable(
            showCheckboxColumn: false,
            columns: [for (final c in columns) DataColumn(label: Text(c))],
            rows: [
              for (final i in items)
                DataRow(
                  onSelectChanged: (_) => onTap(i),
                  cells: [
                    for (final s in cells(i))
                      DataCell(FocusRing(child: s is Widget ? s : Text('$s'))),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Lista vacía: mensaje y una acción (quitar filtros o crear el primero).
class EmptyState extends StatelessWidget {
  const EmptyState(this.message, this.action, this.onAction, {super.key});
  final String message, action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(message),
      const SizedBox(height: 12),
      OutlinedButton(onPressed: onAction, child: Text(action)),
    ],
  );
}
