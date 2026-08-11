import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';

final authProvider = AsyncNotifierProvider<AuthNotifier, Map<String, dynamic>?>(() {
  return AuthNotifier();
});

class AuthNotifier extends AsyncNotifier<Map<String, dynamic>?> {
  @override
  FutureOr<Map<String, dynamic>?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token != null) {
      return {'loggedIn': true};
    }
    return null;
  }

  // ── Google Sign-In ──────────────────────────────────────────────────────────
  Future<void> loginWithGoogle() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      // Use Firebase signInWithPopup — works natively on Flutter web
      final GoogleAuthProvider googleProvider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile');

      final userCredential =
          await FirebaseAuth.instance.signInWithPopup(googleProvider);

      if (userCredential.user == null) {
        throw Exception('Sign-in cancelled');
      }

      // Get Firebase ID token and exchange it for our backend JWT
      final idToken = await userCredential.user!.getIdToken();

      final response = await ApiClient.instance.post('/auth/google', data: {
        'idToken': idToken,
      });

      // Persist our JWT and user info
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', response.data['token']);
      await prefs.setString('user_id', response.data['_id']);
      await prefs.setString('user_name', response.data['name'] ?? '');
      await prefs.setString('user_email', response.data['email'] ?? '');
      await prefs.setString('user_photo', response.data['profileImage'] ?? '');

      return response.data as Map<String, dynamic>;
    });
  }

  // ── Demo Login (shared public account, pre-loaded with ~3 months of data) ───
  Future<void> loginAsDemo() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final response = await ApiClient.instance.post('/auth/demo-login');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', response.data['token']);
      await prefs.setString('user_id', response.data['_id']);
      await prefs.setString('user_name', response.data['name'] ?? '');
      await prefs.setString('user_email', response.data['email'] ?? '');
      await prefs.setString('user_photo', response.data['profileImage'] ?? '');

      return response.data as Map<String, dynamic>;
    });
  }

  // ── Mock Login (dev fallback, remove in production) ─────────────────────────
  Future<void> mockLogin(String name, String email) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final response = await ApiClient.instance.post('/auth/mock-login', data: {
        'name': name,
        'email': email,
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', response.data['token']);
      await prefs.setString('user_id', response.data['_id']);
      await prefs.setString('user_name', response.data['name']);
      await prefs.setString('user_email', response.data['email']);
      await prefs.setString('user_photo', response.data['profileImage'] ?? '');

      return response.data as Map<String, dynamic>;
    });
  }

  // ── Logout ──────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('user_photo');
    state = const AsyncValue.data(null);
  }
}
