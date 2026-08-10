import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/socket_events.dart';
import '../../../core/network/socket_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_style.dart';
import '../../goals/presentation/widgets/check_in_button.dart';
import '../../groups/domain/models/group_progress.dart';
import '../../groups/presentation/widgets/group_status_widgets.dart';
import '../../home/domain/my_progress_provider.dart';

class TodaysRitualsScreen extends ConsumerStatefulWidget {
  const TodaysRitualsScreen({super.key});

  @override
  ConsumerState<TodaysRitualsScreen> createState() => _TodaysRitualsScreenState();
}

class _TodaysRitualsScreenState extends ConsumerState<TodaysRitualsScreen> {
  late final Function(dynamic) _checkinUpdatedHandler;

  @override
  void initState() {
    super.initState();
    // This screen previously had no socket listener at all, so a teammate
    // checking in never showed up until something else happened to refresh
    // the shared provider.
    _checkinUpdatedHandler = (payload) {
      if (!mounted) return;
      final groupId = groupIdFromCheckinPayload(payload);
      final notifier = ref.read(myProgressProvider.notifier);
      groupId != null ? notifier.refreshGroup(groupId) : notifier.refreshSilently();
    };
    SocketService().initSocket();
    SocketService().on(SocketEvents.checkinUpdated, _checkinUpdatedHandler);
  }

