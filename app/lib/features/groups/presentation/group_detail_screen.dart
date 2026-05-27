import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/socket_service.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../goals/presentation/widgets/goal_card.dart';
import '../../goals/presentation/widgets/create_goal_dialog.dart';
import '../../goals/domain/goal_provider.dart';
import '../domain/group_provider.dart';
import '../../../core/network/api_client.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

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

  // Named callbacks — must pass these to off() to avoid removing other screens' listeners
  late final Function(dynamic) _goalUpdatedHandler;
  late final Function(dynamic) _checkinUpdatedHandler;

  @override
  void initState() {
    super.initState();
    _goalUpdatedHandler = (_) { if (mounted && !isLoading) _silentReload(); };
    _checkinUpdatedHandler = (_) { if (mounted && !isLoading) _silentReload(); };

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadGroupData());
    SocketService().initSocket();
    SocketService().joinGroup(widget.groupId);
    SocketService().on('goal_updated', _goalUpdatedHandler);
    SocketService().on('checkin_updated', _checkinUpdatedHandler);
  }

  @override
  void dispose() {
    SocketService().leaveGroup(widget.groupId);
    SocketService().off('goal_updated', _goalUpdatedHandler);
    SocketService().off('checkin_updated', _checkinUpdatedHandler);
    super.dispose();
  }

  Future<void> _silentReload() async {
    try {
      final response = await ApiClient.instance.get('/groups/${widget.groupId}');
      if (!mounted) return;
      setState(() {
        groupName = response.data['name'];
        inviteCode = response.data['inviteCode'];
        adminId = response.data['adminId'];
        members = response.data['members'] ?? [];
      });
      ref.read(goalsProvider.notifier).fetchGoalsSilently(widget.groupId);
      final goals = ref.read(goalsProvider).value;
      if (goals != null) {
        for (final goal in goals) {
          ref.read(checkInProvider.notifier).fetchCheckIns(goal['_id']);
        }
      }
      final sr = await ApiClient.instance.get('/goals/group/${widget.groupId}/streak');
      if (!mounted) return;
      setState(() => streak = sr.data['streak'] ?? 0);
    } catch (_) {}
  }

  Future<void> _loadGroupData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => currentUserId = prefs.getString('user_id'));
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
      try {
        final sr = await ApiClient.instance.get('/goals/group/${widget.groupId}/streak');
        setState(() => streak = sr.data['streak'] ?? 0);
      } catch (_) {}
    } catch (_) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _removeMember(String memberId) async {
    try {
      await ref.read(groupProvider.notifier).removeMember(widget.groupId, memberId);
      _loadGroupData();
    } catch (_) {}
  }

  void _showSettings() {
    final isAdmin = currentUserId == adminId;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text('Group Settings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),

            if (isAdmin && inviteCode != null) ...[
              Text('Invite Code',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.45),
                      letterSpacing: 0.5)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Theme.of(ctx).colorScheme.primary.withOpacity(0.3)),
                ),
                child: Text(
                  inviteCode!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 8,
                    color: Theme.of(ctx).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            Text('Members',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.45),
                    letterSpacing: 0.5)),
            const SizedBox(height: 10),
            ...members.map((member) {
              final isMemberAdmin = member['_id'] == adminId;
              final isMe = member['_id'] == currentUserId;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        Theme.of(ctx).colorScheme.primary.withOpacity(0.2),
                    child: Text(
                      (member['name'] as String)[0].toUpperCase(),
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(ctx).colorScheme.primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(member['name'] + (isMe ? ' (You)' : ''),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      if (isMemberAdmin)
                        Text('Admin',
                            style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(ctx).colorScheme.primary)),
                    ]),
                  ),
                  if (isAdmin && !isMemberAdmin)
                    IconButton(
                      icon: const Icon(Icons.person_remove_rounded,
                          color: Colors.redAccent, size: 20),
                      onPressed: () {
                        _removeMember(member['_id']);
                        Navigator.pop(ctx);
                      },
                    ),
                ]),
              );
            }),

            const SizedBox(height: 16),
            if (isAdmin)
              _DangerButton(
                icon: Icons.delete_rounded,
                label: 'Delete Group',
                onTap: () {
                  Navigator.pop(ctx);
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      title: const Text('Delete Group?'),
                      content: const Text(
                          'This will permanently delete the group and all its goals.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel')),
                        TextButton(
                          onPressed: () {
                            ref
                                .read(groupProvider.notifier)
                                .deleteGroup(widget.groupId);
                            Navigator.pop(context);
                            context.go('/dashboard');
                          },
                          child: const Text('Delete',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                },
              )
            else
              _DangerButton(
                icon: Icons.exit_to_app_rounded,
                label: 'Leave Group',
                onTap: () {
                  Navigator.pop(ctx);
                  ref
                      .read(groupProvider.notifier)
                      .removeMember(widget.groupId, currentUserId!);
                  context.go('/dashboard');
                },
              ),
          ]),
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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(slivers: [
        // ── Sliver header ────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 160,
          pinned: true,
          backgroundColor: cs.surface,
          leading: GestureDetector(
            onTap: () => context.canPop() ? context.pop() : context.go('/dashboard'),
            child: Container(
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.surfaceVariant.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: cs.onSurface),
            ),
          ),
          actions: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: cs.surfaceVariant.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.bar_chart_rounded, size: 18, color: cs.onSurface),
              ),
              onPressed: () => context.push('/group/${widget.groupId}/analytics'),
            ),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: cs.surfaceVariant.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.tune_rounded, size: 18, color: cs.onSurface),
              ),
              onPressed: _showSettings,
            ),
            const SizedBox(width: 8),
          ],
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.pin,
            background: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(groupName ?? 'Group',
                        style: const TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -1)),
                    const SizedBox(height: 8),
                    Row(children: [
                      // Member avatars
                      ...members.take(3).toList().asMap().entries.map((e) {
                        final m = e.value;
                        return Transform.translate(
                          offset: Offset(-e.key * 8.0, 0),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: cs.surface, width: 1.5),
                            ),
                            child: ClipOval(
                              child: UserAvatar(
                                name: m['name'] as String,
                                profileImage: m['profileImage'] as String?,
                                radius: 13,
                                colorScheme: cs,
                              ),
                            ),
                          ),
                        );
                      }),
                      SizedBox(width: members.length > 1 ? 4.0 : 0),
                      Text(
                        members.length == 1
                            ? 'Just you'
                            : members
                                .map((m) => (m['name'] as String).split(' ').first)
                                .join(' & '),
                        style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withOpacity(0.5),
                            fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      if (streak > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(children: [
                            const Text('🔥', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 4),
                            Text('$streak wk streak',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.orange)),
                          ]),
                        ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Today's Status ──────────────────────────────────────────
        SliverToBoxAdapter(
          child: _TodayStatusBar(
            members: members,
            currentUserId: currentUserId,
            goalsState: goalsState,
          ),
        ),

        // ── Quick action buttons (Activity + Leaderboard + Chat) ────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(children: [
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.dynamic_feed_rounded,
                  label: 'Activity',
                  onTap: () => context.push('/group/${widget.groupId}/feed'),
                  cs: cs,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.leaderboard_rounded,
                  label: 'Ranks',
                  onTap: () => context.push(
                    '/group/${widget.groupId}/leaderboard',
                    extra: {'members': members},
                  ),
                  cs: cs,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Chat',
                  onTap: () => context.push(
                    '/group/${widget.groupId}/chat',
                    extra: {'groupName': groupName ?? 'Group'},
                  ),
                  cs: cs,
                ),
              ),
            ]),
          ),
        ),

        // ── Goals list ───────────────────────────────────────────────
        goalsState.when(
          loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator())),
          error: (err, _) => SliverFillRemaining(
              child: Center(child: Text('Error: $err'))),
          data: (goals) {
            if (goals.isEmpty) {
              return SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.emoji_events_outlined,
                          size: 52, color: cs.onSurface.withOpacity(0.2)),
                      const SizedBox(height: 16),
                      Text(
                        isAdmin
                            ? 'No goals yet.\nTap + to add the first one!'
                            : 'No goals yet.\nWaiting for the admin.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurface.withOpacity(0.45), height: 1.5),
                      ),
                    ]),
                  ),
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => GoalCard(
                    goalId: goals[i]['_id'],
                    groupId: widget.groupId,
                    goalName: goals[i]['name'],
                    icon: goals[i]['icon'],
                    weeklyMinimum: goals[i]['weeklyMinimum'] ?? 3,
                    isAdmin: isAdmin,
                    groupMembers: members,
                  ),
                  childCount: goals.length,
                ),
              ),
            );
          },
        ),
      ]),

      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => CreateGoalDialog(groupId: widget.groupId),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Goal',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cs.primary.withOpacity(0.1),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.primary.withOpacity(0.25), width: 1.5),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: cs.primary),
            const SizedBox(width: 7),
            Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                )),
          ]),
        ),
      ),
    );
  }
}

