import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';
import 'brand.dart';
import 'edit_dialog.dart';
import 'models.dart';
import 'providers.dart';
import 'util.dart';

const withdrawalFields = [
  FieldSpec('kg', 'Kg', kind: Kind.decimal),
  FieldSpec('reason', 'Motivo', kind: Kind.select, options: withdrawalReasons),
  FieldSpec('withdrawn_at', 'Fecha y hora', kind: Kind.datetime),
  FieldSpec('notes', 'Notas', kind: Kind.multiline, required: false),
];

// toString sin el prefijo "Exception:" para que el diálogo muestre solo el texto.
class _StockException implements Exception {
  _StockException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Valida contra el stock tostado disponible (margen 1e-9 por el doble) y hace el POST.
Future<void> submitWithdrawal(Api api, String roastId, double available, Map<String, dynamic> v) async {
  if ((v['kg'] as num) > available + 1e-9) {
    throw _StockException('Stock tostado disponible: ${fmtKg(available)}');
  }
  await api.send('POST', '/roasts/$roastId/withdrawals', v);
}

Future<void> registerWithdrawal(BuildContext context, WidgetRef ref, Roast r) async {
  final api = ref.read(apiProvider);
  final saved = await showEditDialog(
    context,
    title: 'Registrar salida',
    fields: withdrawalFields,
    initial: {'withdrawn_at': fmtDate(DateTime.now()), 'reason': 'sale'},
    footer: (_) => Text('Disponible: ${fmtKg(r.roastedStockKg)}', style: mono),
    onSubmit: (v) => submitWithdrawal(api, r.id, r.roastedStockKg, v),
  );
  if (saved) {
    ref.invalidate(roastProvider);
    ref.invalidate(roastsProvider);
    ref.invalidate(lotProvider);
  }
}

class WithdrawalList extends StatelessWidget {
  const WithdrawalList({super.key, required this.withdrawals, required this.isAdmin, required this.onDelete});
  final List<Withdrawal> withdrawals;
  final bool isAdmin;
  final void Function(Withdrawal) onDelete;

  @override
  Widget build(BuildContext context) {
    if (withdrawals.isEmpty) return const Text('Sin salidas');
    return Column(
      children: [
        for (final w in withdrawals)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('${fmtDate(w.withdrawnAt)} · ${fmtKg(w.kg)} · ${withdrawalReasons[w.reason] ?? w.reason}',
                style: mono),
            subtitle: Text([w.userName, if (w.notes != null) w.notes!].join(' · ')),
            trailing: isAdmin
                ? IconButton(
                    tooltip: 'Eliminar salida',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => onDelete(w),
                  )
                : null,
          ),
      ],
    );
  }
}
