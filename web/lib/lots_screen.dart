import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'lot_form.dart';
import 'models.dart';
import 'providers.dart';
import 'util.dart';
import 'widgets.dart';

class LotsScreen extends ConsumerStatefulWidget {
  const LotsScreen({super.key});
  @override
  ConsumerState<LotsScreen> createState() => _LotsScreenState();
}

class _LotsScreenState extends ConsumerState<LotsScreen> {
  final _country = TextEditingController();
  final _process = TextEditingController();
  LotFilter _filter = (country: '', process: '');

  void _apply() => setState(() => _filter = (country: _country.text.trim(), process: _process.text.trim()));

  @override
  void dispose() {
    _country.dispose();
    _process.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: 200,
            child: TextField(
              controller: _country,
              decoration: const InputDecoration(labelText: 'País', border: OutlineInputBorder()),
              onSubmitted: (_) => _apply(),
            ),
          ),
          SizedBox(
            width: 200,
            child: TextField(
              controller: _process,
              decoration: const InputDecoration(labelText: 'Proceso', border: OutlineInputBorder()),
              onSubmitted: (_) => _apply(),
            ),
          ),
          OutlinedButton(onPressed: _apply, child: const Text('Filtrar')),
          FilledButton.icon(
            onPressed: () => editLot(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Nuevo lote'),
          ),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: asyncBody(
            ref.watch(lotsProvider(_filter)),
            (page) => SingleChildScrollView(
              child: ResponsiveTable<Lot>(
                items: page.items,
                columns: const ['Código', 'País', 'Variedad', 'Proceso', 'Recibido', 'Stock'],
                cells: (l) => [l.code, l.originCountry, l.variety, l.process, fmtKg(l.receivedKg), fmtKg(l.stockKg)],
                title: (l) => '${l.code} · ${l.originCountry}',
                subtitle: (l) => '${l.variety} · ${l.process} · stock ${fmtKg(l.stockKg)}',
                onTap: (l) => context.go('/lots/${l.id}'),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
