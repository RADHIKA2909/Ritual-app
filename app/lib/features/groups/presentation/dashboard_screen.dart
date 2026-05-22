import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/socket_service.dart';
import '../domain/group_provider.dart';
import '../../auth/domain/auth_provider.dart';
import '../../../core/theme/theme_provider.dart';
import 'widgets/join_group_dialog.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _currentUserId;

  void _showAddGroupOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Add Group',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('Create New Group'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/create-group');
                },
              ),
              ListTile(
                leading: const Icon(Icons.group_add_outlined),
                title: const Text('Join via Invite Code'),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (context) => const JoinGroupDialog(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
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

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) {
        setState(() => _currentUserId = p.getString('user_id'));
        if (_currentUserId != null) {
          _setupSocket(_currentUserId!);
        }
      }
    });
  }

  void _setupSocket(String userId) {
    SocketService().initSocket();
    SocketService().joinUserRoom(userId);
    SocketService().on('group_updated', (_) {
      if (mounted) {
        ref.read(groupProvider.notifier).refreshGroupsSilently();
      }
    });
  }

  @override
  void dispose() {
    SocketService().off('group_updated');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupState = ref.watch(groupProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Groups', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Groups list ──────────────────────────────────
            Expanded(
              child: groupState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (groups) {
            if (groups.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'No rituals yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Create a group and start building rituals with someone you care about.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            context.push('/create-group');
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Create New Group'),
                        ),
                        const SizedBox(width: 16),
                        TextButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => const JoinGroupDialog(),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                              ),
                            ),
                          ),
                          child: const Text('Join Group'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                final members = (group['members'] as List<dynamic>?) ?? [];
                final goalCount = (group['goalCount'] as num?)?.toInt() ?? 0;

                // Build member summary: "You & Anjali" / "You, Anjali +2"
                final otherMembers = members.where((m) {
                  if (m is Map) return m['_id']?.toString() != _currentUserId;
                  return m?.toString() != _currentUserId;
                }).toList();

                String memberSummary;
                if (members.length == 1) {
                  memberSummary = 'Just you';
                } else if (otherMembers.length == 1) {
                  final name = otherMembers[0] is Map
                      ? (otherMembers[0]['name'] as String? ?? 'Someone')
                      : 'Someone';
                  // Use first name only
                  final firstName = name.split(' ').first;
                  memberSummary = 'You & $firstName';
                } else {
                  final firstName = otherMembers[0] is Map
                      ? ((otherMembers[0]['name'] as String? ?? 'Someone').split(' ').first)
                      : 'Someone';
                  final extra = otherMembers.length - 1;
                  memberSummary = 'You, $firstName +$extra';
                }

                // Color accent per group (cycle through palette)
                const groupAccents = [
                  Color(0xFF7B6FE8), Color(0xFF48BB78), Color(0xFFED8936),
                  Color(0xFFE8A838), Color(0xFF4299E1), Color(0xFFED64A6),
                ];
                final accent = groupAccents[index % groupAccents.length];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: accent.withOpacity(0.2), width: 1.5),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => context.push('/group/${group['_id']}'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          // Gradient avatar circle
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [accent, accent.withOpacity(0.55)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                (group['name'] as String).substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Group name + member summary
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group['name'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  memberSummary,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Goal count + chevron
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: accent.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$goalCount ${goalCount == 1 ? 'goal' : 'goals'}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: accent,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: accent.withOpacity(0.5),
                                size: 18,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),  // end Expanded
      ],   // end Column children
      ),   // end Column
      ),   // end SafeArea
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddGroupOptions(context),
        label: const Text('Add Group'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
