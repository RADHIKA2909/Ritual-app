import 'package:flutter/material.dart';
import 'app_theme.dart';
import '../utils/plurals.dart';
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

class StatusStyle {
  StatusStyle._();

  // ── Per-goal weekly status ───────────────────────────────────────────────
  //
  // NOTE ON UNITS: `goal.remaining` is in GROUP units — the weakest-link score
  // still needed, not the number of individual check-ins. For a pair at 0/3
  // that is "3 more together", which really means 6 taps between two people.
  // Copy here says "together" so the number can't be misread as a personal to-do.
  static StatusPresentation forGoal(GroupGoalProgress goal) {
    final remaining = goal.remaining;

    switch (goal.status) {
      case GoalStatus.completed:
        return const StatusPresentation(
          color: AppTheme.success,
          label: 'Complete',
          icon: Icons.check_circle_rounded,
          // GROUP completion — deliberately not "you're done".
          encouragement: 'Complete for the week 🎉',
        );

      case GoalStatus.atRisk:
        // Split the genuinely-lost case from the tight-but-doable one; the two
        // used to share copy, so a Sunday with 7 needed said "there's still time".
        if (goal.unreachableThisWeek) {
          return const StatusPresentation(
            color: AppTheme.warning,
            label: 'Next week',
            icon: Icons.refresh_rounded,
            encouragement: 'Out of reach this week — next week is a fresh start',
          );
        }
        return StatusPresentation(
          color: AppTheme.warning,
          label: 'Streak at risk',
          icon: Icons.bolt_rounded,
          encouragement: 'Needs ${count(remaining, 'more check-in')} together, '
              'every remaining day',
        );

      case GoalStatus.needsAttention:
        return StatusPresentation(
          color: AppTheme.accent,
          label: 'Needs attention',
          icon: Icons.schedule_rounded,
          encouragement:
              'A bit behind — ${count(remaining, 'more check-in')} together this week',
        );

      case GoalStatus.onTrack:
        return StatusPresentation(
          color: AppTheme.success,
          label: 'On track',
          icon: Icons.trending_up_rounded,
          encouragement: '${count(remaining, 'more check-in')} to go together',
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

  /// The one-line summary under a ritual: what the group needs next.
  ///
  /// Ordering matters — the personal state ("you're done, waiting on X") is
  /// more useful than the weekly total once you've checked in today.
  static String goalHint(GroupGoalProgress goal, {bool isSolo = false}) {
    // GROUP completion.
    if (goal.status == GoalStatus.completed) {
      return isSolo ? 'Complete for the week 🎉' : 'Everyone hit this one 🎉';
    }

    // I'm done today, someone else isn't.
    if (goal.waitingOnOthersToday) {
      final others = goal.othersPendingToday;
      if (others.length == 1) {
        return 'You\'re done — waiting on ${others.first.name.split(' ').first}';
      }
      return 'You\'re done — waiting on ${count(others.length, 'other')}';
    }

    // I still owe today's check-in.
    if (!goal.currentUserCompletedToday) {
      final remaining = goal.remaining;
      if (goal.unreachableThisWeek) return 'Fresh start next week';
      return isSolo
          ? '${count(remaining, 'more check-in')} needed this week'
          : '${count(remaining, 'more check-in')} needed together';
    }

    // Everyone has done today, but the week isn't finished yet — describe the
    // real status rather than always claiming "on track".
    switch (goal.status) {
      case GoalStatus.atRisk:
        return goal.unreachableThisWeek
            ? 'Fresh start next week'
            : 'Everyone in today — but it\'s tight';
      case GoalStatus.needsAttention:
        return 'Everyone in today — still a bit behind';
      default:
        return isSolo ? 'On track' : 'On track together';
    }
  }

  // ── Group streak ─────────────────────────────────────────────────────────
  static StatusPresentation forStreak(GroupProgress progress) {
    final weeks = progress.groupStreak;

    switch (progress.streakStatus) {
      case StreakStatus.safe:
        return StatusPresentation(
          color: AppTheme.accent,
          label: weeks > 0 ? weekStreakLabel(weeks) : 'On track',
          icon: Icons.local_fire_department_rounded,
          encouragement: 'Streak safe for this week',
        );

      case StreakStatus.atRisk:
        final needed = progress.goals
            .where((g) => g.status == GoalStatus.atRisk)
            .fold<int>(0, (sum, g) => sum + g.remaining);
        return StatusPresentation(
          color: AppTheme.warning,
          label: weekStreakLabel(weeks),
          icon: Icons.local_fire_department_rounded,
          encouragement: needed > 0
              ? 'Your ${weekStreakLabel(weeks)} needs ${count(needed, 'more check-in')}'
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
          encouragement: '${health.score}% consistency this week',
        );
      case HealthLabel.needsAttention:
        return StatusPresentation(
          color: AppTheme.accent,
          label: 'Needs attention',
          icon: Icons.favorite_border_rounded,
          encouragement: '${health.score}% consistency this week',
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
  ///
  /// Picks between three genuinely different states rather than one counter:
  /// "waiting on anyone" used to be reported as "needs both of you" even when
  /// the reader had already checked in and only a teammate was outstanding.
  static String todayHeadline(GroupProgress progress) {
    final anyone = progress.todaySummary.goalsWaitingOnAnyoneToday;
    final waitingOnMe = progress.todaySummary.goalsWaitingOnMeToday;
    final waitingOnOthersOnly = progress.todaySummary.goalsWaitingOnOthersOnlyToday;

    if (progress.goals.isEmpty) return 'No rituals yet';

    if (anyone == 0) {
      return progress.isSolo ? 'All done for today 🎉' : 'Everyone\'s done today 🎉';
    }

    if (progress.isSolo) {
      return '${count(waitingOnMe, 'ritual')} waiting on you';
    }

    // I'm fully checked in today; only teammates are outstanding.
    if (waitingOnMe == 0 && waitingOnOthersOnly > 0) {
      final others = progress.otherMembers.where((m) => !m.completedToday).toList();
      if (others.length == 1) {
        return '${count(waitingOnOthersOnly, 'ritual')} waiting on ${others.first.displayName}';
      }
      return '${count(waitingOnOthersOnly, 'ritual')} waiting on ${count(others.length, 'other')}';
    }

    if (progress.memberCount == 2) {
      return '${count(anyone, 'ritual')} ${plural(anyone, 'needs', 'need')} both of you today';
    }

    return '${count(anyone, 'ritual')} ${plural(anyone, 'needs', 'need')} everyone today';
  }

  /// "1/2 members checked in" — explicitly a member count, not a ritual count.
  static String checkedInToday(GroupProgress progress) =>
      '${progress.todaySummary.membersDoneToday}/${progress.memberCount} '
      '${plural(progress.memberCount, 'member')} checked in';
}
