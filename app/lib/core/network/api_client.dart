import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../routing/app_router.dart';

class ApiClient {
  // ── Network Config ──────────────────────────────────────────────────
  // For local laptop browser:    use 'localhost'
  // For mobile on same WiFi:     use your Mac's local IP (e.g. '192.168.1.45')
  // Run `ipconfig getifaddr en0` in Terminal to find your Mac's IP
  static const String _host = 'localhost';
  static const int _port = 5001;
  // ────────────────────────────────────────────────────────────────────

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://$_host:$_port/api',
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
