import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'models.dart';
import 'providers.dart';
import 'roast_form.dart';
import 'util.dart';
import 'widgets.dart';

class RoastsScreen extends ConsumerStatefulWidget {
  const RoastsScreen({super.key});
  @override
  ConsumerState<RoastsScreen> createState() => _RoastsScreenState();
}

class _RoastsScreenState extends ConsumerState<RoastsScreen> {
  final _from = TextEditingController();
  final _to = TextEditingController();
  String _lotId = '';
  String _level = '';
  String _fromApplied = '';
  String _toApplied = '';

  void _apply() => setState(() {
        _fromApplied = _from.text.trim();
        _toApplied = _to.text.trim();
      });

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lots = ref.watch(lotsProvider((country: '', process: ''))).valueOrNull?.items ?? const <Lot>[];
    final filter = (lotId: _lotId, level: _level, from: _fromApplied, to: _toApplied);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          DropdownButton<String>(
            value: _lotId,
            items: [
              const DropdownMenuItem(value: '', child: Text('Todos los lotes')),
              for (final l in lots) DropdownMenuItem(value: l.id, child: Text(l.code)),
            ],
            onChanged: (v) => setState(() => _lotId = v ?? ''),
          ),
          DropdownButton<String>(
            value: _level,
            items: [
              const DropdownMenuItem(value: '', child: Text('Todos los niveles')),
              for (final e in roastLevels.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _level = v ?? ''),
          ),
          // ponytail: fechas como texto AAAA-MM-DD; la API responde 422 si el formato es inválido.
          SizedBox(
            width: 170,
            child: TextField(
              controller: _from,
              decoration: const InputDecoration(labelText: 'Desde (AAAA-MM-DD)', border: OutlineInputBorder()),
              onSubmitted: (_) => _apply(),
            ),
          ),
          SizedBox(
            width: 170,
            child: TextField(
              controller: _to,
              decoration: const InputDecoration(labelText: 'Hasta (AAAA-MM-DD)', border: OutlineInputBorder()),
              onSubmitted: (_) => _apply(),
            ),
          ),
          OutlinedButton(onPressed: _apply, child: const Text('Filtrar')),
          FilledButton.icon(
            onPressed: () => editRoast(context, ref, lotId: _lotId.isEmpty ? null : _lotId),
            icon: const Icon(Icons.add),
            label: const Text('Nuevo tueste'),
          ),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: asyncBody(
            ref.watch(roastsProvider(filter)),
            (page) => SingleChildScrollView(
              child: ResponsiveTable<Roast>(
                items: page.items,
                columns: const ['Fecha', 'Lote', 'Entrada', 'Salida', 'Merma', 'Nivel', 'Tostador'],
                cells: (r) => [
                  fmtDate(r.roastedAt), r.lotCode, fmtKg(r.greenInKg), fmtKg(r.roastedOutKg),
                  '${r.lossPct.toStringAsFixed(1)} %', roastLevels[r.roastLevel] ?? r.roastLevel, r.roasterName,
                ],
                title: (r) => '${r.lotCode} · ${fmtDate(r.roastedAt)}',
                subtitle: (r) =>
                    '${fmtKg(r.greenInKg)} → ${fmtKg(r.roastedOutKg)} · ${r.lossPct.toStringAsFixed(1)} % · ${r.roasterName}',
                onTap: (r) => context.go('/roasts/${r.id}'),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
