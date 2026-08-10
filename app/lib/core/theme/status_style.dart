import 'package:flutter/material.dart';
import 'app_theme.dart';
import '../../features/groups/domain/models/group_progress.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Status presentation — colour, icon and COPY for every progress state.
//
// Every user-facing sentence about progress, streaks and health lives in this
// file, on purpose: the product rule is that Ritual encourages and never
// shames, and keeping the wording in one place makes that rule reviewable in a
// single diff.
//
// House style:
//   • Say what would help ("2 more check-ins"), not what went wrong.
//   • Never name a member as the problem. "Waiting on Radhika" is a fact about
//     the ritual; "Radhika is behind" is a judgement about a person.
//   • A broken streak is a fresh start, not a loss.
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class StatusPresentation {
  final Color color;
  final String label;
  final IconData icon;

  /// A short encouraging line. Empty when the state needs no commentary.
  final String encouragement;

  const StatusPresentation({
    required this.color,
    required this.label,
    required this.icon,
    this.encouragement = '',
  });
}

String _plural(int n, String singular, [String? plural]) =>
    n == 1 ? singular : (plural ?? '${singular}s');

class StatusStyle {
  StatusStyle._();

  // ── Per-goal weekly status ───────────────────────────────────────────────
  static StatusPresentation forGoal(GroupGoalProgress goal) {
    final remaining = goal.remaining;

    switch (goal.status) {
      case GoalStatus.completed:
        return const StatusPresentation(
          color: AppTheme.success,
          label: 'Complete',
          icon: Icons.check_circle_rounded,
          encouragement: 'Done for the week 🎉',
        );

      case GoalStatus.atRisk:
        return StatusPresentation(
          color: AppTheme.warning,
          label: 'Needs a push',
          icon: Icons.bolt_rounded,
          encouragement:
              '$remaining more ${_plural(remaining, 'check-in')} needed — there\'s still time',
        );

      case GoalStatus.onTrack:
        return StatusPresentation(
          color: AppTheme.success,
          label: 'On track',
          icon: Icons.trending_up_rounded,
          encouragement:
              '$remaining more ${_plural(remaining, 'check-in')} to go together',
        );

      case GoalStatus.incomplete:
        return const StatusPresentation(
          color: AppTheme.textMuted,
          label: 'Not started',
          icon: Icons.circle_outlined,
          encouragement: 'Ready when you are',
        );
    }
  }

  /// The one-line summary under a goal: what the group needs next.
  static String goalHint(GroupGoalProgress goal) {
    if (goal.status == GoalStatus.completed) return 'Everyone hit this one 🎉';

    if (goal.waitingOnOthersToday) {
      final others = goal.othersPendingToday;
      if (others.length == 1) {
        return 'You\'re done — waiting on ${others.first.name.split(' ').first}';
      }
      return 'You\'re done — waiting on ${others.length} others';
    }

    if (!goal.currentUserCompletedToday) {
      final remaining = goal.remaining;
      return '$remaining more ${_plural(remaining, 'check-in')} needed this week';
    }

    return 'On track together';
  }

  // ── Group streak ─────────────────────────────────────────────────────────
  static StatusPresentation forStreak(GroupProgress progress) {
    final weeks = progress.groupStreak;

    switch (progress.streakStatus) {
      case StreakStatus.safe:
        return StatusPresentation(
          color: AppTheme.accent,
          label: weeks > 0 ? '$weeks week ${_plural(weeks, 'streak', 'streak')}' : 'On track',
          icon: Icons.local_fire_department_rounded,
          encouragement: 'Streak safe for this week',
        );

      case StreakStatus.atRisk:
        final needed = progress.goals
            .where((g) => g.status == GoalStatus.atRisk)
            .fold<int>(0, (sum, g) => sum + g.remaining);
        return StatusPresentation(
          color: AppTheme.warning,
          label: '$weeks week streak',
          icon: Icons.local_fire_department_rounded,
          encouragement: needed > 0
              ? 'Your $weeks-week streak needs $needed more ${_plural(needed, 'check-in')}'
              : 'A few more check-ins keeps the streak alive',
        );

      case StreakStatus.building:
        return const StatusPresentation(
          color: AppTheme.textMuted,
          label: 'Building',
          icon: Icons.auto_awesome_rounded,
          // Deliberately not "you lost your streak".
          encouragement: 'Fresh start this week',
        );

      case StreakStatus.none:
        return const StatusPresentation(
          color: AppTheme.textMuted,
          label: 'No streak yet',
          icon: Icons.auto_awesome_rounded,
          encouragement: 'Your first week together starts now',
        );
    }
  }

  // ── Group health ─────────────────────────────────────────────────────────
  static StatusPresentation forHealth(GroupHealth health) {
    switch (health.label) {
      case HealthLabel.strong:
        return StatusPresentation(
          color: AppTheme.success,
          label: 'Strong',
          icon: Icons.favorite_rounded,
          encouragement: '${health.score}% of commitments kept',
        );
      case HealthLabel.needsAttention:
        return StatusPresentation(
          color: AppTheme.accent,
          label: 'Needs attention',
          icon: Icons.favorite_border_rounded,
          encouragement: '${health.score}% of commitments kept',
        );
      case HealthLabel.atRisk:
        return StatusPresentation(
          color: AppTheme.warning,
          label: 'Worth a check-in',
          icon: Icons.favorite_border_rounded,
          // Never "failing" / "at risk of collapse".
          encouragement: 'Worth a check-in together',
        );
    }
  }

  // ── Today, at the group level ────────────────────────────────────────────

  /// The headline under a group hero: what today asks of this group.
  /// Adapts to group size — solo, a pair, or more.
  static String todayHeadline(GroupProgress progress) {
    final needing = progress.todaySummary.goalsNeedingEveryoneToday;
    final waitingOnMe = progress.todaySummary.goalsWaitingOnMeToday;

    if (progress.goals.isEmpty) return 'No rituals yet';

    if (needing == 0) {
      return progress.isSolo ? 'All done for today 🎉' : 'Everyone\'s done today 🎉';
    }

    if (progress.isSolo) {
      return '$waitingOnMe ${_plural(waitingOnMe, 'ritual')} waiting on you';
    }

    if (progress.memberCount == 2) {
      return '$needing ${_plural(needing, 'ritual')} ${_plural(needing, 'needs', 'need')} both of you today';
    }

    return '$needing ${_plural(needing, 'ritual')} ${_plural(needing, 'needs', 'need')} everyone today';
  }

  /// "1 of 2 checked in today"
  static String checkedInToday(GroupProgress progress) =>
      '${progress.todaySummary.membersDoneToday}/${progress.memberCount} checked in today';
}
