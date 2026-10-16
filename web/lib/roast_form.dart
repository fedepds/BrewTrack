import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'brand.dart';
import 'edit_dialog.dart';
import 'models.dart';
import 'providers.dart';
import 'util.dart';

List<FieldSpec> roastFields(Map<String, String>? lotOptions) => [
  if (lotOptions != null)
    FieldSpec('lot_id', 'Lote', kind: Kind.select, options: lotOptions),
  const FieldSpec('roasted_at', 'Fecha y hora', kind: Kind.datetime),
  const FieldSpec('green_in_kg', 'Kg verde (entrada)', kind: Kind.decimal),
  const FieldSpec('roasted_out_kg', 'Kg tostado (salida)', kind: Kind.decimal),
  const FieldSpec('duration_s', 'Duración (segundos)', kind: Kind.integer),
  const FieldSpec(
    'drop_temp_c',
    'Temperatura de descarga (°C)',
    kind: Kind.decimal,
  ),
  const FieldSpec(
    'roast_level',
    'Nivel de tueste',
    kind: Kind.select,
    options: roastLevels,
  ),
  const FieldSpec('notes', 'Notas', kind: Kind.multiline, required: false),
];

Widget roastLossFooter(Map<String, dynamic> v) {
  final inKg = (v['green_in_kg'] as num?)?.toDouble();
  final outKg = (v['roasted_out_kg'] as num?)?.toDouble();
  final l = lossPct(inKg, outKg);
  final both = inKg != null && outKg != null && inKg > 0 && outKg > 0;
  final over = both && outKg > inKg;
  Widget bar(String label, double ratio, Color color, Key key) => Row(
    children: [
      SizedBox(width: 48, child: Text(label)),
      Expanded(
        child: RatioBar(ratio: ratio, color: color, fillKey: key),
      ),
    ],
  );
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(l == null ? 'Merma: —' : 'Merma: ${fmtPct(l)}', style: mono),
      if (over) const Text('Sale más café del que entra'),
      if (both) ...[
        const SizedBox(height: 8),
        bar('Entra', 1, Colors.grey.shade600, const Key('bar-in')),
        const SizedBox(height: 6),
        bar(
          'Sale',
          outKg / inKg,
          levelColor(v['roast_level'] as String?),
          const Key('bar-out'),
        ),
      ],
    ],
  );
}

Map<String, dynamic> _roastInitial(Roast r) => {
  'roasted_at': fmtDate(r.roastedAt),
  'green_in_kg': r.greenInKg,
  'roasted_out_kg': r.roastedOutKg,
  'duration_s': r.durationS,
  'drop_temp_c': r.dropTempC,
  'roast_level': r.roastLevel,
  'notes': r.notes,
};

/// Alta (roast == null, con `lotId` opcional preseleccionado) o edición de un tueste.
Future<void> editRoast(
  BuildContext context,
  WidgetRef ref, {
  Roast? roast,
  String? lotId,
}) async {
  final api = ref.read(apiProvider);
  Map<String, String>? lotOptions;
  if (roast == null) {
    final lots = await api.lots();
    lotOptions = {
      for (final l in lots) l.id: '${l.code} · stock ${fmtKg(l.stockKg)}',
    };
  }
  if (!context.mounted) return;
  final saved = await showEditDialog(
    context,
    title: roast == null ? 'Nuevo tueste' : 'Editar tueste',
    fields: roastFields(lotOptions),
    initial: roast == null ? {'lot_id': lotId} : _roastInitial(roast),
    footer: roastLossFooter,
    onSubmit: (v) => roast == null
        ? api.send('POST', '/roasts', v)
        : api.send('PATCH', '/roasts/${roast.id}', v),
  );
  if (saved) {
    ref.invalidate(roastsProvider);
    ref.invalidate(roastProvider);
    ref.invalidate(lotProvider);
    ref.invalidate(lotsProvider);
  }
}
