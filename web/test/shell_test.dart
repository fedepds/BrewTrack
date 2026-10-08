import 'package:brewtrack_web/models.dart';
import 'package:brewtrack_web/providers.dart';
import 'package:brewtrack_web/shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class FakeAuth extends AuthController {
  FakeAuth(this.u);
  final User? u;
  @override
  Future<User?> build() async => u;
}

Future<void> pumpShell(WidgetTester t, User u) async {
  final router = GoRouter(initialLocation: '/lots', routes: [
    ShellRoute(
      builder: (_, _, child) => Shell(child: child),
      routes: [
        GoRoute(path: '/lots', builder: (_, _) => const Text('lots-page')),
        GoRoute(path: '/roasts', builder: (_, _) => const Text('roasts-page')),
        GoRoute(path: '/users', builder: (_, _) => const Text('users-page')),
      ],
    ),
  ]);
  await t.pumpWidget(ProviderScope(
    overrides: [authProvider.overrideWith(() => FakeAuth(u))],
    child: MaterialApp.router(routerConfig: router),
  ));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('roaster no ve Usuarios', (t) async {
    await pumpShell(t, const User(id: '1', email: 'r@x.com', name: 'Rita', role: 'roaster', active: true));
    expect(find.text('Lotes'), findsOneWidget);
    expect(find.text('Tuestes'), findsOneWidget);
    expect(find.text('Usuarios'), findsNothing);
  });

  testWidgets('admin ve Usuarios', (t) async {
    await pumpShell(t, const User(id: '2', email: 'a@x.com', name: 'Ada', role: 'admin', active: true));
    expect(find.text('Usuarios'), findsOneWidget);
  });
}
