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
import '../domain/group_progress_provider.dart';
import '../domain/models/group_progress.dart';
import '../../home/domain/my_progress_provider.dart';
import '../../../core/network/socket_events.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_style.dart';
import 'widgets/group_status_widgets.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  String? currentUserId;

  // Named callbacks — must pass these to off() to avoid removing other screens' listeners
  late final Function(dynamic) _goalUpdatedHandler;
  late final Function(dynamic) _checkinUpdatedHandler;

  @override
  void initState() {
    super.initState();
    _goalUpdatedHandler = (_) => _refresh();
    _checkinUpdatedHandler = (payload) => _refresh(
          goalId: goalIdFromCheckinPayload(payload),
        );

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCurrentUser());
    SocketService().initSocket();
    SocketService().joinGroup(widget.groupId);
    SocketService().on(SocketEvents.goalUpdated, _goalUpdatedHandler);
    SocketService().on(SocketEvents.checkinUpdated, _checkinUpdatedHandler);
  }

  @override
  void dispose() {
    SocketService().leaveGroup(widget.groupId);
    SocketService().off(SocketEvents.goalUpdated, _goalUpdatedHandler);
    SocketService().off(SocketEvents.checkinUpdated, _checkinUpdatedHandler);
    super.dispose();
  }

  /// One progress refetch, plus the affected goal's raw check-ins when the
  /// event told us which goal changed.
  ///
  /// This used to refetch the group, all goals, every goal's check-ins and the
  /// streak on every single event — 1+1+N+1 requests each time any member
  /// ticked anything, and it read the goal list before the refetch resolved.
  void _refresh({String? goalId}) {
    if (!mounted) return;
    ref.read(groupProgressProvider(widget.groupId).notifier).refreshSilently();
    if (goalId != null) {
      ref.read(checkInProvider.notifier).fetchCheckIns(goalId);
    }
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => currentUserId = prefs.getString('user_id'));
  }

  Future<void> _removeMember(String memberId) async {
    try {
      await ref.read(groupProvider.notifier).removeMember(widget.groupId, memberId);
      ref.invalidate(groupProgressProvider(widget.groupId));
      ref.read(myProgressProvider.notifier).refreshSilently();
    } catch (_) {}
  }

  /// The raw `{_id, name, profileImage}` shape that the settings sheet and the
  /// leaderboard route still expect.
  List<Map<String, dynamic>> _rawMembers(GroupProgress progress) => [
        for (final m in progress.members)
          {'_id': m.userId, 'name': m.name, 'profileImage': m.profileImage},
      ];

  void _showSettings(GroupProgress progress) {
    final isAdmin = progress.isAdmin;
    final inviteCode = progress.inviteCode;
    final adminId = progress.adminId;
    final members = _rawMembers(progress);
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
                  inviteCode,
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
    final progressState = ref.watch(groupProgressProvider(widget.groupId));
    final cs = Theme.of(context).colorScheme;

    return progressState.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: cs.onSurface.withOpacity(0.2)),
            const SizedBox(height: 12),
            Text('Could not load this group',
                style: TextStyle(color: cs.onSurface.withOpacity(0.4))),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => ref.invalidate(groupProgressProvider(widget.groupId)),
              child: const Text('Try again'),
            ),
            TextButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Back to groups'),
            ),
          ]),
        ),
      ),
      data: (progress) => _buildContent(context, progress),
    );
  }

  Widget _buildContent(BuildContext context, GroupProgress progress) {
    final cs = Theme.of(context).colorScheme;
    final isAdmin = progress.isAdmin;
    final members = _rawMembers(progress);
    final groupName = progress.groupName;

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
              onPressed: () => _showSettings(progress),
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
                    Text(groupName,
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
                        progress.isSolo
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
                      StreakPill(progress: progress, compact: true),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Our progress this week ──────────────────────────────────
        SliverToBoxAdapter(child: _GroupSummaryHeader(progress: progress)),

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
                    extra: {'groupName': groupName},
                  ),
                  cs: cs,
                ),
              ),
            ]),
          ),
        ),

        // ── Rituals ──────────────────────────────────────────────────
        if (progress.goals.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.emoji_events_outlined,
                      size: 52, color: cs.onSurface.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  Text(
                    isAdmin
                        ? 'No rituals yet.\nAdd the first one you\'ll do together.'
                        : 'No rituals yet.\nWaiting for the admin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurface.withOpacity(0.45), height: 1.5),
                  ),
                ]),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => GoalCard(
                  goalId: progress.goals[i].goalId,
                  groupId: widget.groupId,
                  goalName: progress.goals[i].goalName,
                  icon: progress.goals[i].icon,
                  weeklyMinimum: progress.goals[i].weeklyMinimum,
                  isAdmin: isAdmin,
                  groupMembers: members,
                  progress: progress.goals[i],
                  isSolo: progress.isSolo,
                ),
                childCount: progress.goals.length,
              ),
            ),
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

