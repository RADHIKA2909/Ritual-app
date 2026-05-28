import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../domain/my_analytics_provider.dart';

class MyAnalyticsScreen extends ConsumerStatefulWidget {
  const MyAnalyticsScreen({super.key});

  @override
  ConsumerState<MyAnalyticsScreen> createState() => _MyAnalyticsScreenState();
}

class _MyAnalyticsScreenState extends ConsumerState<MyAnalyticsScreen> {
  DateTime _selectedMonth = DateTime.now();

  void _previousMonth() => setState(() =>
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1));

  void _nextMonth() => setState(() =>
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1));

  int _calculatePersonalTicks(DateTime day, List<dynamic> checkIns) {
    int count = 0;
    for (final c in checkIns) {
      if (c['completed'] != true) continue;
      final d = DateTime.parse(c['date']).toLocal();
      if (d.year == day.year && d.month == day.month && d.day == day.day) {
        count++;
      }
    }
    return count;
  }

  int _calculateWeeklyStreak(List<dynamic> checkIns, List<dynamic> goals) {
    if (goals.isEmpty) return 0;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final currentWeekStart =
        todayDate.subtract(Duration(days: todayDate.weekday - 1));

    final Map<String, Map<DateTime, int>> goalWeeklyTicks = {};
    for (var g in goals) {
      goalWeeklyTicks[g['_id']] = {};
    }

    for (var c in checkIns) {
      if (c['completed'] != true) continue;
      final goalId = c['goalId'];
      if (!goalWeeklyTicks.containsKey(goalId)) continue;
      final d = DateTime.parse(c['date']).toLocal();
      final weekStart = DateTime(d.year, d.month, d.day)
          .subtract(Duration(days: d.weekday - 1));
      goalWeeklyTicks[goalId]!
          .update(weekStart, (v) => v + 1, ifAbsent: () => 1);
    }

    int streak = 0;

    bool currentWeekMet = true;
    for (var g in goals) {
      final target = g['weeklyMinimum'] ?? 0;
      final ticks = goalWeeklyTicks[g['_id']]?[currentWeekStart] ?? 0;
      if (ticks < target) {
        currentWeekMet = false;
        break;
      }
    }
    if (currentWeekMet) streak++;

    for (int i = 1; i < 520; i++) {
      final weekStart =
          currentWeekStart.subtract(Duration(days: i * 7));
      bool weekMet = true;
      for (var g in goals) {
        final target = g['weeklyMinimum'] ?? 0;
        final ticks = goalWeeklyTicks[g['_id']]?[weekStart] ?? 0;
        if (ticks < target) {
          weekMet = false;
          break;
        }
      }
      if (weekMet) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    final analyticsState = ref.watch(myAnalyticsProvider);
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
                    context.canPop() ? context.pop() : context.go('/home'),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: cs.surfaceVariant.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: cs.onSurface.withOpacity(0.07)),
                  ),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 15, color: cs.onSurface),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text('My Analytics',
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
                    cs: cs),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
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
                    cs: cs),
              ],
            ),
          ),

          // ── Content ─────────────────────────────────────────────────
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
                        size: 48,
                        color: cs.onSurface.withOpacity(0.2)),
                    const SizedBox(height: 12),
                    Text('Could not load analytics',
                        style: TextStyle(
                            color: cs.onSurface.withOpacity(0.4))),
                  ],
                ),
              ),
              data: (data) {
                final checkIns = data['checkIns'] as List<dynamic>;
                final groups = data['groups'] as List<dynamic>;
                final goals = data['goals'] as List<dynamic>;

                final lastDay = DateTime(
                        _selectedMonth.year, _selectedMonth.month + 1, 0)
                    .day;

                // Compute heatmap
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

                final firstDay = DateTime(
                    _selectedMonth.year, _selectedMonth.month, 1);
                for (int i = 0; i < firstDay.weekday - 1; i++) {
                  dayBoxes.add(const SizedBox.shrink());
                }

                int activeDays = 0;
                int totalCompletions = 0;
                int totalExpected = 0;
                for (var g in goals) {
                  totalExpected +=
                      ((g['weeklyMinimum'] ?? 0) * 4) as int;
                }

                for (int day = 1; day <= lastDay; day++) {
                  final d = DateTime(
                      _selectedMonth.year, _selectedMonth.month, day);
                  final achieved = _calculatePersonalTicks(d, checkIns);
                  if (achieved > 0) activeDays++;
                  totalCompletions += achieved;

                  Color boxColor;
                  if (achieved == 0) {
                    boxColor = isDark
                        ? cs.surfaceVariant.withOpacity(0.3)
                        : cs.surfaceVariant.withOpacity(0.5);
                  } else if (goals.isNotEmpty &&
                      achieved >= goals.length) {
                    boxColor = cs.primary;
                  } else {
                    final intensity = goals.isNotEmpty
                        ? (achieved / goals.length).clamp(0.0, 1.0)
                        : 0.5;
                    boxColor =
                        cs.primary.withOpacity(0.3 + 0.7 * intensity);
                  }

                  dayBoxes.add(Container(
                    decoration: BoxDecoration(
                        color: boxColor,
                        borderRadius: BorderRadius.circular(6)),
                    child: Center(
                      child: Text(
                        '$day',
                        style: TextStyle(
                          color: achieved > 0
                              ? Colors.white
                              : cs.onSurface.withOpacity(0.45),
                          fontSize: 11,
                          fontWeight: achieved > 0
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ));
                }

                final streak =
                    _calculateWeeklyStreak(checkIns, goals);

                // Goal breakdown
                final Map<String, List<dynamic>> goalsByGroup = {};
                for (var g in goals) {
                  final gid = g['groupId'];
                  goalsByGroup.putIfAbsent(gid, () => []);
                  goalsByGroup[gid]!.add(g);
                }

                return ListView(
                  padding:
                      const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  children: [
                    // ── Summary cards ──────────────────────────────
                    Row(children: [
                      _StatCard(
                        icon: '✅',
                        value: totalCompletions.toString(),
                        label: 'Completions',
                        subLabel: 'of $totalExpected needed',
                        color: const Color(0xFF48BB78),
                        cs: cs,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 10),
                      _StatCard(
                        icon: '📅',
                        value: activeDays.toString(),
                        label: 'Active Days',
                        subLabel: 'checked in ≥1',
                        color: const Color(0xFF4299E1),
                        cs: cs,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 10),
                      _StatCard(
                        icon: '🔥',
                        value: streak.toString(),
                        label: 'Wk Streak',
                        subLabel: 'consecutive weeks',
                        color: const Color(0xFFED8936),
                        cs: cs,
                        isDark: isDark,
                      ),
                    ])
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: -0.05, end: 0),

                    const SizedBox(height: 24),

                    // ── Heatmap ────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Consistency Heatmap',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface),
                        ),
                        Row(children: [
                          _HeatmapLegend(
                              color: cs.surfaceVariant.withOpacity(0.5),
                              label: 'None'),
                          const SizedBox(width: 8),
                          _HeatmapLegend(
                              color: cs.primary, label: 'Full'),
                        ]),
                      ],
                    )
                        .animate(delay: 100.ms)
                        .fadeIn(duration: 400.ms),

                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 7,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      children: dayBoxes,
                    )
                        .animate(delay: 150.ms)
                        .fadeIn(duration: 400.ms),

                    // ── Per-goal breakdown ─────────────────────────
                    if (goalsByGroup.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      Text(
                        'Monthly Breakdown',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface),
                      )
                          .animate(delay: 200.ms)
                          .fadeIn(duration: 400.ms),
                      const SizedBox(height: 12),
                      ...groups
                          .asMap()
                          .entries
                          .where((e) =>
                              goalsByGroup[e.value['_id']] != null &&
                              goalsByGroup[e.value['_id']]!.isNotEmpty)
                          .map((e) {
                        final group = e.value;
                        final groupGoals =
                            goalsByGroup[group['_id']] ?? [];

                        return Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                  top: 4, bottom: 8),
                              child: Text(
                                group['name'] ?? '',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4,
                                    color: cs.onSurface.withOpacity(
                                        0.4)),
                              ),
                            ),
                            ...groupGoals
                                .asMap()
                                .entries
                                .map((ge) {
                              final goal = ge.value;
                              int monthCount = 0;
                              for (var c in checkIns) {
                                if (c['goalId'] == goal['_id'] &&
                                    c['completed'] == true) {
                                  final cd =
                                      DateTime.parse(c['date'])
                                          .toLocal();
                                  if (cd.year ==
                                          _selectedMonth.year &&
                                      cd.month ==
                                          _selectedMonth.month) {
                                    monthCount++;
                                  }
                                }
                              }
                              final expected =
                                  (goal['weeklyMinimum'] ?? 0) * 4;
                              final progress = expected > 0
                                  ? (monthCount / expected)
                                      .clamp(0.0, 1.0)
                                  : 0.0;
                              final met = progress >= 1.0;

                              return Container(
                                margin: const EdgeInsets.only(
                                    bottom: 10),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? cs.surfaceVariant
                                          .withOpacity(0.4)
                                      : cs.surface,
                                  borderRadius:
                                      BorderRadius.circular(18),
                                  border: Border.all(
                                      color: met
                                          ? const Color(0xFF48BB78)
                                              .withOpacity(0.3)
                                          : cs.onSurface
                                              .withOpacity(0.07)),
                                  boxShadow: [
                                    BoxShadow(
                                        color: cs.onSurface
                                            .withOpacity(0.03),
                                        blurRadius: 8,
                                        offset:
                                            const Offset(0, 2)),
                                  ],
                                ),
                                child: Row(children: [
                                  Text(goal['icon'] ?? '🎯',
                                      style: const TextStyle(
                                          fontSize: 22)),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(goal['name'],
                                          style: const TextStyle(
                                              fontWeight:
                                                  FontWeight.w700,
                                              fontSize: 14)),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(4),
                                        child: TweenAnimationBuilder<
                                            double>(
                                          tween: Tween(
                                              begin: 0,
                                              end: progress),
                                          duration: const Duration(
                                              milliseconds: 800),
                                          curve: Curves.easeOutCubic,
                                          builder: (_, v, __) =>
                                              LinearProgressIndicator(
                                            value: v,
                                            minHeight: 5,
                                            backgroundColor: cs
                                                .onSurface
                                                .withOpacity(0.08),
                                            color: met
                                                ? const Color(
                                                    0xFF48BB78)
                                                : cs.primary,
                                          ),
                                        ),
                                      ),
                                    ]),
                                  ),
                                  const SizedBox(width: 14),
                                  Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                    Text(
                                      '$monthCount',
                                      style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color: met
                                              ? const Color(0xFF48BB78)
                                              : cs.onSurface),
                                    ),
                                    Text(
                                      '/$expected',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: cs.onSurface
                                              .withOpacity(0.4)),
                                    ),
                                  ]),
                                ]),
                              )
                                  .animate(
                                      delay: (ge.key * 60 + 300).ms)
                                  .fadeIn(duration: 350.ms)
                                  .slideX(
                                      begin: 0.06,
                                      end: 0,
                                      curve: Curves.easeOut);
                            }),
                          ],
                        );
                      }),
                    ],
                  ],
                );
              },
            ),
          ),
        ]),
      ),
    );
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
        child:
            Icon(icon, size: 20, color: cs.onSurface.withOpacity(0.6)),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String icon;
  final String value;
  final String label;
  final String subLabel;
  final Color color;
  final ColorScheme cs;
  final bool isDark;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.subLabel,
    required this.color,
    required this.cs,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        decoration: BoxDecoration(
          color: isDark ? color.withOpacity(0.1) : color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: color,
                    height: 1)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface.withOpacity(0.5))),
            Text(subLabel,
                style: TextStyle(
                    fontSize: 9,
                    color: cs.onSurface.withOpacity(0.35))),
          ],
        ),
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
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withOpacity(0.45))),
    ]);
  }
}
