import 'package:flutter/material.dart';

import 'api.dart';

enum Kind { text, multiline, integer, decimal, date, datetime, select, password }

class FieldSpec {
  const FieldSpec(this.key, this.label, {this.kind = Kind.text, this.required = true, this.options = const {}});
  final String key, label;
  final Kind kind;
  final bool required;
  final Map<String, String> options; // valor -> etiqueta (solo select)
}

/// Muestra un formulario modal. `onSubmit` hace la llamada a la API; si lanza,
/// el mensaje del backend se muestra en el diálogo. Devuelve true si se guardó.
Future<bool> showEditDialog(
  BuildContext context, {
  required String title,
  required List<FieldSpec> fields,
  required Future<void> Function(Map<String, dynamic> values) onSubmit,
  Map<String, dynamic> initial = const {},
  Widget Function(Map<String, dynamic> values)? footer,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => _EditDialog(title: title, fields: fields, initial: initial, onSubmit: onSubmit, footer: footer),
    ) ??
    false;

class _EditDialog extends StatefulWidget {
  const _EditDialog({
    required this.title,
    required this.fields,
    required this.initial,
    required this.onSubmit,
    required this.footer,
  });
  final String title;
  final List<FieldSpec> fields;
  final Map<String, dynamic> initial;
  final Future<void> Function(Map<String, dynamic>) onSubmit;
  final Widget Function(Map<String, dynamic>)? footer;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c = {
    for (final f in widget.fields) f.key: TextEditingController(text: '${widget.initial[f.key] ?? ''}'),
  };
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  dynamic _parse(FieldSpec f) {
    final t = _c[f.key]!.text.trim();
    if (t.isEmpty) return null;
    switch (f.kind) {
      case Kind.integer:
        return int.tryParse(t);
      case Kind.decimal:
        return double.tryParse(t.replaceAll(',', '.'));
      case Kind.datetime:
        return DateTime.tryParse(t)?.toUtc().toIso8601String();
      default:
        return t;
    }
  }

  Map<String, dynamic> get _values => {for (final f in widget.fields) f.key: _parse(f)};

  Future<void> _pick(FieldSpec f) async {
    final now = DateTime.now();
    final d = await showDatePicker(
        context: context, initialDate: now, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (d == null || !mounted) return;
    var text = d.toIso8601String().substring(0, 10);
    if (f.kind == Kind.datetime) {
      final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(now));
      if (t == null) return;
      text += ' ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    setState(() => _c[f.key]!.text = text);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_values);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = apiMessage(e);
          _busy = false;
        });
      }
    }
  }

  Widget _input(FieldSpec f) {
    final c = _c[f.key]!;
    String? validate(String? s) {
      if ((s ?? '').trim().isEmpty) return f.required ? 'Requerido' : null;
      return _parse(f) == null ? 'Valor inválido' : null;
    }

    final deco = InputDecoration(labelText: f.label, border: const OutlineInputBorder());
    switch (f.kind) {
      case Kind.select:
        return DropdownButtonFormField<String>(
          initialValue: f.options.containsKey(c.text) ? c.text : null,
          decoration: deco,
          isExpanded: true,
          items: [for (final e in f.options.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          validator: validate,
          onChanged: (v) => setState(() => c.text = v ?? ''),
        );
      case Kind.date:
      case Kind.datetime:
        return TextFormField(
          controller: c,
          decoration: deco.copyWith(suffixIcon: const Icon(Icons.calendar_today)),
          readOnly: true,
          validator: validate,
          onTap: () => _pick(f),
        );
      default:
        return TextFormField(
          controller: c,
          decoration: deco,
          obscureText: f.kind == Kind.password,
          maxLines: f.kind == Kind.multiline ? 3 : 1,
          validator: validate,
          onChanged: (_) => setState(() {}),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final f in widget.fields) Padding(padding: const EdgeInsets.only(top: 12), child: _input(f)),
              if (widget.footer != null)
                Padding(padding: const EdgeInsets.only(top: 12), child: widget.footer!(_values)),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: _busy ? null : _submit, child: const Text('Guardar')),
      ],
    );
  }
}