class _TodayStatusBar extends ConsumerWidget {
  final List<dynamic> members;
  final String? currentUserId;
  final AsyncValue<List<dynamic>> goalsState;

  const _TodayStatusBar({
    required this.members,
    required this.currentUserId,
    required this.goalsState,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (members.isEmpty) return const SizedBox.shrink();

    final checkInState = ref.watch(checkInProvider);
    final allCheckIns = checkInState.value ?? {};
    final goals = goalsState.value ?? [];

    final now = DateTime.now();

    // For each member, check if they have at least 1 completed check-in today
    // across any goal
    Map<String, bool> memberCheckedIn = {};
    for (final member in members) {
      final memberId = member['_id'].toString();
      bool checkedInToday = false;
      for (final goal in goals) {
        final goalId = goal['_id'].toString();
        final checkIns = allCheckIns[goalId] ?? [];
        checkedInToday = checkIns.any((c) {
          if (c['userId'].toString() != memberId) return false;
          if (c['completed'] != true) return false;
          final d = DateTime.parse(c['date']).toLocal();
          return d.year == now.year && d.month == now.month && d.day == now.day;
        });
        if (checkedInToday) break;
      }
      memberCheckedIn[memberId] = checkedInToday;
    }

    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surfaceVariant.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.onSurface.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(
                "TODAY'S STATUS",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: cs.onSurface.withOpacity(0.4),
                ),
              ),
              const Spacer(),
              // Summary count
              Text(
                '${memberCheckedIn.values.where((v) => v).length}/${members.length} checked in',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withOpacity(0.4),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: members.length <= 4
                  ? MainAxisAlignment.spaceAround
                  : MainAxisAlignment.start,
              children: members.map<Widget>((member) {
                final memberId = member['_id'].toString();
                final isMe = memberId == currentUserId;
                final isDone = memberCheckedIn[memberId] ?? false;
                final name = (member['name'] as String).split(' ').first;

                return Padding(
                  padding: members.length > 4
                      ? const EdgeInsets.only(right: 16)
                      : EdgeInsets.zero,
                  child: Column(children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDone
                                  ? cs.primary.withOpacity(0.5)
                                  : cs.onSurface.withOpacity(0.1),
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: UserAvatar(
                              name: name,
                              profileImage: member is Map
                                  ? member['profileImage'] as String?
                                  : null,
                              radius: 22,
                            ),
                          ),
                        ),
                        // Status badge
                        Positioned(
                          bottom: -2, right: -2,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 18, height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDone
                                  ? const Color(0xFF48BB78)
                                  : cs.surfaceVariant,
                              border: Border.all(
                                  color: cs.surface, width: 1.5),
                            ),
                            child: Center(
                              child: isDone
                                  ? const Icon(Icons.check_rounded,
                                      size: 10, color: Colors.white)
                                  : Icon(Icons.schedule_rounded,
                                      size: 10,
                                      color: cs.onSurface.withOpacity(0.35)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isMe ? 'You' : name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDone
                            ? cs.onSurface.withOpacity(0.8)
                            : cs.onSurface.withOpacity(0.4),
                      ),
                    ),
                  ]),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DangerButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.red.withOpacity(0.2)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.redAccent, size: 18),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  color: Colors.redAccent, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
