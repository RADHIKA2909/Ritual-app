import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/auth_provider.dart';

class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    ref.listen(authProvider, (previous, next) {
      if (next.value != null) {
        context.go('/home');
      } else if (next.hasError) {
        final err = next.error.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err), // Show actual error for debugging
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    });

    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLoading = authState.isLoading;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Glowing logo ─────────────────────────────────────────────
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [primary, primary.withOpacity(0.55)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withOpacity(0.45),
                        blurRadius: 40,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 52,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 36),

              // ── App name ─────────────────────────────────────────────────
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ).createShader(bounds),
                child: const Text(
                  'Ritual',
                  style: TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -2,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Build habits that stick.\nTogether.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
              ),

              const Spacer(flex: 2),

              // ── Google Sign-In button ─────────────────────────────────────
              _GoogleSignInButton(
                isLoading: isLoading,
                onTap: () => ref.read(authProvider.notifier).loginWithGoogle(),
              ),
              const SizedBox(height: 16),

              // ── Terms ─────────────────────────────────────────────────────
              Text(
                'By continuing, you agree to our Terms of Service\nand Privacy Policy.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _GoogleSignInButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1B2E) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: isLoading
            ? const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Google "G" logo drawn with text (no asset needed)
                  const _GoogleLogo(),
                  const SizedBox(width: 14),
                  Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Simple Google "G" rendered with a RichText — no external assets needed.
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: const TextSpan(
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        children: [
          TextSpan(text: 'G', style: TextStyle(color: Color(0xFF4285F4))),
          TextSpan(text: 'o', style: TextStyle(color: Color(0xFFEA4335))),
          TextSpan(text: 'o', style: TextStyle(color: Color(0xFFFBBC05))),
          TextSpan(text: 'g', style: TextStyle(color: Color(0xFF4285F4))),
          TextSpan(text: 'l', style: TextStyle(color: Color(0xFF34A853))),
          TextSpan(text: 'e', style: TextStyle(color: Color(0xFFEA4335))),
        ],
      ),
    );
  }
}