/// The group's shared standing: streak, health, this week's commitments, and
/// who still has something to do today.
///
/// Everything here comes from the server-derived progress model — no client
/// side streak or completion maths.
class _GroupSummaryHeader extends StatelessWidget {
  final GroupProgress progress;

  const _GroupSummaryHeader({required this.progress});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final streakStyle = StatusStyle.forStreak(progress);

    // Commitments = every member's share of every goal for the week.
    final totalCommitments = progress.goals.fold<int>(
      0,
      (sum, g) => sum + g.weeklyMinimum * progress.memberCount,
    );
    final keptCommitments = progress.goals.fold<int>(
      0,
      (sum, g) => sum + g.memberProgress.fold<int>(
            0,
            (s, m) => s + (m.completedCount > m.target ? m.target : m.completedCount),
          ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cs.surfaceVariant.withOpacity(0.4),
          borderRadius: BorderRadius.circular(AppTheme.radiusHero),
          border: Border.all(color: cs.onSurface.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Headline — what today asks of this group.
            Text(
              StatusStyle.todayHeadline(progress),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              StatusStyle.checkedInToday(progress),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: cs.onSurface.withOpacity(0.5),
              ),
            ),

            if (progress.goals.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: _SummaryStat(
                    label: 'This week',
                    value: '$keptCommitments/$totalCommitments',
                    caption: 'commitments kept',
                    color: cs.primary,
                  ),
                ),
                Container(
                  width: 1,
                  height: 34,
                  color: cs.onSurface.withOpacity(0.08),
                ),
                Expanded(
                  child: _SummaryStat(
                    label: 'Rituals met',
                    value:
                        '${progress.goalsCompletedThisWeek}/${progress.goals.length}',
                    caption: 'as a group',
                    color: progress.goalsCompletedThisWeek == progress.goals.length
                        ? AppTheme.success
                        : cs.primary,
                  ),
                ),
              ]),

              // Streak + health, side by side. Streak is reserved for the group
              // level; it deliberately doesn't appear on individual goal cards.
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StreakPill(progress: progress),
                  if (progress.health != null)
                    GroupHealthChip(health: progress.health!),
                ],
              ),

              if (streakStyle.encouragement.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Icon(streakStyle.icon, size: 14, color: streakStyle.color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      streakStyle.encouragement,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: streakStyle.color,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ]),
              ],
            ],

            if (progress.members.length > 1) ...[
              const SizedBox(height: 16),
              Divider(height: 1, color: cs.onSurface.withOpacity(0.07)),
              const SizedBox(height: 14),
              MemberStatusRow(members: progress.members),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  final String caption;
  final Color color;

  const _SummaryStat({
    required this.label,
    required this.value,
    required this.caption,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: cs.onSurface.withOpacity(0.4),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
            color: color,
          ),
        ),
        Text(
          caption,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: cs.onSurface.withOpacity(0.4),
          ),
        ),
      ],
    );
  }
}
