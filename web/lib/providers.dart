import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';

final prefsProvider = Provider<SharedPreferences>((_) => throw UnimplementedError('override en main'));
final apiProvider = Provider<Api>((ref) => Api(ref.watch(prefsProvider)));

class AuthController extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    final api = ref.read(apiProvider);
    if (!await api.restore()) return null;
    return api.me();
  }

  Future<void> login(String email, String password) async {
    final api = ref.read(apiProvider);
    state = await AsyncValue.guard(() async {
      await api.login(email, password);
      return api.me();
    });
  }

  Future<void> logout() async {
    await ref.read(apiProvider).logout();
    state = const AsyncData(null);
  }
}

final authProvider = AsyncNotifierProvider<AuthController, User?>(AuthController.new);

final lotsProvider = FutureProvider.autoDispose.family<List<Lot>, LotFilter>(
    (ref, f) => ref.watch(apiProvider).lots(country: f.country, process: f.process));
final lotProvider =
    FutureProvider.autoDispose.family<LotDetail, String>((ref, id) => ref.watch(apiProvider).lot(id));
final roastsProvider = FutureProvider.autoDispose
    .family<List<Roast>, RoastFilter>((ref, f) => ref.watch(apiProvider).roasts(f));
final roastProvider =
    FutureProvider.autoDispose.family<RoastDetail, String>((ref, id) => ref.watch(apiProvider).roast(id));
final usersProvider = FutureProvider.autoDispose<List<User>>((ref) => ref.watch(apiProvider).users());
final summaryProvider = FutureProvider.autoDispose
    .family<Summary, String?>((ref, month) => ref.watch(apiProvider).summary(month));
