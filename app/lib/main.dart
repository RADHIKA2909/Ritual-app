import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/firebase_config.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/routing/app_router.dart';
import 'core/network/api_client.dart';
import 'core/network/socket_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: FirebaseConfig.webOptions);
  ApiClient.initialize();
  // Join the personal socket room up front so real-time updates work on
  // whichever screen the user lands on, not just Home.
  SocketService().bootstrap();
  runApp(
    const ProviderScope(
      child: RitualApp(),
    ),
  );
}

class RitualApp extends ConsumerWidget {
  const RitualApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider).value ?? ThemeMode.dark;

    return MaterialApp.router(
      title: 'Ritual',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
