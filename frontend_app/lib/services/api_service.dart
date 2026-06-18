import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense.dart';

// URL is read exclusively from frontend_app/.env  → API_BASE_URL=...
// There is NO hardcoded fallback. The app throws if the key is missing.
String get _baseUrl {
  final url = dotenv.env['API_BASE_URL'];
  assert(url != null && url.isNotEmpty,
      '\n\n[ApiService] API_BASE_URL is not set in frontend_app/.env\n'
      'Add the line:  API_BASE_URL=http://10.0.2.2:3000\n');
  return url!;
}

class ApiService {
  static final ApiService _i = ApiService._();
  factory ApiService() => _i;
  ApiService._();

  final _storage = const FlutterSecureStorage();
  late final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ))..interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await _storage.read(key: 'jwt');
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    },
    onError: (e, handler) => handler.next(e),
  ));

  // ── Auth ──────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> register(String name, String email, String phone) async {
    final res = await _dio.post('/api/auth/register', data: {
      'name': name,
      'email': email,
      'phone': phone,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> login(String identifier) async {
    final res = await _dio.post('/api/auth/login', data: {
      'identifier': identifier,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyOtp(String identifier, String otp) async {
    final res = await _dio.post('/api/auth/verify-otp', data: {
      'identifier': identifier,
      'otp': otp,
    });
    final token = res.data['token'] as String;
    await _storage.write(key: 'jwt', value: token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt', token);
    await prefs.setString('api_base_url', _baseUrl);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyFirebaseToken(String idToken, {String? name, String? email}) async {
    final res = await _dio.post('/api/auth/verify-firebase-token', data: {
      'idToken': idToken,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
    });
    if (res.data['token'] != null) {
      final token = res.data['token'] as String;
      await _storage.write(key: 'jwt', value: token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt', token);
      await prefs.setString('api_base_url', _baseUrl);
    }
    return res.data as Map<String, dynamic>;
  }

  Future<void> logout() async {
    await _storage.delete(key: 'jwt');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt');
    await prefs.remove('cached_user');
  }

  Future<bool> isLoggedIn() async => (await _storage.read(key: 'jwt')) != null;

  Future<Map<String, dynamic>> getMe() async {
    final res = await _dio.get('/api/auth/me');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProfile({String? name, String? email, String? phone}) async {
    final res = await _dio.patch('/api/auth/profile', data: {
      if (name  != null) 'name':  name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
    });
    return res.data as Map<String, dynamic>;
  }

  // ── Expenses ──────────────────────────────────────────────────────────────
  Future<Expense> createExpense(Expense e) async {
    final res = await _dio.post('/api/expenses', data: e.toJson());
    return Expense.fromJson(res.data as Map<String, dynamic>);
  }

  Future<List<dynamic>> getTrackedMonths() async {
    final res = await _dio.get('/api/expenses/months');
    return res.data as List<dynamic>;
  }

  Future<List<Expense>> getExpenses({
    int page = 1, int limit = 200,
    int? month, int? year, String? category,
  }) async {
    final res = await _dio.get('/api/expenses', queryParameters: {
      'page': page, 'limit': limit,
      if (month    != null) 'month':    month,
      if (year     != null) 'year':     year,
      if (category != null) 'category': category,
    });
    final list = res.data['expenses'] as List;
    return list.map((e) => Expense.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> getMonthlySummaryRaw({required int month, required int year}) async {
    final res = await _dio.get('/api/expenses/summary', queryParameters: {'month': month, 'year': year});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getYearlyStats({required int year}) async {
    final res = await _dio.get('/api/expenses/stats/yearly', queryParameters: {'year': year});
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteExpense(String id) => _dio.delete('/api/expenses/$id');

  Future<Expense> updateExpense(String id, Map<String, dynamic> data) async {
    final res = await _dio.patch('/api/expenses/$id', data: data);
    return Expense.fromJson(res.data as Map<String, dynamic>);
  }

  // Returns the CSV download URL (use for sharing/opening in browser)
  String exportCsvUrl({int? month, int? year}) {
    final q = [
      if (month != null) 'month=$month',
      if (year  != null) 'year=$year',
      'format=csv',
    ].join('&');
    return '$_baseUrl/api/expenses/export?$q';
  }
}
