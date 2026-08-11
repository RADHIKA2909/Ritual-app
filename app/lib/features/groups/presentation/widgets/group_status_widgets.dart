import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/status_style.dart';
import '../../../../core/utils/plurals.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../domain/models/group_progress.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Small shared pieces for showing GROUP state.
//
// Reused by Home, Groups, Rituals and Group Detail so "our progress" reads the
// same everywhere. All copy comes from StatusStyle.
// ─────────────────────────────────────────────────────────────────────────────

/// 🔥 4-week streak — amber when safe, amber-orange when it needs attention.
///
/// Streaks are a group-level moment, so this is deliberately NOT rendered on
/// every goal card; it belongs on group headers and hero cards.
class StreakPill extends StatelessWidget {
  final GroupProgress progress;
  final bool compact;

  const StreakPill({super.key, required this.progress, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final style = StatusStyle.forStreak(progress);
    final atRisk = progress.streakStatus == StreakStatus.atRisk;

    // Nothing to celebrate yet — stay quiet rather than showing "0".
    if (progress.groupStreak == 0 && !atRisk) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: style.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: style.color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🔥', style: TextStyle(fontSize: compact ? 11 : 13)),
          const SizedBox(width: 5),
          Text(
            compact
                ? weekStreakShort(progress.groupStreak)
                : weekStreakLabel(progress.groupStreak),
            style: TextStyle(
              color: style.color,
              fontSize: compact ? 11 : 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          if (atRisk) ...[
            const SizedBox(width: 5),
            Icon(Icons.bolt_rounded, size: compact ? 12 : 14, color: style.color),
          ],
        ],
      ),
    );
  }
}

/// A coloured dot + label for group health, e.g. "🟢 Strong · 86%".
///
/// Health is the nuanced companion to the strict binary streak: a group can
/// have a broken streak and still be doing well.
class GroupHealthChip extends StatelessWidget {
  final GroupHealth health;
  final bool showScore;
  final bool compact;

  const GroupHealthChip({
    super.key,
    required this.health,
    this.showScore = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = StatusStyle.forHealth(health);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: style.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: style.color.withOpacity(0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 6 : 7,
            height: compact ? 6 : 7,
            decoration: BoxDecoration(color: style.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            showScore ? '${style.label} · ${health.score}%' : style.label,
            style: TextStyle(
              color: style.color,
              fontSize: compact ? 11 : 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Who has checked in today — avatars with a green tick or a waiting ring.
///
/// Scrolls horizontally so groups larger than a couple of people don't overflow
/// (the previous fixed Row did).
class MemberStatusRow extends StatelessWidget {
  final List<GroupMemberProgress> members;
  final double avatarRadius;
  final void Function(GroupMemberProgress member)? onMemberTap;

  const MemberStatusRow({
    super.key,
    required this.members,
    this.avatarRadius = 18,
    this.onMemberTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final m in members)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: GestureDetector(
                onTap: onMemberTap == null ? null : () => onMemberTap!(m),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        UserAvatar(
                          name: m.name,
                          profileImage: m.profileImage,
                          radius: avatarRadius,
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: cs.surface,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              m.completedToday
                                  ? Icons.check_circle_rounded
                                  : Icons.schedule_rounded,
                              size: 14,
                              color: m.completedToday
                                  ? AppTheme.success
                                  : cs.onSurface.withOpacity(0.28),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Capped to the avatar's width so a long name can't widen
                    // this cell and break the row's alignment — it sits inside
                    // an unbounded horizontal scroller, so without a cap the
                    // Text would simply render at its full intrinsic width.
                    SizedBox(
                      width: avatarRadius * 2.4,
                      child: Text(
                        m.displayName,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface.withOpacity(m.completedToday ? 0.7 : 0.4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The core "our progress vs my progress" widget.
///
/// Shows the group's shared score (the weakest link, which is what the streak
/// actually counts) above the current user's own contribution, so it's obvious
/// both what the team needs and what you personally still owe.
class DualProgressBars extends StatelessWidget {
  final GroupGoalProgress goal;
  final bool isSolo;

  const DualProgressBars({super.key, required this.goal, this.isSolo = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = StatusStyle.forGoal(goal);
    final target = goal.groupTarget == 0 ? 1 : goal.groupTarget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group line — the number the streak is actually based on.
        if (!isSolo) ...[
          _Bar(
            label: 'Together',
            value: goal.groupCompletedCount,
            target: goal.groupTarget,
            fraction: (goal.groupCompletedCount / target).clamp(0.0, 1.0),
            color: status.color,
            emphasised: true,
          ),
          const SizedBox(height: 8),
        ],
        _Bar(
          label: isSolo ? 'This week' : 'You',
          value: goal.currentUserCount,
          target: goal.groupTarget,
          fraction: (goal.currentUserCount / target).clamp(0.0, 1.0),
          color: goal.currentUserCount >= goal.groupTarget
              ? AppTheme.success
              : cs.primary,
          emphasised: isSolo,
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  final String label;
  final int value;
  final int target;
  final double fraction;
  final Color color;
  final bool emphasised;

  const _Bar({
    required this.label,
    required this.value,
    required this.target,
    required this.fraction,
    required this.color,
    this.emphasised = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: emphasised ? FontWeight.w800 : FontWeight.w600,
                color: cs.onSurface.withOpacity(emphasised ? 0.72 : 0.5),
                letterSpacing: -0.1,
              ),
            ),
            const Spacer(),
            Text(
              '$value/$target',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: emphasised ? 7 : 5,
            backgroundColor: cs.onSurface.withOpacity(0.07),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

/// Per-member weekly contribution rows, for any group size.
///
/// Replaces the old two-person hard-wiring, which resolved the partner's name
/// and their check-in dots from different sources — so in a group of three or
/// more the label and the data could belong to different people.
class MemberContributionList extends StatefulWidget {
  final List<MemberGoalProgress> members;
  final int collapseAfter;

  const MemberContributionList({
    super.key,
    required this.members,
    this.collapseAfter = 3,
  });

  @override
  State<MemberContributionList> createState() => _MemberContributionListState();
}

class _MemberContributionListState extends State<MemberContributionList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final all = widget.members;
    final needsCollapse = all.length > widget.collapseAfter;
    final visible = (!needsCollapse || _expanded)
        ? all
        : all.sublist(0, widget.collapseAfter);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final m in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                UserAvatar(name: m.name, profileImage: m.profileImage, radius: 11),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    m.isCurrentUser ? 'You' : m.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: m.isCurrentUser ? FontWeight.w700 : FontWeight.w600,
                      color: cs.onSurface.withOpacity(0.65),
                    ),
                  ),
                ),
                if (m.completedToday) ...[
                  const Icon(Icons.check_circle_rounded,
                      size: 13, color: AppTheme.success),
                  const SizedBox(width: 6),
                ],
                Text(
                  '${m.completedCount}/${m.target}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: m.hasMetTarget
                        ? AppTheme.success
                        : cs.onSurface.withOpacity(0.45),
                  ),
                ),
              ],
            ),
          ),
        if (needsCollapse)
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _expanded ? 'Show less' : 'Show all ${all.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
