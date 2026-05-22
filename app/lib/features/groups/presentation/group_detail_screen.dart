import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/socket_service.dart';
import '../../goals/presentation/widgets/goal_card.dart';
import '../../goals/presentation/widgets/create_goal_dialog.dart';
import '../../goals/domain/goal_provider.dart';
import '../domain/group_provider.dart';
import '../../../core/network/api_client.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GroupDetailScreen({
    super.key,
    required this.groupId,
  });

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  String? groupName;
  String? inviteCode;
  String? adminId;
  String? currentUserId;
  List<dynamic> members = [];
  bool isLoading = true;
  int streak = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGroupData();
    });
    
    // Setup socket connection for this group
    SocketService().initSocket();
    SocketService().joinGroup(widget.groupId);
    
    SocketService().on('goal_updated', (_) {
      if (mounted && !isLoading) _silentReloadGroupData();
    });
    
    SocketService().on('checkin_updated', (_) {
      if (mounted && !isLoading) _silentReloadGroupData();
    });
  }

  @override
  void dispose() {
    SocketService().leaveGroup(widget.groupId);
    SocketService().off('goal_updated');
    SocketService().off('checkin_updated');
    super.dispose();
  }

  Future<void> _silentReloadGroupData() async {
    try {
      final response = await ApiClient.instance.get('/groups/${widget.groupId}');
      if (!mounted) return;
      setState(() {
        groupName = response.data['name'];
        inviteCode = response.data['inviteCode'];
        adminId = response.data['adminId'];
        members = response.data['members'] ?? [];
      });

      // Refetch goals list silently
      ref.read(goalsProvider.notifier).fetchGoalsSilently(widget.groupId);

      // Refetch check-ins for each goal
      final goals = ref.read(goalsProvider).value;
      if (goals != null) {
        for (final goal in goals) {
          ref.read(checkInProvider.notifier).fetchCheckIns(goal['_id']);
        }
      }

      // Fetch real streak
      final streakResponse = await ApiClient.instance.get('/goals/group/${widget.groupId}/streak');
      if (!mounted) return;
      setState(() {
        streak = streakResponse.data['streak'] ?? 0;
      });
    } catch (_) {}
  }

  Future<void> _loadGroupData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    setState(() {
      currentUserId = userId;
    });

    ref.read(goalsProvider.notifier).fetchGoals(widget.groupId);

    try {
      final response = await ApiClient.instance.get('/groups/${widget.groupId}');
      setState(() {
        groupName = response.data['name'];
        inviteCode = response.data['inviteCode'];
        adminId = response.data['adminId'];
        members = response.data['members'] ?? [];
        isLoading = false;
      });

      // Fetch real streak
      try {
        final streakResponse = await ApiClient.instance.get('/goals/group/${widget.groupId}/streak');
        setState(() {
          streak = streakResponse.data['streak'] ?? 0;
        });
      } catch (_) {}
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _removeMember(String memberId) async {
    try {
      await ref.read(groupProvider.notifier).removeMember(widget.groupId, memberId);
      // Reload to update member list
      _loadGroupData();
    } catch (e) {
      // ignore
    }
  }

  void _showSettingsDialog() {
    final isAdmin = currentUserId == adminId;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Group Settings',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              
              if (isAdmin && inviteCode != null) ...[
                const Text('Invite your partner with this code:'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    inviteCode!,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              const Text(
                'Members',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...members.map((member) {
                final isMemberAdmin = member['_id'] == adminId;
                final isMe = member['_id'] == currentUserId;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    child: Text(member['name'][0].toUpperCase()),
                  ),
                  title: Text(member['name'] + (isMe ? ' (You)' : '')),
                  subtitle: isMemberAdmin ? const Text('Admin') : null,
                  trailing: (isAdmin && !isMemberAdmin)
                      ? IconButton(
                          icon: const Icon(Icons.person_remove, color: Colors.red),
                          onPressed: () {
                            _removeMember(member['_id']);
                            Navigator.pop(context); // close dialog, user can reopen to see updated list
                          },
                        )
                      : null,
                );
              }),

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              const SizedBox(height: 16),
              
              if (isAdmin)
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Group?'),
                        content: const Text('This will permanently delete the group and all its goals.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              ref.read(groupProvider.notifier).deleteGroup(widget.groupId);
                              Navigator.pop(context);
                              context.go('/dashboard');
                            },
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text('Delete Group', style: TextStyle(color: Colors.red)),
                )
              else
                // Simple hack for non-admins to leave group (we reuse removeMember with their own ID)
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    ref.read(groupProvider.notifier).removeMember(widget.groupId, currentUserId!);
                    context.go('/dashboard');
                  },
                  icon: const Icon(Icons.exit_to_app, color: Colors.red),
                  label: const Text('Leave Group', style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final goalsState = ref.watch(goalsProvider);
    final isAdmin = currentUserId == adminId;

    return Scaffold(
      appBar: AppBar(
        title: Text(groupName ?? 'Group'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded),
            tooltip: 'Home',
            onPressed: () => context.go('/home'),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'Analytics',
            onPressed: () => context.push('/group/${widget.groupId}/analytics'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: _showSettingsDialog,
          )
        ],
      ),
      body: SafeArea(
        child: goalsState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (goals) {
            if (goals.isEmpty) {
              return Center(
                child: Text(
                  isAdmin ? 'No goals yet.\nTap + to add one!' : 'No goals yet.\nWait for the admin to add one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                const Text(
                  'This Week',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                ...goals.map((goal) => GoalCard(
                      goalId: goal['_id'],
                      groupId: widget.groupId,
                      goalName: goal['name'],
                      icon: goal['icon'],
                      weeklyMinimum: goal['weeklyMinimum'] ?? 3,
                      isAdmin: isAdmin,
                      groupMembers: members,
                    )),
              ],
            );
          },
        ),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => CreateGoalDialog(groupId: widget.groupId),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
