import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/goal_provider.dart';

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
    setState(() {
      currentUserId = prefs.getString('user_id');
    });
  }

  /// Compute consecutive weekly streak and current week's duo ticks
  (int streak, int currentWeekTicks) _computeWeeklyStats(List<dynamic> checkIns) {
    if (checkIns.isEmpty) return (0, 0);

    final members = widget.groupMembers;

    // weeklyUserTicks: weekStart -> userId -> count
    final Map<DateTime, Map<String, int>> weeklyUserTicks = {};

    for (var c in checkIns) {
      if (c['completed'] != true) continue;
      
      final d = DateTime.parse(c['date']).toLocal();
      final weekStart = DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));
      final userId = c['userId'].toString();

      weeklyUserTicks.putIfAbsent(weekStart, () => {});
      weeklyUserTicks[weekStart]!.update(userId, (v) => v + 1, ifAbsent: () => 1);
    }

    final Map<DateTime, int> weeklyDuoTicks = {};

    weeklyUserTicks.forEach((weekStart, userTicksMap) {
       int groupTicks = 0;
       if (members.isNotEmpty) {
         int minTicks = 999;
         for (var member in members) {
           final memberId = member['_id'].toString();
           final ticks = userTicksMap[memberId] ?? 0;
           if (ticks < minTicks) minTicks = ticks;
         }
         groupTicks = minTicks == 999 ? 0 : minTicks;
       } else {
         int minTicks = 999;
         for (var ticks in userTicksMap.values) {
           if (ticks < minTicks) minTicks = ticks;
         }
         groupTicks = minTicks == 999 ? 0 : minTicks;
       }
       weeklyDuoTicks[weekStart] = groupTicks;
    });

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final currentWeekStart = todayDate.subtract(Duration(days: todayDate.weekday - 1));
    
    int streak = 0;
    
    // Check if current week meets target
    final currentWeekTicks = weeklyDuoTicks[currentWeekStart] ?? 0;
    if (currentWeekTicks >= widget.weeklyMinimum) {
      streak++;
    }

    // Check previous consecutive weeks backwards
    for (int i = 1; i < 520; i++) {
      final weekStart = currentWeekStart.subtract(Duration(days: i * 7));
      if ((weeklyDuoTicks[weekStart] ?? 0) >= widget.weeklyMinimum) {
        streak++;
      } else {
        break; // Streak broken
      }
    }

    return (streak, currentWeekTicks);
  }

  void _toggleMyDay(DateTime date) {
    HapticFeedback.lightImpact();
    ref.read(checkInProvider.notifier).toggleCheckIn(widget.goalId, date);
  }

  Widget _buildWeekTracker(String userName, List<dynamic> checkIns, bool isMe, String? userIdToMatch) {
    // Build array of last 7 days starting from Monday
    final now = DateTime.now();
    // 1 = Monday, 7 = Sunday
    final currentDayOfWeek = now.weekday;
    final monday = now.subtract(Duration(days: currentDayOfWeek - 1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          userName,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (index) {
            final targetDate = monday.add(Duration(days: index));
            final targetDateOnly = DateTime(targetDate.year, targetDate.month, targetDate.day);
            final todayDateOnly = DateTime(now.year, now.month, now.day);
            final isFuture = targetDateOnly.isAfter(todayDateOnly);

            // Check if this date has a checkin for this user
            final hasCheckedIn = checkIns.any((c) {
              final checkInDate = DateTime.parse(c['date']).toLocal();
              return c['userId'] == userIdToMatch &&
                  c['completed'] == true &&
                  checkInDate.year == targetDate.year &&
                  checkInDate.month == targetDate.month &&
                  checkInDate.day == targetDate.day;
            });

            return GestureDetector(
              onTap: (isMe && !isFuture) ? () => _toggleMyDay(targetDate) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.elasticOut,
                width: hasCheckedIn ? 38 : 34,
                height: hasCheckedIn ? 38 : 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasCheckedIn
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceVariant.withOpacity(isFuture ? 0.2 : 0.5),
                  border: Border.all(
                    color: hasCheckedIn
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface.withOpacity(isFuture ? 0.05 : 0.1),
                    width: 2,
                  ),
                ),
                child: hasCheckedIn
                    ? AnimatedOpacity(
                        opacity: 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.check_rounded,
                          size: 20,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : null,
              ),
            );
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final checkInState = ref.watch(checkInProvider);
    final allCheckInsMap = checkInState.value ?? {};
    final checkIns = allCheckInsMap[widget.goalId] ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Text(
                  widget.icon,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.goalName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Builder(builder: (ctx) {
                        final allCheckInsMap = ref.watch(checkInProvider).value ?? {};
                        final checkIns = allCheckInsMap[widget.goalId] ?? [];
                        final stats = _computeWeeklyStats(checkIns);
                        final streak = stats.$1;
                        final currentWeekTicks = stats.$2;
                        final target = widget.weeklyMinimum;
                        final isWeekMet = currentWeekTicks >= target;
                        final progress = (currentWeekTicks / target).clamp(0.0, 1.0);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.local_fire_department, color: Colors.orange, size: 13),
                                const SizedBox(width: 2),
                                Text(
                                  '$streak week streak',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '· $currentWeekTicks/$target this wk',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Sleek Progress Bar
                            Container(
                              height: 4,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: progress,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isWeekMet ? Colors.greenAccent : const Color(0xFF6C63FF),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
                if (widget.isAdmin)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Goal?'),
                          content: const Text('This will permanently delete this goal and its check-in history.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                ref.read(goalsProvider.notifier).deleteGoal(widget.goalId, widget.groupId);
                                Navigator.pop(context);
                              },
                              child: const Text('Delete', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 24),
            
            Builder(
              builder: (context) {
                // Only show Partner row if there are other members in the group
                final hasPartner = widget.groupMembers.length > 1;

                // Determine partner's ID (any ID that is not current user)
                final allUserIds = checkIns.map((c) => c['userId'] as String).toSet();
                final partnerId = allUserIds.firstWhere(
                  (id) => id != currentUserId,
                  orElse: () => '',
                );

                // Get partner's name from group members
                String partnerLabel = 'Partner';
                if (hasPartner) {
                  final partnerMember = widget.groupMembers.firstWhere(
                    (m) => m is Map && m['_id']?.toString() != currentUserId,
                    orElse: () => null,
                  );
                  if (partnerMember != null && partnerMember is Map) {
                    final fullName = partnerMember['name'] as String? ?? 'Partner';
                    partnerLabel = fullName.split(' ').first;
                  }
                }

                return Column(
                  children: [
                    _buildWeekTracker('You', checkIns, true, currentUserId),
                    if (hasPartner) ...
                      [
                        const SizedBox(height: 16),
                        _buildWeekTracker(partnerLabel, checkIns, false,
                            partnerId.isEmpty ? null : partnerId),
                      ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
