import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// En desarrollo: `--dart-define=API_BASE=http://localhost:8000/api/v1`.
const apiBase = String.fromEnvironment('API_BASE', defaultValue: '/api/v1');
const _refreshKey = 'refresh_token';

String apiMessage(Object e) {
  if (e is DioException) {
    final d = e.response?.data;
    if (d is Map && d['error'] is Map) return d['error']['message'] as String;
    return e.message ?? 'Error de red';
  }
  return e.toString();
}

class Api {
  Api(this._prefs, {Dio? dio}) : _dio = dio ?? Dio(BaseOptions(baseUrl: apiBase)) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (o, h) {
        if (_access != null) o.headers['Authorization'] = 'Bearer $_access';
        h.next(o);
      },
      onError: (e, h) async {
        final o = e.requestOptions;
        if (e.response?.statusCode != 401 || o.path.startsWith('/auth/') || !await restore()) {
          return h.next(e);
        }
        o.headers['Authorization'] = 'Bearer $_access';
        try {
          h.resolve(await _dio.fetch<dynamic>(o));
        } on DioException catch (e2) {
          h.next(e2);
        }
      },
    ));
  }

  final SharedPreferences _prefs;
  final Dio _dio;
  String? _access;

  /// Canjea el refresh token guardado por un access token nuevo.
  Future<bool> restore() async {
    final rt = _prefs.getString(_refreshKey);
    if (rt == null) return false;
    try {
      final r = await Dio(BaseOptions(baseUrl: _dio.options.baseUrl))
          .post<Map<String, dynamic>>('/auth/refresh', data: {'refresh_token': rt});
      _access = r.data!['access_token'];
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) await logout();
      return false;
    }
  }

  Future<void> login(String email, String password) async {
    final r = await _dio.post<Map<String, dynamic>>('/auth/login', data: {'email': email, 'password': password});
    _access = r.data!['access_token'];
    await _prefs.setString(_refreshKey, r.data!['refresh_token']);
  }

  Future<void> logout() async {
    _access = null;
    await _prefs.remove(_refreshKey);
  }

  Future<User> me() async => User.fromJson(await _get('/auth/me'));

  Future<Map<String, dynamic>> _get(String path, [Map<String, dynamic>? query]) async =>
      (await _dio.get<Map<String, dynamic>>(path, queryParameters: query)).data!;

  // ponytail: lista fija de 200 filas, sin paginación en la UI; añadirla si un taller supera eso.
  Future<Paged<Lot>> lots({String country = '', String process = ''}) async => pageFrom(
      await _get('/green-lots', {
        'limit': 200,
        if (country.isNotEmpty) 'country': country,
        if (process.isNotEmpty) 'process': process,
      }),
      Lot.fromJson);

  Future<LotDetail> lot(String id) async => LotDetail.fromJson(await _get('/green-lots/$id'));

  Future<Paged<Roast>> roasts(RoastFilter f) async => pageFrom(
      await _get('/roasts', {
        'limit': 200,
        if (f.lotId.isNotEmpty) 'lot_id': f.lotId,
        if (f.level.isNotEmpty) 'level': f.level,
        if (f.from.isNotEmpty) 'date_from': f.from,
        if (f.to.isNotEmpty) 'date_to': f.to,
      }),
      Roast.fromJson);

  Future<RoastDetail> roast(String id) async => RoastDetail.fromJson(await _get('/roasts/$id'));

  Future<List<User>> users() async => [
        for (final u in (await _dio.get<List<dynamic>>('/users')).data!) User.fromJson(u as Map<String, dynamic>)
      ];

  Future<void> send(String method, String path, [Object? data]) async {
    await _dio.request<void>(path, data: data, options: Options(method: method));
  }
}
