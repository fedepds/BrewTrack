import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'edit_dialog.dart';
import 'models.dart';
import 'providers.dart';
import 'widgets.dart';

const _roles = {'roaster': 'Tostador', 'admin': 'Admin'};

class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final api = ref.read(apiProvider);
    final saved = await showEditDialog(
      context,
      title: 'Nuevo usuario',
      fields: const [
        FieldSpec('email', 'Email'),
        FieldSpec('name', 'Nombre'),
        FieldSpec('password', 'Contraseña (mín. 8)', kind: Kind.password),
        FieldSpec('role', 'Rol', kind: Kind.select, options: _roles),
      ],
      initial: const {'role': 'roaster'},
      onSubmit: (v) => api.send('POST', '/users', v),
    );
    if (saved) ref.invalidate(usersProvider);
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, User u) async {
    final api = ref.read(apiProvider);
    final saved = await showEditDialog(
      context,
      title: 'Editar ${u.email}',
      fields: const [
        FieldSpec('name', 'Nombre'),
        FieldSpec('role', 'Rol', kind: Kind.select, options: _roles),
        FieldSpec('password', 'Nueva contraseña (opcional)', kind: Kind.password, required: false),
      ],
      initial: {'name': u.name, 'role': u.role},
      onSubmit: (v) {
        v.removeWhere((_, x) => x == null); // contraseña vacía = no cambiarla
        return api.send('PATCH', '/users/${u.id}', v);
      },
    );
    if (saved) ref.invalidate(usersProvider);
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, User u, bool active) async {
    try {
      await ref.read(apiProvider).send('PATCH', '/users/${u.id}', {'active': active});
      ref.invalidate(usersProvider);
    } catch (e) {
      if (context.mounted) toast(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return asyncBody(
      ref.watch(usersProvider),
      (users) => ListView(padding: const EdgeInsets.all(16), children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => _create(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Nuevo usuario'),
          ),
        ),
        const SizedBox(height: 8),
        for (final u in users)
          Card(
            child: ListTile(
              title: Text(u.name),
              subtitle: Text('${u.email} · ${_roles[u.role]}'),
              onTap: () => _edit(context, ref, u),
              trailing: Switch(value: u.active, onChanged: (v) => _toggle(context, ref, u, v)),
            ),
          ),
      ]),
    );
  }
}
