import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'login_screen.dart';
import 'lot_detail_screen.dart';
import 'lots_screen.dart';
import 'providers.dart';
import 'roast_detail_screen.dart';
import 'roasts_screen.dart';
import 'shell.dart';
import 'users_screen.dart';


final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);
  // ponytail: al recargar la página se pierde el deep link y se vuelve a /lots.
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final here = state.matchedLocation;
      if (auth.isLoading) return here == '/splash' ? null : '/splash';
      final user = auth.valueOrNull;
      if (user == null) return here == '/login' ? null : '/login';
      if (here == '/login' || here == '/splash' || (here.startsWith('/users') && !user.isAdmin)) {
        return '/lots';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const Scaffold(body: Center(child: CircularProgressIndicator()))),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      ShellRoute(
        builder: (_, _, child) => Shell(child: child),
        routes: [
          GoRoute(
            path: '/lots',
            builder: (_, _) => const LotsScreen(),
            routes: [GoRoute(path: ':id', builder: (_, s) => LotDetailScreen(s.pathParameters['id']!))],
          ),
          GoRoute(
            path: '/roasts',
            builder: (_, _) => const RoastsScreen(),
            routes: [GoRoute(path: ':id', builder: (_, s) => RoastDetailScreen(s.pathParameters['id']!))],
          ),
          GoRoute(path: '/users', builder: (_, _) => const UsersScreen()),
        ],
      ),
    ],
  );
});
