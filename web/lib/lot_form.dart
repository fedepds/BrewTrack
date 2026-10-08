import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'edit_dialog.dart';
import 'models.dart';
import 'providers.dart';

const _lotFields = [
  FieldSpec('code', 'Código (ej. GL-2026-001)'),
  FieldSpec('origin_country', 'País de origen'),
  FieldSpec('region', 'Región', required: false),
  FieldSpec('farm', 'Finca', required: false),
  FieldSpec('producer', 'Productor', required: false),
  FieldSpec('variety', 'Variedad'),
  FieldSpec('process', 'Proceso (lavado, natural, honey…)'),
  FieldSpec('altitude_m', 'Altitud (msnm)', kind: Kind.integer, required: false),
  FieldSpec('harvest_year', 'Año de cosecha', kind: Kind.integer),
  FieldSpec('received_at', 'Fecha de recepción', kind: Kind.date),
  FieldSpec('received_kg', 'Kg recibidos', kind: Kind.decimal),
  FieldSpec('notes', 'Notas', kind: Kind.multiline, required: false),
];

Map<String, dynamic> _lotInitial(Lot l) => {
      'code': l.code,
      'origin_country': l.originCountry,
      'region': l.region,
      'farm': l.farm,
      'producer': l.producer,
      'variety': l.variety,
      'process': l.process,
      'altitude_m': l.altitudeM,
      'harvest_year': l.harvestYear,
      'received_at': l.receivedAt,
      'received_kg': l.receivedKg,
      'notes': l.notes,
    };

/// Alta (lot == null) o edición de un lote.
Future<void> editLot(BuildContext context, WidgetRef ref, [Lot? lot]) async {
  final api = ref.read(apiProvider);
  final saved = await showEditDialog(
    context,
    title: lot == null ? 'Nuevo lote' : 'Editar ${lot.code}',
    fields: _lotFields,
    initial: lot == null ? const {} : _lotInitial(lot),
    onSubmit: (v) => lot == null ? api.send('POST', '/green-lots', v) : api.send('PATCH', '/green-lots/${lot.id}', v),
  );
  if (saved) {
    ref.invalidate(lotsProvider);
    ref.invalidate(lotProvider);
  }
}
