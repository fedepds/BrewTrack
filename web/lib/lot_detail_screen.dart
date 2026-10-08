import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'lot_form.dart';
import 'models.dart';
import 'providers.dart';
import 'roast_form.dart';
import 'util.dart';
import 'widgets.dart';

class LotDetailScreen extends ConsumerWidget {
  const LotDetailScreen(this.id, {super.key});
  final String id;

  Future<void> _delete(BuildContext context, WidgetRef ref, Lot l) async {
    if (!await confirm(context, '¿Eliminar el lote ${l.code}?')) return;
    try {
      await ref.read(apiProvider).send('DELETE', '/green-lots/${l.id}');
      ref.invalidate(lotsProvider);
      if (context.mounted) context.go('/lots');
    } catch (e) {
      if (context.mounted) toast(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final text = Theme.of(context).textTheme;
    return asyncBody(ref.watch(lotProvider(id)), (d) {
      final l = d.lot;
      return ListView(padding: const EdgeInsets.all(16), children: [
        Text(l.code, style: text.headlineSmall),
        const SizedBox(height: 8),
        Text('${l.originCountry} · ${l.region ?? '—'} · ${l.farm ?? '—'} · ${l.producer ?? '—'}'),
        Text('${l.variety} · ${l.process} · cosecha ${l.harvestYear} · ${l.altitudeM ?? '—'} msnm'),
        Text('Recibido ${l.receivedAt}: ${fmtKg(l.receivedKg)} · Stock: ${fmtKg(l.stockKg)}'),
        if (l.notes != null) Text(l.notes!),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          OutlinedButton(onPressed: () => editLot(context, ref, l), child: const Text('Editar')),
          FilledButton(
            onPressed: () => editRoast(context, ref, lotId: l.id),
            child: const Text('Registrar tueste'),
          ),
          if (user?.isAdmin ?? false)
            TextButton(onPressed: () => _delete(context, ref, l), child: const Text('Eliminar')),
        ]),
        const Divider(height: 32),
        Text('Tuestes', style: text.titleMedium),
        ResponsiveTable<Roast>(
          items: d.roasts,
          columns: const ['Fecha', 'Entrada', 'Salida', 'Merma', 'Nivel', 'Tostador'],
          cells: (r) => [
            fmtDate(r.roastedAt), fmtKg(r.greenInKg), fmtKg(r.roastedOutKg),
            '${r.lossPct.toStringAsFixed(1)} %', roastLevels[r.roastLevel] ?? r.roastLevel, r.roasterName,
          ],
          title: (r) => fmtDate(r.roastedAt),
          subtitle: (r) => '${fmtKg(r.greenInKg)} → ${fmtKg(r.roastedOutKg)} · ${r.lossPct.toStringAsFixed(1)} %',
          onTap: (r) => context.go('/roasts/${r.id}'),
        ),
      ]);
    });
  }
}
