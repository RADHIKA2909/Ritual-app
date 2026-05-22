import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import '../../auth/domain/auth_provider.dart';
import '../../../core/theme/theme_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _userName = 'there';
  String _quote = '';

  final List<String> _quotes = [
    "Consistency is what transforms average into excellence.",
    "Small disciplines repeated with consistency lead to great achievements.",
    "Success is the sum of small efforts, repeated day in and day out.",
    "The secret of your future is hidden in your daily routine.",
    "First we make our habits, then our habits make us.",
    "It's not what we do once in a while that shapes our lives. It's what we do consistently.",
  ];

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _quote = _quotes[Random().nextInt(_quotes.length)];
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name') ?? 'there';
    setState(() {
      _userName = name.split(' ').first; // Use first name
    });
  }

  void _showProfileOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final themeMode = ref.watch(themeProvider).value ?? ThemeMode.dark;
          final isDark = themeMode == ThemeMode.dark;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Text(
                    'Settings',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  // Theme toggle
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(isDark ? 'Dark Mode' : 'Light Mode'),
                    subtitle: Text(isDark ? 'Switch to light' : 'Switch to dark',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                    trailing: Switch.adaptive(
                      value: isDark,
                      activeColor: Theme.of(context).colorScheme.primary,
                      onChanged: (_) => ref.read(themeProvider.notifier).toggle(),
                    ),
                  ),
                  const Divider(height: 24),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.logout, color: Colors.redAccent),
                    title: const Text('Log Out', style: TextStyle(color: Colors.redAccent)),
                    onTap: () {
                      Navigator.pop(context);
                      ref.read(authProvider.notifier).logout();
                      context.go('/auth');
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 28, color: color),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Hi $_userName,',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _quote,
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            height: 1.5,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_outline_rounded, size: 20),
                    ),
                    onPressed: () {
                      // Import auth_provider for logout functionality
                      // We'll add this to the top of the file if needed, or simply push to profile/auth.
                      // The old dashboard called _showProfileOptions(context, ref);
                      // Since we didn't migrate that method to home_screen, I'll copy it here.
                      _showProfileOptions(context, ref);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.9,
                  children: [
                    _buildCard(
                      context, 
                      'My Groups', 
                      Icons.groups_rounded, 
                      Colors.blueAccent, 
                      () => context.push('/dashboard')
                    ),
                    _buildCard(
                      context, 
                      'Group Analysis', 
                      Icons.bar_chart_rounded, 
                      Colors.orangeAccent, 
                      () => context.push('/select-group-analytics')
                    ),
                    _buildCard(
                      context, 
                      'My Analysis', 
                      Icons.person_outline_rounded, 
                      const Color(0xFF6C63FF), 
                      () => context.push('/my-analytics')
                    ),
                    _buildCard(
                      context, 
                      'Today\'s Rituals', 
                      Icons.task_alt_rounded, 
                      Colors.greenAccent, 
                      () => context.push('/todays-rituals')
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
