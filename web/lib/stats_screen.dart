import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';
import 'providers.dart';
import 'util.dart';
import 'widgets.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});
  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  String? _month; // null = mes actual del taller, lo decide la API

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(summaryProvider(null)).valueOrNull?.month;
    final month = _month ?? current;
    final summary = ref.watch(summaryProvider(_month));

    void go(int delta) => setState(() {
          final m = shiftMonth(month!, delta);
          _month = m == current ? null : m;
        });

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
            tooltip: 'Mes anterior',
            icon: const Icon(Icons.chevron_left),
            onPressed: month == null ? null : () => go(-1),
          ),
          SizedBox(
            width: 180,
            child: Text(
              month == null ? '' : monthLabel(month),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: 'Mes siguiente',
            icon: const Icon(Icons.chevron_right),
            onPressed: month == null || month == current ? null : () => go(1),
          ),
        ]),
        const SizedBox(height: 12),
        Expanded(child: SingleChildScrollView(child: asyncBody(summary, _figures))),
      ]),
    );
  }

  Widget _figures(Summary s) => Wrap(spacing: 12, runSpacing: 12, children: [
        _Figure('Lotes con stock (hoy)', '${s.lotsInStock}'),
        _Figure('Stock de verde (hoy)', '${s.stockKg} kg'),
        _Figure('Recibido en el mes', '${s.receivedKg} kg', _count(s.receivedLots, 'lote', 'lotes')),
        _Figure('Tostado en el mes', '${s.greenKg} kg → ${s.roastedKg} kg', _count(s.roasts, 'tueste', 'tuestes')),
        _Figure('Merma media', s.lossPct == null ? '—' : '${s.lossPct} %'),
      ]);
}

String _count(int n, String one, String many) => '$n ${n == 1 ? one : many}';

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value, [this.detail]);
  final String label, value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: 240,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: text.labelLarge),
            const SizedBox(height: 8),
            Text(value, style: text.headlineSmall),
            if (detail != null) Text(detail!, style: text.bodyMedium),
          ]),
        ),
      ),
    );
  }
}
