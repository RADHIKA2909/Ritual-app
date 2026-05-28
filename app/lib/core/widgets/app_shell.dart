import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

/// Persistent bottom-nav shell that wraps all main screens.
class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  static const _tabs = [
    _TabItem(icon: Icons.home_rounded, label: 'Home', path: '/home'),
    _TabItem(icon: Icons.groups_rounded, label: 'Groups', path: '/dashboard'),
    _TabItem(icon: Icons.task_alt_rounded, label: 'Rituals', path: '/todays-rituals'),
    _TabItem(icon: Icons.person_rounded, label: 'Profile', path: '/profile'),
  ];

  int _currentIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    if (loc.startsWith('/dashboard') || loc.startsWith('/group') || loc.startsWith('/create-group')) return 1;
    if (loc.startsWith('/todays-rituals')) return 2;
    if (loc.startsWith('/profile')) return 3;
    return 0; // home, analytics, etc.
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentIndex = _currentIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(
            top: BorderSide(color: cs.onSurface.withOpacity(0.06), width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final tab = _tabs[i];
                final isActive = i == currentIndex;
                return Expanded(
                  child: _NavTab(
                    tab: tab,
                    isActive: isActive,
                    onTap: () => context.go(tab.path),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final _TabItem tab;
  final bool isActive;
  final VoidCallback onTap;

  const _NavTab({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? cs.primary.withOpacity(0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                tab.icon,
                size: 22,
                color: isActive ? cs.primary : cs.onSurface.withOpacity(0.35),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? cs.primary : cs.onSurface.withOpacity(0.35),
                letterSpacing: 0.2,
              ),
              child: Text(tab.label),
            ),
          ],
        ),
      )
      .animate(target: isActive ? 1 : 0)
      .scaleXY(begin: 0.95, end: 1.0, curve: Curves.easeOutBack, duration: 200.ms),
    );
  }
}

class _TabItem {
  final IconData icon;
  final String label;
  final String path;
  const _TabItem({required this.icon, required this.label, required this.path});
}