  @override
  void dispose() {
    SocketService().off(SocketEvents.checkinUpdated, _checkinUpdatedHandler);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progressState = ref.watch(myProgressProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's Commitments",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _todayLabel(),
                    style: TextStyle(
                      fontSize: 14,
                      color: cs.onSurface.withOpacity(0.45),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Body ────────────────────────────────────────────────────
            Expanded(
              child: progressState.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off_rounded,
                          size: 48,
                          color: cs.onSurface.withOpacity(0.2)),
                      const SizedBox(height: 12),
                      Text('Could not load rituals',
                          style: TextStyle(
                              color: cs.onSurface.withOpacity(0.4))),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => ref.invalidate(myProgressProvider),
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
                data: (groups) {
                  final withGoals =
                      groups.where((g) => g.goals.isNotEmpty).toList();

                  if (withGoals.isEmpty) {
                    return _EmptyRitualsView();
                  }

                  // Today's commitments across every group.
                  final total =
                      withGoals.fold<int>(0, (s, g) => s + g.goals.length);
                  final doneCount = withGoals.fold<int>(
                      0, (s, g) => s + g.goalsDoneByMeToday.length);
                  final allDone = doneCount == total && total > 0;

                  var animIndex = 0;

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    children: [
                      // ── Progress hero card ─────────────────────────
                      _ProgressHeroCard(
                        doneCount: doneCount,
                        total: total,
                        allDone: allDone,
                        cs: cs,
                      )
                          .animate()
                          .fadeIn(duration: 400.ms)
                          .slideY(begin: -0.1, end: 0, curve: Curves.easeOut),

                      const SizedBox(height: 24),

                      // ── One section per group ──────────────────────
                      // Grouping by group (rather than one flat list) is what
                      // makes this read as "our commitments" instead of a
                      // personal to-do list.
                      for (final group in withGoals) ...[
                        _GroupSectionHeader(group: group),
                        const SizedBox(height: 10),
                        ...(() {
                          // Pending first within each group, then done.
                          final ordered = [
                            ...group.goalsPendingForMeToday,
                            ...group.goalsDoneByMeToday,
                          ];
                          return ordered.map((goal) {
                            final delay = (animIndex++ * 60).ms;
                            return _RitualCard(
                              goal: goal,
                              groupName: group.groupName,
                              groupId: group.groupId,
                              isSolo: group.isSolo,
                              cs: cs,
                            )
                                .animate(delay: delay)
                                .fadeIn(duration: 350.ms)
                                .slideX(
                                    begin: 0.06,
                                    end: 0,
                                    curve: Curves.easeOutCubic);
                          });
                        })(),
                        const SizedBox(height: 22),
                      ],

                      // All done celebration
                      if (allDone)
                        _AllDoneBanner()
                            .animate(delay: 200.ms)
                            .fadeIn(duration: 500.ms)
                            .scale(
                              begin: const Offset(0.9, 0.9),
                              end: const Offset(1.0, 1.0),
                              curve: Curves.elasticOut,
                            ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _todayLabel() {
    final now = DateTime.now();
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }
}

// ── Progress Hero Card ─────────────────────────────────────────────────────
class _ProgressHeroCard extends StatelessWidget {
  final int doneCount;
  final int total;
  final bool allDone;
  final ColorScheme cs;

  const _ProgressHeroCard({
    required this.doneCount,
    required this.total,
    required this.allDone,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? doneCount / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: allDone
              ? [const Color(0xFF38A169), const Color(0xFF48BB78)]
              : [cs.primary, cs.primary.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (allDone ? const Color(0xFF48BB78) : cs.primary)
                .withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(children: [
        // Circular progress
        SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => CircularProgressIndicator(
                  value: value,
                  strokeWidth: 6,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              Text(
                '$doneCount/$total',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(
              allDone
                  ? '🎉 All done!'
                  : doneCount == 0
                      ? 'Let\'s get started!'
                      : 'Keep it up!',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              allDone
                  ? 'You crushed today\'s rituals.'
                  : '${total - doneCount} ritual${total - doneCount == 1 ? '' : 's'} remaining today',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}


// ── Ritual Card ────────────────────────────────────────────────────────────
/// One ritual, checkable in place.
///
/// The old card had a "Go →" pill that looked like an action but was pure
/// decoration inside a card-wide tap target that just navigated to the group;
/// completed cards had every handler nulled, so they weren't even tappable.
/// Now the button checks in, and the text region navigates.
class _RitualCard extends StatelessWidget {
  final GroupGoalProgress goal;
  final String groupName;
  final String groupId;
  final bool isSolo;
  final ColorScheme cs;

  const _RitualCard({
    required this.goal,
    required this.groupName,
    required this.groupId,
    required this.isSolo,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDone = goal.currentUserCompletedToday;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDone
            ? AppTheme.success.withOpacity(0.07)
            : isDark
                ? cs.surfaceVariant.withOpacity(0.5)
                : cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDone
              ? AppTheme.success.withOpacity(0.25)
              : cs.onSurface.withOpacity(0.07),
          width: 1.5,
        ),
        boxShadow: isDone
            ? null
            : [
                BoxShadow(
                  color: cs.onSurface.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(children: [
        // Icon box
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isDone
                ? AppTheme.success.withOpacity(0.12)
                : cs.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
              child: Text(goal.icon, style: const TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 14),

        // Text — tapping here opens the group. Keeping navigation off the
        // button means the check-in hit target is unambiguous.
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push('/group/$groupId'),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.goalName,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: -0.3,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      decorationColor: cs.onSurface.withOpacity(0.3),
                      color: isDone
                          ? cs.onSurface.withOpacity(0.4)
                          : cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(children: [
                    Icon(Icons.groups_rounded,
                        size: 11,
                        color: cs.onSurface.withOpacity(isDone ? 0.25 : 0.35)),
                    const SizedBox(width: 4),
                    Flexible(
                      // The group name is already the section header, so this
                      // line carries what the GROUP still needs instead.
                      child: Text(
                        StatusStyle.goalHint(goal),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color:
                                cs.onSurface.withOpacity(isDone ? 0.35 : 0.45),
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ]),
                ]),
          ),
        ),

        const SizedBox(width: 10),
        CheckInButton(
          goalId: goal.goalId,
          groupId: groupId,
          date: DateTime.now(),
          isCompleted: isDone,
        ),
      ]),
    );
  }
}

/// Group heading above that group's rituals — name, streak, and how many of
/// its rituals are done today.
class _GroupSectionHeader extends StatelessWidget {
  final GroupProgress group;

  const _GroupSectionHeader({required this.group});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final done = group.goalsDoneByMeToday.length;

    return Row(
      children: [
        Flexible(
          child: Text(
            group.groupName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: cs.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: done == group.goals.length
                ? AppTheme.success.withOpacity(0.14)
                : cs.onSurface.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$done/${group.goals.length}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: done == group.goals.length
                  ? AppTheme.success
                  : cs.onSurface.withOpacity(0.45),
            ),
          ),
        ),
        const Spacer(),
        StreakPill(progress: group, compact: true),
      ],
    );
  }
}

// ── All Done Banner ────────────────────────────────────────────────────────
class _AllDoneBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF38A169), Color(0xFF48BB78)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🔥', style: TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        const Text(
          'Streak alive! Come back tomorrow.',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ]),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────
class _EmptyRitualsView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            '✨',
            style: const TextStyle(fontSize: 64),
          )
              .animate()
              .scale(
                begin: const Offset(0.5, 0.5),
                end: const Offset(1.0, 1.0),
                curve: Curves.elasticOut,
                duration: 700.ms,
              ),
          const SizedBox(height: 20),
          const Text(
            'No rituals yet',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5),
          )
              .animate(delay: 100.ms)
              .fadeIn(duration: 400.ms),
          const SizedBox(height: 8),
          Text(
            'Join a group and add goals to\nsee your daily rituals here.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: cs.onSurface.withOpacity(0.45)),
          )
              .animate(delay: 200.ms)
              .fadeIn(duration: 400.ms),
        ]),
      ),
    );
  }
}
