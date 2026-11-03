import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'brand.dart';
import 'providers.dart';
import 'roast_form.dart';
import 'util.dart';
import 'widgets.dart';

class RoastDetailScreen extends ConsumerWidget {
  const RoastDetailScreen(this.id, {super.key});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final text = Theme.of(context).textTheme;
    return asyncBody(ref.watch(roastProvider(id)), (d) {
      final r = d.roast;
      final l = d.lot;
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text.rich(
            TextSpan(
              style: text.headlineSmall,
              children: [
                const TextSpan(text: 'Tueste de '),
                TextSpan(text: r.lotCode, style: stencil),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('${fmtDate(r.roastedAt)} · por ${r.roasterName}'),
          Text(
            'Entrada ${fmtKg(r.greenInKg)} › salida ${fmtKg(r.roastedOutKg)} · merma ${fmtPct(r.lossPct)}',
            style: mono,
          ),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${r.durationS} s · descarga ${fmtC(r.dropTempC)}',
                style: mono,
              ),
              LevelChip(r.roastLevel),
            ],
          ),
          if (r.notes != null) Text(r.notes!),
          const Divider(height: 32),
          Text('Lote de origen', style: text.titleMedium),
          codeTitle(
            l.code,
            ' · ${l.originCountry} · ${l.region ?? '—'} · ${l.farm ?? '—'}',
          ),
          Text('${l.variety} · ${l.process}'),
          const SizedBox(height: 8),
          Row(children: [const Text('Stock '), StockBar(l)]),
          TextButton(
            onPressed: () => context.go('/lots/${l.id}'),
            child: const Text('Ver lote'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              if (user != null && canEditRoast(user, r))
                OutlinedButton(
                  onPressed: () => editRoast(context, ref, roast: r),
                  child: const Text('Editar'),
                ),
              if (user?.isAdmin ?? false)
                TextButton(
                  onPressed: () async {
                    if (!await confirm(context, '¿Eliminar este tueste?')) return;
                    try {
                      await ref
                          .read(apiProvider)
                          .send('DELETE', '/roasts/${r.id}');
                      ref.invalidate(roastsProvider);
                      ref.invalidate(lotProvider);
                      ref.invalidate(lotsProvider);
                      if (context.mounted) context.go('/roasts');
                    } catch (e) {
                      if (context.mounted) toast(context, e);
                    }
                  },
                  child: const Text('Eliminar'),
                ),
            ],
          ),
        ],
      );
    });
  }
}
