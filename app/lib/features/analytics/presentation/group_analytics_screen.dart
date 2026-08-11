import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../domain/analytics_provider.dart';
import '../../../core/network/socket_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/plurals.dart';

class GroupAnalyticsScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GroupAnalyticsScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupAnalyticsScreen> createState() =>
      _GroupAnalyticsScreenState();
}

class _GroupAnalyticsScreenState extends ConsumerState<GroupAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final Function(dynamic) _checkinHandler;
  late final Function(dynamic) _goalHandler;
  DateTime _selectedMonth = DateTime.now();
  String? _selectedGoalId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkinHandler = (_) {
      if (mounted) ref.invalidate(analyticsProvider(widget.groupId));
    };
    _goalHandler = (_) {
      if (mounted) ref.invalidate(analyticsProvider(widget.groupId));
    };
    SocketService().on('checkin_updated', _checkinHandler);
    SocketService().on('goal_updated', _goalHandler);
  }

  @override
  void dispose() {
    SocketService().off('checkin_updated', _checkinHandler);
    SocketService().off('goal_updated', _goalHandler);
    _tabController.dispose();
    super.dispose();
  }

  void _previousMonth() =>
      setState(() => _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month - 1));

  void _nextMonth() =>
      setState(() => _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + 1));

  int _calculateDuoTicks(String goalId, DateTime start, DateTime end,
      List<dynamic> checkIns, List<dynamic> members) {
    final Map<String, int> userTicks = {};
    for (final c in checkIns) {
      if (c['goalId'] != goalId || c['completed'] != true) continue;
      final d = DateTime.parse(c['date']).toLocal();
      final dayOnly = DateTime(d.year, d.month, d.day);
      if (dayOnly.isBefore(start) || dayOnly.isAfter(end)) continue;
      final userId = c['userId'].toString();
      userTicks.update(userId, (v) => v + 1, ifAbsent: () => 1);
    }
    if (members.isNotEmpty) {
      int minTicks = 999;
      for (var m in members) {
        final t = userTicks[m.toString()] ?? 0;
        if (t < minTicks) minTicks = t;
      }
      return minTicks == 999 ? 0 : minTicks;
    } else {
      int minTicks = 999;
      for (var t in userTicks.values) {
        if (t < minTicks) minTicks = t;
      }
      return minTicks == 999 ? 0 : minTicks;
    }
  }

  int _calculateUniqueMembersCompleted(
      String goalId, DateTime day, List<dynamic> checkIns) {
    final Set<String> uniqueUsers = {};
    for (final c in checkIns) {
      if (c['goalId'] != goalId || c['completed'] != true) continue;
      final d = DateTime.parse(c['date']).toLocal();
      if (d.year == day.year && d.month == day.month && d.day == day.day) {
        uniqueUsers.add(c['userId'].toString());
      }
    }
    return uniqueUsers.length;
  }

  int _computeGoalWeeklyStreak(Map<String, dynamic> goal,
      List<dynamic> checkIns, List<dynamic> members) {
    final goalId = goal['_id'];
    final target = goal['weeklyMinimum'] ?? 0;
    final goalCheckIns =
        checkIns.where((c) => c['goalId'] == goalId && c['completed'] == true).toList();
    if (goalCheckIns.isEmpty) return 0;

    final Map<DateTime, Map<String, int>> weeklyUserTicks = {};
    for (final c in goalCheckIns) {
      final d = DateTime.parse(c['date']).toLocal();
      final weekStart = DateTime(d.year, d.month, d.day)
          .subtract(Duration(days: d.weekday - 1));
      final userId = c['userId'].toString();
      weeklyUserTicks.putIfAbsent(weekStart, () => {});
      weeklyUserTicks[weekStart]!
          .update(userId, (v) => v + 1, ifAbsent: () => 1);
    }

    final Map<DateTime, int> weeklyDuoTicks = {};
    weeklyUserTicks.forEach((weekStart, userMap) {
      if (members.isNotEmpty) {
        int minTicks = 999;
        for (var m in members) {
          final t = userMap[m.toString()] ?? 0;
          if (t < minTicks) minTicks = t;
        }
        weeklyDuoTicks[weekStart] = minTicks == 999 ? 0 : minTicks;
      } else {
        int minTicks = 999;
        for (var t in userMap.values) {
          if (t < minTicks) minTicks = t;
        }
        weeklyDuoTicks[weekStart] = minTicks == 999 ? 0 : minTicks;
      }
    });

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final currentWeekStart =
        todayDate.subtract(Duration(days: todayDate.weekday - 1));

    int streak = 0;
    if ((weeklyDuoTicks[currentWeekStart] ?? 0) >= target) streak++;
    for (int i = 1; i < 520; i++) {
      final weekStart =
          currentWeekStart.subtract(Duration(days: i * 7));
      if ((weeklyDuoTicks[weekStart] ?? 0) >= target) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    final analyticsState = ref.watch(analyticsProvider(widget.groupId));
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          // ── Header ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () =>
                    context.canPop() ? context.pop() : context.go('/dashboard'),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: cs.surfaceVariant.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.onSurface.withOpacity(0.07)),
                  ),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 15, color: cs.onSurface),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text('Analytics',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8)),
              ),
            ]),
          ),

          // ── Month selector ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _MonthNavButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: _previousMonth,
                  cs: cs,
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    DateFormat('MMMM yyyy').format(_selectedMonth),
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: cs.primary),
                  ),
                ),
                const SizedBox(width: 12),
                _MonthNavButton(
                  icon: Icons.chevron_right_rounded,
                  onTap: _nextMonth,
                  cs: cs,
                ),
              ],
            ),
          ),

          // ── Tab bar ────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: cs.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500),
              indicator: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: cs.onSurface.withOpacity(0.5),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Weekly View'),
                Tab(text: 'Ritual Heatmap'),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Content ────────────────────────────────────────────────
          Expanded(
            child: analyticsState.when(
              skipLoadingOnReload: true,
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off_rounded,
                        size: 48, color: cs.onSurface.withOpacity(0.2)),
                    const SizedBox(height: 12),
                    Text('Could not load analytics',
                        style: TextStyle(
                            color: cs.onSurface.withOpacity(0.4))),
                  ],
                ),
              ),
              data: (data) => TabBarView(
                controller: _tabController,
                children: [
                  _buildGroupWeeklyView(data, cs, isDark),
                  _buildIndividualGoalView(data, cs, isDark),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildGroupWeeklyView(
      Map<String, dynamic> data, ColorScheme cs, bool isDark) {
    final goals = data['goals'] as List<dynamic>;
    final checkIns = data['checkIns'] as List<dynamic>;
    final members = data['members'] as List<dynamic>;

    final firstDayOfMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDayOfMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

    DateTime currentWeekStart = firstDayOfMonth
        .subtract(Duration(days: firstDayOfMonth.weekday - 1));

    final List<(DateTime, DateTime)> weekRanges = [];
    while (currentWeekStart.isBefore(lastDayOfMonth) ||
        currentWeekStart.isAtSameMomentAs(lastDayOfMonth)) {
      final weekEnd = currentWeekStart.add(const Duration(days: 6));
      weekRanges.add((currentWeekStart, weekEnd));
      currentWeekStart = currentWeekStart.add(const Duration(days: 7));
    }

    if (goals.isEmpty) {
      return Center(
        child: Text('No rituals yet.',
            style:
                TextStyle(color: cs.onSurface.withOpacity(0.4))),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      itemCount: weekRanges.length,
      itemBuilder: (context, index) {
        final start = weekRanges[index].$1;
        final end = weekRanges[index].$2;

        int totalTarget = 0;
        int totalAchieved = 0;
        final goalRows = <Widget>[];

        for (final goal in goals) {
          final target = (goal['weeklyMinimum'] as num?)?.toInt() ?? 0;
          final achieved =
              _calculateDuoTicks(goal['_id'], start, end, checkIns, members);

          totalTarget += target;
          totalAchieved += achieved;
          final met = achieved >= target;

          goalRows.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Text(goal['icon'] ?? '🎯',
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(goal['name'],
                      style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurface.withOpacity(0.7))),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: met
                        ? AppTheme.success.withOpacity(0.15)
                        : cs.onSurface.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$achieved/$target',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: met
                          ? AppTheme.success
                          : cs.onSurface.withOpacity(0.4),
                    ),
                  ),
                ),
              ]),
            ),
          );
        }

        final pct = totalTarget == 0
            ? 0
            : (totalAchieved / totalTarget * 100).clamp(0, 100).toInt();
        final isFullyMet = pct >= 100;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark
                ? cs.surfaceVariant.withOpacity(0.4)
                : cs.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isFullyMet
                  ? AppTheme.success.withOpacity(0.3)
                  : cs.onSurface.withOpacity(0.07),
            ),
            boxShadow: [
              BoxShadow(
                  color: cs.onSurface.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              iconColor: cs.onSurface.withOpacity(0.5),
              collapsedIconColor: cs.onSurface.withOpacity(0.35),
              shape: const RoundedRectangleBorder(),
              title: Row(children: [
                Text(
                  'Week ${index + 1}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(width: 8),
                if (isFullyMet)
                  const Text('✅', style: TextStyle(fontSize: 14)),
              ]),
              subtitle: Text(
                '${DateFormat('MMM d').format(start)} – ${DateFormat('MMM d').format(end)}',
                style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withOpacity(0.45)),
              ),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isFullyMet
                        ? AppTheme.success.withOpacity(0.12)
                        : cs.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$pct%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isFullyMet
                          ? AppTheme.success
                          : cs.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ]),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Divider(
                          color: cs.onSurface.withOpacity(0.06)),
                      const SizedBox(height: 8),
                      ...goalRows,
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
            .animate(delay: (index * 50).ms)
            .fadeIn(duration: 350.ms)
            .slideY(begin: 0.1, end: 0, curve: Curves.easeOut);
      },
    );
  }

  Widget _buildIndividualGoalView(
      Map<String, dynamic> data, ColorScheme cs, bool isDark) {
    final goals = data['goals'] as List<dynamic>;
    final checkIns = data['checkIns'] as List<dynamic>;
    final members = data['members'] as List<dynamic>;

    if (goals.isEmpty) {
      return Center(
          child: Text('No rituals yet.',
              style: TextStyle(color: cs.onSurface.withOpacity(0.4))));
    }

    if (_selectedGoalId == null && goals.isNotEmpty) {
      _selectedGoalId = goals.first['_id'];
    }

    final selectedGoal = goals.firstWhere(
        (g) => g['_id'] == _selectedGoalId,
        orElse: () => goals.first);

    // Build heatmap
    final lastDay =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final List<Widget> dayBoxes = [];
    const weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    for (var d in weekDays) {
      dayBoxes.add(Center(
          child: Text(d,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface.withOpacity(0.4)))));
    }

    final firstDayOfMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    for (int i = 0; i < firstDayOfMonth.weekday - 1; i++) {
      dayBoxes.add(const SizedBox.shrink());
    }

    int monthTotal = 0;
    final totalMembers = members.isNotEmpty ? members.length : 1;

    for (int day = 1; day <= lastDay; day++) {
      final d = DateTime(_selectedMonth.year, _selectedMonth.month, day);
      final uniqueCompleted =
          _calculateUniqueMembersCompleted(selectedGoal['_id'], d, checkIns);
      final achieved =
          _calculateDuoTicks(selectedGoal['_id'], d, d, checkIns, members);
      if (achieved > 0) monthTotal++;

      Color boxColor;
      if (uniqueCompleted == 0) {
        boxColor = isDark
            ? cs.surfaceVariant.withOpacity(0.3)
            : cs.surfaceVariant.withOpacity(0.5);
      } else if (uniqueCompleted >= totalMembers) {
        boxColor = cs.primary;
      } else {
        final intensity = uniqueCompleted / totalMembers;
        boxColor = cs.primary.withOpacity(0.3 + (0.7 * intensity));
      }

      dayBoxes.add(
        Container(
          decoration: BoxDecoration(
              color: boxColor,
              borderRadius: BorderRadius.circular(6)),
          child: Center(
            child: Text(
              '$day',
              style: TextStyle(
                color: uniqueCompleted > 0
                    ? Colors.white
                    : cs.onSurface.withOpacity(0.45),
                fontSize: 11,
                fontWeight: uniqueCompleted > 0
                    ? FontWeight.w700
                    : FontWeight.normal,
              ),
            ),
          ),
        ),
      );
    }

    final currentStreak =
        _computeGoalWeeklyStreak(selectedGoal, checkIns, members);

    return Column(children: [
      // Goal chips
      SizedBox(
        height: 44,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: goals.length,
          itemBuilder: (ctx, i) {
            final g = goals[i];
            final isSelected = g['_id'] == _selectedGoalId;
            return GestureDetector(
              onTap: () => setState(() => _selectedGoalId = g['_id']),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? cs.primary
                      : cs.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isSelected
                          ? cs.primary
                          : cs.onSurface.withOpacity(0.08)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(g['icon'] ?? '🎯',
                      style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    g['name'],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : cs.onSurface.withOpacity(0.7),
                    ),
                  ),
                ]),
              ),
            );
          },
        ),
      ),

      const SizedBox(height: 8),

      // Content
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            // Streak hero card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary, cs.primary.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(children: [
                // Streak
                Expanded(
                  child: Column(children: [
                    const Text('Weekly Streak',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      const Text('🔥',
                          style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 6),
                      Text(
                        '$currentStreak',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 2),
                    Text(plural(currentStreak, 'week'),
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12)),
                  ]),
                ),

                Container(
                    width: 1,
                    height: 60,
                    color: Colors.white.withOpacity(0.2)),

                // Month stats
                Expanded(
                  child: Column(children: [
                    Column(children: [
                      Text(
                        '$monthTotal',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            height: 1),
                      ),
                      Text(
                        '${plural(monthTotal, 'day')} in ${DateFormat('MMM').format(_selectedMonth)}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      const Icon(Icons.repeat_rounded,
                          color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${selectedGoal['weeklyMinimum'] ?? 0}× / week',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ]),
                  ]),
                ),
              ]),
            )
                .animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: -0.08, end: 0, curve: Curves.easeOut),

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Monthly Heatmap',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface),
                ),
                // Legend
                Row(children: [
                  _HeatmapLegend(
                      color: cs.surfaceVariant.withOpacity(0.5),
                      label: 'None'),
                  const SizedBox(width: 8),
                  _HeatmapLegend(
                      color: cs.primary.withOpacity(0.4),
                      label: 'Partial'),
                  const SizedBox(width: 8),
                  _HeatmapLegend(color: cs.primary, label: 'Full'),
                ]),
              ],
            ),
            const SizedBox(height: 12),
            // Capped width: on a wide desktop browser window (this app has no
            // page-level max-width) an uncapped GridView.count stretches each
            // day cell to fill the available space, turning a calendar-style
            // heatmap into an oversized grid spanning several screens.
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  children: dayBoxes,
                ),
              ),
            ),
          ],
        ),
      ),
    ]);
  }
}

class _MonthNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _MonthNavButton(
      {required this.icon, required this.onTap, required this.cs});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: cs.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.onSurface.withOpacity(0.07)),
        ),
        child: Icon(icon, size: 20, color: cs.onSurface.withOpacity(0.6)),
      ),
    );
  }
}

class _HeatmapLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _HeatmapLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45))),
    ]);
  }
}
