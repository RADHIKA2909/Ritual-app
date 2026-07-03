import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../routing/app_router.dart';

class ApiClient {
  // ── Network Config ──────────────────────────────────────────────────
  // Backend URL from environment (set via --dart-define during build)
  // Usage: flutter build web --dart-define=BACKEND_URL=https://your-api.com
  static const String _baseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://8b937884-4c3b-45b4-9f96-9b0bacb4f8cb-00-39jp9x0ui1aa3.sisko.replit.dev',
  );
  // ────────────────────────────────────────────────────────────────────

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: '$_baseUrl/api',
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 3),
  ));

  static void initialize() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('jwt_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('jwt_token');
          await prefs.remove('user_id');
          // Automatically redirect to login
          appRouter.go('/auth');
        }
        return handler.next(e);
      },
    ));
  }

  static Dio get instance => _dio;
}
