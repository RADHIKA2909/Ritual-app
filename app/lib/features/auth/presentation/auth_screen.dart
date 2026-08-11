import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
            content: Text(err),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    });

    final isLoading = authState.isLoading;

    return Scaffold(
      body: Stack(
        children: [
          // ── Animated gradient background ──────────────────────────
          const _AnimatedBackground(),

          // ── Content ───────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // Logo
                  _LogoWidget()
                      .animate()
                      .scale(
                        begin: const Offset(0.3, 0.3),
                        end: const Offset(1.0, 1.0),
                        duration: 700.ms,
                        curve: Curves.elasticOut,
                      )
                      .fadeIn(duration: 400.ms),

                  const SizedBox(height: 40),

                  // App name
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFB794F4), Color(0xFF9F7AEA), Color(0xFF7C3AED)],
                    ).createShader(bounds),
                    child: const Text(
                      'Ritual',
                      style: TextStyle(
                        fontSize: 58,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -3,
                        color: Colors.white,
                      ),
                    ),
                  )
                      .animate(delay: 200.ms)
                      .fadeIn(duration: 600.ms)
                      .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),

                  const SizedBox(height: 16),

                  Text(
                    'Build habits that stick.\nTogether.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.55),
                    ),
                  )
                      .animate(delay: 400.ms)
                      .fadeIn(duration: 500.ms)
                      .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),

                  const Spacer(flex: 2),

                  // Google Sign-In
                  _GoogleSignInButton(
                    isLoading: isLoading,
                    onTap: () => ref.read(authProvider.notifier).loginWithGoogle(),
                  )
                      .animate(delay: 600.ms)
                      .fadeIn(duration: 500.ms)
                      .slideY(begin: 0.4, end: 0, curve: Curves.easeOutCubic),

                  const SizedBox(height: 12),

                  // Demo login — a shared account pre-loaded with ~3 months
                  // of groups/check-ins, so anyone can see how the app looks
                  // without creating an account. Always visible (unlike Dev
                  // Login below), since it's meant to work in production.
                  _DemoLoginButton(
                    isLoading: isLoading,
                    onTap: () => ref.read(authProvider.notifier).loginAsDemo(),
                  )
                      .animate(delay: 680.ms)
                      .fadeIn(duration: 500.ms)
                      .slideY(begin: 0.4, end: 0, curve: Curves.easeOutCubic),

                  const SizedBox(height: 16),

                  // Dev login
                  if (!kReleaseMode)
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () => ref
                              .read(authProvider.notifier)
                              .mockLogin('Dev User', 'dev@ritual.local'),
                      child: Text(
                        'Dev Login (localhost only)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.35),
                        ),
                      ),
                    )
                        .animate(delay: 750.ms)
                        .fadeIn(duration: 400.ms),

                  const SizedBox(height: 12),

                  // Terms
                  Text(
                    'By continuing, you agree to our Terms of Service\nand Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.6,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.3),
                    ),
                  )
                      .animate(delay: 800.ms)
                      .fadeIn(duration: 400.ms),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated orb background ────────────────────────────────────────────────
class _AnimatedBackground extends StatefulWidget {
  const _AnimatedBackground();

  @override
  State<_AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<_AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _BackgroundPainter(_controller.value, isDark),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  final double t;
  final bool isDark;

  const _BackgroundPainter(this.t, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final bgColor = isDark ? const Color(0xFF0F0A1E) : const Color(0xFFFAF8FF);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = bgColor,
    );

    // Floating orbs
    final orbs = [
      _OrbConfig(
        color: const Color(0xFF7C3AED).withOpacity(isDark ? 0.25 : 0.12),
        xFraction: 0.2,
        yFraction: 0.15,
        radius: 140,
        speed: 1.0,
      ),
      _OrbConfig(
        color: const Color(0xFF9F7AEA).withOpacity(isDark ? 0.2 : 0.1),
        xFraction: 0.85,
        yFraction: 0.2,
        radius: 100,
        speed: 1.4,
      ),
      _OrbConfig(
        color: const Color(0xFF48BB78).withOpacity(isDark ? 0.15 : 0.08),
        xFraction: 0.1,
        yFraction: 0.75,
        radius: 90,
        speed: 0.7,
      ),
      _OrbConfig(
        color: const Color(0xFF7C3AED).withOpacity(isDark ? 0.12 : 0.06),
        xFraction: 0.9,
        yFraction: 0.8,
        radius: 120,
        speed: 1.2,
      ),
    ];

    for (final orb in orbs) {
      final phase = t * orb.speed * 2 * math.pi;
      final dx = math.sin(phase) * 20;
      final dy = math.cos(phase * 0.7) * 15;

      final paint = Paint()
        ..color = orb.color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);

      canvas.drawCircle(
        Offset(
          size.width * orb.xFraction + dx,
          size.height * orb.yFraction + dy,
        ),
        orb.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) => old.t != t || old.isDark != isDark;
}

class _OrbConfig {
  final Color color;
  final double xFraction;
  final double yFraction;
  final double radius;
  final double speed;

  const _OrbConfig({
    required this.color,
    required this.xFraction,
    required this.yFraction,
    required this.radius,
    required this.speed,
  });
}

// ── Logo ───────────────────────────────────────────────────────────────────
class _LogoWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      height: 108,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF9F7AEA), Color(0xFF6B46C1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withOpacity(0.45),
            blurRadius: 48,
            spreadRadius: 4,
          ),
        ],
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        size: 54,
        color: Colors.white,
      ),
    );
  }
}

// ── Google Sign-In Button ──────────────────────────────────────────────────
class _GoogleSignInButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _GoogleSignInButton({required this.isLoading, required this.onTap});

  @override
  State<_GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<_GoogleSignInButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        if (!widget.isLoading) widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1230) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: cs.primary.withOpacity(_pressed ? 0.6 : 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withOpacity(_pressed ? 0.2 : 0.08),
                blurRadius: _pressed ? 12 : 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: widget.isLoading
              ? Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: cs.primary),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _GoogleLogo(),
                    const SizedBox(width: 14),
                    Text(
                      'Continue with Google',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Demo Login Button ───────────────────────────────────────────────────────
class _DemoLoginButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _DemoLoginButton({required this.isLoading, required this.onTap});

  @override
  State<_DemoLoginButton> createState() => _DemoLoginButtonState();
}

class _DemoLoginButtonState extends State<_DemoLoginButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final onSurface = cs.onSurface;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        if (!widget.isLoading) widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: onSurface.withOpacity(_pressed ? 0.35 : 0.18),
              width: 1.5,
            ),
          ),
          child: widget.isLoading
              ? Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: onSurface.withOpacity(0.6),
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.visibility_outlined,
                        size: 18, color: onSurface.withOpacity(0.7)),
                    const SizedBox(width: 10),
                    Text(
                      'Continue as Demo',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: onSurface.withOpacity(0.75),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Google "G" rendered with RichText — no external assets needed.
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
