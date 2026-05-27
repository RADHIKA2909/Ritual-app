import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/goal_provider.dart';
import 'edit_goal_dialog.dart';

class GoalCard extends ConsumerStatefulWidget {
  final String goalId;
  final String groupId;
  final String goalName;
  final String icon;
  final int weeklyMinimum;
  final bool isAdmin;
  final List<dynamic> groupMembers;

  const GoalCard({
    super.key,
    required this.goalId,
    required this.groupId,
    required this.goalName,
    required this.icon,
    required this.weeklyMinimum,
    this.isAdmin = false,
    this.groupMembers = const [],
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

  (int streak, int currentWeekTicks) _computeWeeklyStats(List<dynamic> checkIns) {
    if (checkIns.isEmpty) return (0, 0);
    final members = widget.groupMembers;
    final Map<DateTime, Map<String, int>> weeklyUserTicks = {};

    for (var c in checkIns) {
      if (c['completed'] != true) continue;
      final d = DateTime.parse(c['date']).toLocal();
      final weekStart = DateTime(d.year, d.month, d.day)
          .subtract(Duration(days: d.weekday - 1));
      final userId = c['userId'].toString();
      weeklyUserTicks.putIfAbsent(weekStart, () => {});
      weeklyUserTicks[weekStart]!.update(userId, (v) => v + 1, ifAbsent: () => 1);
    }

    final Map<DateTime, int> weeklyDuoTicks = {};
    weeklyUserTicks.forEach((weekStart, userTicksMap) {
      int minTicks = 999;
      final check = members.isNotEmpty ? members : userTicksMap.keys.toList();
      for (var member in check) {
        final id = member is Map ? member['_id'].toString() : member.toString();
        final t = userTicksMap[id] ?? 0;
        if (t < minTicks) minTicks = t;
      }
      weeklyDuoTicks[weekStart] = minTicks == 999 ? 0 : minTicks;
    });

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final currentWeekStart =
        todayDate.subtract(Duration(days: todayDate.weekday - 1));
    int streak = 0;
    final currentWeekTicks = weeklyDuoTicks[currentWeekStart] ?? 0;
    if (currentWeekTicks >= widget.weeklyMinimum) streak++;

    for (int i = 1; i < 520; i++) {
      final ws = currentWeekStart.subtract(Duration(days: i * 7));
      if ((weeklyDuoTicks[ws] ?? 0) >= widget.weeklyMinimum) {
        streak++;
      } else {
        break;
      }
    }
    return (streak, currentWeekTicks);
  }

  void _toggleMyDay(DateTime date) {
    HapticFeedback.lightImpact();
    ref.read(checkInProvider.notifier).toggleCheckIn(widget.goalId, date);
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
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (i) {
          final d = monday.add(Duration(days: i));
          final dOnly = DateTime(d.year, d.month, d.day);
          return _buildDayDot(
              context, dOnly, checkIns, dayLabels[i], isMe, userIdToMatch);
        }),
      ),
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
    final stats = _computeWeeklyStats(checkIns);
    final streak = stats.$1;
    final currentWeekTicks = stats.$2;
    final target = widget.weeklyMinimum;
    final progress = (currentWeekTicks / target).clamp(0.0, 1.0);
    final isWeekMet = currentWeekTicks >= target;
    final cs = Theme.of(context).colorScheme;

    final partnerMember = widget.groupMembers.firstWhere(
      (m) => m is Map && m['_id']?.toString() != currentUserId,
      orElse: () => null,
    );
    final partnerLabel = partnerMember != null
        ? (partnerMember['name'] as String).split(' ').first
        : 'Partner';
    final allUserIds =
        checkIns.map((c) => c['userId'] as String).toSet();
    final partnerId = allUserIds.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
    final hasPartner = widget.groupMembers.length > 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.45),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isWeekMet
              ? cs.primary.withOpacity(0.3)
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
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3)),
                const SizedBox(height: 6),
                Row(children: [
                  if (streak > 0) ...[
                    const Text('🔥', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 3),
                    Text('$streak wk',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.orange)),
                    const SizedBox(width: 8),
                  ],
                  Text('$currentWeekTicks/$target this week',
                      style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withOpacity(0.45))),
                ]),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: cs.onSurface.withOpacity(0.08),
                    color: isWeekMet ? const Color(0xFF48BB78) : cs.primary,
                  ),
                ),
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
                    title: const Text('Delete Goal?'),
                    content: const Text(
                        'This will permanently delete this goal and all check-ins.'),
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
                            style: TextStyle(color: Colors.red)),
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

          const SizedBox(height: 20),
          Container(height: 1, color: cs.onSurface.withOpacity(0.06)),
          const SizedBox(height: 16),

          // ── Week trackers ───────────────────────────────────────────
          _buildWeekRow(context, 'YOU', checkIns, true, currentUserId),
          if (hasPartner) ...[
            const SizedBox(height: 16),
            _buildWeekRow(
              context,
              partnerLabel.toUpperCase(),
              checkIns,
              false,
              partnerId.isEmpty ? null : partnerId,
            ),
          ],
        ]),
      ),
    );
  }
}
