import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/goal_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/status_style.dart';
import '../../../groups/domain/models/group_progress.dart';
import '../../../groups/presentation/widgets/group_status_widgets.dart';
import 'check_in_button.dart';
import 'edit_goal_dialog.dart';

class GoalCard extends ConsumerStatefulWidget {
  final String goalId;
  final String groupId;
  final String goalName;
  final String icon;
  final int weeklyMinimum;
  final bool isAdmin;
  final List<dynamic> groupMembers;

  /// Server-derived progress for this goal — group score, per-member shares and
  /// status. The card renders it; it never recomputes any of it.
  final GroupGoalProgress progress;

  final bool isSolo;

  const GoalCard({
    super.key,
    required this.goalId,
    required this.groupId,
    required this.goalName,
    required this.icon,
    required this.weeklyMinimum,
    required this.progress,
    this.isAdmin = false,
    this.groupMembers = const [],
    this.isSolo = false,
  });

  @override
  ConsumerState<GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends ConsumerState<GoalCard> {
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    _loadUserId();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(checkInProvider.notifier).fetchCheckIns(widget.goalId);
    });
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => currentUserId = prefs.getString('user_id'));
  }

  // The weekly/streak maths that used to live here now comes from the server
  // (see backend/src/services/progressService.ts) via widget.progress, so the
  // client and the streak endpoint can no longer disagree.

  void _toggleMyDay(DateTime date) {
    HapticFeedback.lightImpact();
    // Explicit target rather than a blind flip, so a double tap converges.
    final target = !ref
        .read(checkInProvider.notifier)
        .isCompletedOn(widget.goalId, currentUserId ?? '', date);
    ref.read(checkInProvider.notifier).setCheckIn(widget.goalId, date, target);
  }

  Widget _buildDayDot(
    BuildContext context,
    DateTime targetDate,
    List<dynamic> checkIns,
    String dayLabel,
    bool isMe,
    String? userIdToMatch,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isFuture = targetDate.isAfter(today);
    final isToday = targetDate.isAtSameMomentAs(today);

    final hasCheckedIn = checkIns.any((c) {
      final d = DateTime.parse(c['date']).toLocal();
      return c['userId'] == userIdToMatch &&
          c['completed'] == true &&
          d.year == targetDate.year &&
          d.month == targetDate.month &&
          d.day == targetDate.day;
    });

    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: (isMe && !isFuture) ? () => _toggleMyDay(targetDate) : null,
      child: Column(children: [
        Text(
          dayLabel,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: isToday
                ? cs.primary
                : cs.onSurface.withOpacity(isFuture ? 0.2 : 0.35),
          ),
        ),
        const SizedBox(height: 5),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutBack,
          width: hasCheckedIn ? 36 : 32,
          height: hasCheckedIn ? 36 : 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasCheckedIn
                ? cs.primary
                : isFuture
                    ? cs.surfaceVariant.withOpacity(0.2)
                    : cs.surfaceVariant.withOpacity(0.55),
            border: Border.all(
              color: isToday && !hasCheckedIn
                  ? cs.primary.withOpacity(0.5)
                  : hasCheckedIn
                      ? cs.primary
                      : cs.onSurface.withOpacity(isFuture ? 0.05 : 0.08),
              width: isToday ? 2 : 1.5,
            ),
          ),
          child: hasCheckedIn
              ? Icon(Icons.check_rounded, size: 18, color: cs.onPrimary)
              : isMe && isToday
                  ? Icon(Icons.add_rounded,
                      size: 16, color: cs.primary.withOpacity(0.6))
                  : null,
        ),
      ]),
    );
  }

  // Find today's completed check-in for a given user
  Map<String, dynamic>? _findTodayCheckIn(List<dynamic> checkIns, String? userId) {
    if (userId == null) return null;
    final now = DateTime.now();
    try {
      return checkIns.firstWhere((c) {
        if (c['userId'].toString() != userId) return false;
        if (c['completed'] != true) return false;
        final d = DateTime.parse(c['date']).toLocal();
        return d.year == now.year && d.month == now.month && d.day == now.day;
      }) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Widget _buildReactionStrip(
    BuildContext context,
    Map<String, dynamic> todayCheckIn,
    bool isMyCheckIn,
  ) {
    const reactionEmojis = ['🔥', '👏', '💪', '❤️', '💯'];
    final cs = Theme.of(context).colorScheme;
    final checkInId = todayCheckIn['_id'].toString();
    final reactions = (todayCheckIn['reactions'] as List<dynamic>?) ?? [];

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: reactionEmojis.map((emoji) {
          final myReaction = reactions.any(
            (r) => r['userId'].toString() == currentUserId && r['emoji'] == emoji,
          );
          final count = reactions.where((r) => r['emoji'] == emoji).length;

          // Can only react to others' check-ins
          final canReact = !isMyCheckIn;

          return GestureDetector(
            onTap: canReact
                ? () {
                    HapticFeedback.lightImpact();
                    ref.read(checkInProvider.notifier)
                        .reactToCheckIn(widget.goalId, checkInId, emoji);
                  }
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: myReaction
                    ? cs.primary.withOpacity(0.12)
                    : cs.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: myReaction
                      ? cs.primary.withOpacity(0.4)
                      : cs.onSurface.withOpacity(0.07),
                  width: 1.5,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(emoji, style: const TextStyle(fontSize: 13)),
                if (count > 0) ...[
                  const SizedBox(width: 3),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: myReaction
                          ? cs.primary
                          : cs.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWeekRow(
    BuildContext context,
    String label,
    List<dynamic> checkIns,
    bool isMe,
    String? userIdToMatch,
  ) {
    final now = DateTime.now();
    final monday =
        now.subtract(Duration(days: now.weekday - 1));
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    final todayCheckIn = _findTodayCheckIn(checkIns, userIdToMatch);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
            letterSpacing: 0.3,
          )),
      const SizedBox(height: 8),
      // The 7 dots need ~36px each at full (checked) size — spaceBetween
      // can't shrink them, so a narrow browser window would overflow. Below
      // that width, scroll horizontally instead; normal-width cards are
      // unaffected since spaceBetween still renders exactly as before.
      LayoutBuilder(builder: (context, constraints) {
        final dots = List.generate(7, (i) {
          final d = monday.add(Duration(days: i));
          final dOnly = DateTime(d.year, d.month, d.day);
          return _buildDayDot(
              context, dOnly, checkIns, dayLabels[i], isMe, userIdToMatch);
        });
        const naturalWidth = 7 * 36.0 + 6 * 4.0;
        if (constraints.maxWidth >= naturalWidth) {
          return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: dots);
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final dot in dots) Padding(padding: const EdgeInsets.only(right: 8), child: dot),
            ],
          ),
        );
      }),
      if (todayCheckIn != null) ...[
        _buildReactionStrip(context, todayCheckIn, isMe),
        _buildNoteRow(context, todayCheckIn, isMe),
      ],
    ]);
  }

  void _showNoteSheet(BuildContext context, Map<String, dynamic> todayCheckIn) {
    final existing = (todayCheckIn['note'] as String?) ?? '';
    final controller = TextEditingController(text: existing);
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: cs.onSurface.withOpacity(0.12),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            existing.isEmpty ? 'Add a note' : 'Edit note',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            maxLength: 200,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'How did it go? e.g. Ran 5k, felt great!',
              hintStyle: TextStyle(color: cs.onSurface.withOpacity(0.35)),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            if (existing.isNotEmpty)
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(checkInProvider.notifier).updateNote(
                        widget.goalId, todayCheckIn['_id'].toString(), '');
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: cs.onSurface.withOpacity(0.15)),
                  ),
                  child: const Text('Remove'),
                ),
              ),
            if (existing.isNotEmpty) const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  ref.read(checkInProvider.notifier).updateNote(
                      widget.goalId,
                      todayCheckIn['_id'].toString(),
                      controller.text.trim());
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Save',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _buildNoteRow(
    BuildContext context,
    Map<String, dynamic> todayCheckIn,
    bool isMe,
  ) {
    final note = (todayCheckIn['note'] as String?) ?? '';
    final cs = Theme.of(context).colorScheme;
    final hasNote = note.isNotEmpty;

    if (!isMe && !hasNote) return const SizedBox.shrink();

    return GestureDetector(
      onTap: isMe ? () => _showNoteSheet(context, todayCheckIn) : null,
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(children: [
          Icon(
            hasNote ? Icons.notes_rounded : Icons.edit_note_rounded,
            size: 15,
            color: hasNote
                ? cs.onSurface.withOpacity(0.55)
                : cs.onSurface.withOpacity(0.25),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              hasNote ? note : 'Add a note…',
              style: TextStyle(
                fontSize: 12,
                fontStyle: hasNote ? FontStyle.normal : FontStyle.italic,
                color: hasNote
                    ? cs.onSurface.withOpacity(0.6)
                    : cs.onSurface.withOpacity(0.25),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isMe && hasNote)
            Icon(Icons.chevron_right_rounded,
                size: 14, color: cs.onSurface.withOpacity(0.2)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final checkInState = ref.watch(checkInProvider);
    final checkIns = (checkInState.value ?? {})[widget.goalId] ?? [];
    final goal = widget.progress;
    final status = StatusStyle.forGoal(goal);
    final isWeekMet = goal.status == GoalStatus.completed;
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.45),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isWeekMet
              ? AppTheme.success.withOpacity(0.4)
              : cs.onSurface.withOpacity(0.07),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header ─────────────────────────────────────────────────
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(
              onTap: () => context.push('/goal/${widget.goalId}/history', extra: {
                'goalName': widget.goalName,
                'goalIcon': widget.icon,
                'groupMembers': widget.groupMembers,
              }),
              child: Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                    child: Text(widget.icon,
                        style: const TextStyle(fontSize: 22))),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: GestureDetector(
                onTap: () => context.push('/goal/${widget.goalId}/history', extra: {
                  'goalName': widget.goalName,
                  'goalIcon': widget.icon,
                  'groupMembers': widget.groupMembers,
                }),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(widget.goalName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3)),
                const SizedBox(height: 6),
                // Status chip. Note there is deliberately no streak here —
                // the streak is a group-level moment and lives on the group
                // header, not on every card.
                Row(children: [
                  Icon(status.icon, size: 13, color: status.color),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      status.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: status.color),
                    ),
                  ),
                ]),
              ]),
            ),  // closes GestureDetector
            ),  // closes Expanded
            if (widget.isAdmin) ...[
              const SizedBox(width: 4),
              // Edit button
              GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => EditGoalDialog(
                    goalId: widget.goalId,
                    groupId: widget.groupId,
                    initialName: widget.goalName,
                    initialIcon: widget.icon,
                    initialWeeklyMinimum: widget.weeklyMinimum,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cs.onSurface.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.edit_outlined,
                      size: 16, color: cs.onSurface.withOpacity(0.3)),
                ),
              ),
              const SizedBox(width: 4),
              // Delete button
              GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    title: const Text('Delete Ritual?'),
                    content: const Text(
                        'This will permanently delete this ritual and all check-ins.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel')),
                      TextButton(
                        onPressed: () {
                          ref
                              .read(goalsProvider.notifier)
                              .deleteGoal(widget.goalId, widget.groupId);
                          Navigator.pop(context);
                        },
                        child: const Text('Delete',
                            style: TextStyle(color: AppTheme.danger)),
                      ),
                    ],
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cs.onSurface.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.delete_outline_rounded,
                      size: 16, color: cs.onSurface.withOpacity(0.3)),
                ),
              ),
            ],
          ]),

          const SizedBox(height: 16),

          // ── Our progress vs mine ────────────────────────────────────
          DualProgressBars(goal: goal, isSolo: widget.isSolo),

          const SizedBox(height: 12),

          // ── Today's action + what the group still needs ─────────────
          Row(children: [
            Expanded(
              child: Text(
                StatusStyle.goalHint(goal, isSolo: widget.isSolo),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withOpacity(0.55),
                  letterSpacing: -0.1,
                ),
              ),
            ),
            const SizedBox(width: 10),
            CheckInButton(
              goalId: widget.goalId,
              groupId: widget.groupId,
              date: DateTime.now(),
              isCompleted: goal.currentUserCompletedToday,
              size: CheckInButtonSize.compact,
            ),
          ]),

          const SizedBox(height: 16),
          Container(height: 1, color: cs.onSurface.withOpacity(0.06)),
          const SizedBox(height: 16),

          // ── Each member's week ──────────────────────────────────────
          // One row per member, from the server's per-member breakdown.
          // Previously this was hard-wired to two people, and resolved the
          // partner's NAME from groupMembers while resolving their DOTS from
          // the check-in rows — so in a group of 3+ the label and the data
          // could describe different people.
          if (!widget.isSolo) ...[
            MemberContributionList(members: goal.memberProgress),
            const SizedBox(height: 12),
          ],

          // Your own week, with tappable days for back-filling.
          _buildWeekRow(context, widget.isSolo ? 'THIS WEEK' : 'YOUR WEEK',
              checkIns, true, currentUserId),
        ]),
      ),
    );
  }
}
