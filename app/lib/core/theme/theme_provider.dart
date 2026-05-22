import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeProvider = AsyncNotifierProvider<ThemeNotifier, ThemeMode>(() {
  return ThemeNotifier();
});

class ThemeNotifier extends AsyncNotifier<ThemeMode> {
  @override
  FutureOr<ThemeMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('theme_mode');
    if (saved == 'dark') return ThemeMode.dark;
    if (saved == 'light') return ThemeMode.light;
    return ThemeMode.dark; // default to dark for premium feel
  }

  Future<void> toggle() async {
    final current = state.value ?? ThemeMode.dark;
    final next = current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', next == ThemeMode.dark ? 'dark' : 'light');
    state = AsyncData(next);
  }

  bool get isDark => state.value == ThemeMode.dark;
}
