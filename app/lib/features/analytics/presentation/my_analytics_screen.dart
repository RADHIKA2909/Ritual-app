import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../domain/my_analytics_provider.dart';

class MyAnalyticsScreen extends ConsumerStatefulWidget {
  const MyAnalyticsScreen({super.key});

  @override
  ConsumerState<MyAnalyticsScreen> createState() => _MyAnalyticsScreenState();
}

class _MyAnalyticsScreenState extends ConsumerState<MyAnalyticsScreen> {
  DateTime _selectedMonth = DateTime.now();

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
  }

  int _calculatePersonalTicks(DateTime day, List<dynamic> checkIns) {
    int count = 0;
    for (final c in checkIns) {
      if (c['completed'] != true) continue;
      final d = DateTime.parse(c['date']).toLocal();
      if (d.year == day.year && d.month == day.month && d.day == day.day) {
        count++; // Count every habit completed this day
      }
    }
    return count;
  }

  int _calculateWeeklyStreak(List<dynamic> checkIns, List<dynamic> goals) {
    if (goals.isEmpty) return 0;
    
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final currentWeekStart = todayDate.subtract(Duration(days: todayDate.weekday - 1));

    final Map<String, Map<DateTime, int>> goalWeeklyTicks = {};
    for (var g in goals) {
      goalWeeklyTicks[g['_id']] = {};
    }

    for (var c in checkIns) {
      if (c['completed'] != true) continue;
      final goalId = c['goalId'];
      if (!goalWeeklyTicks.containsKey(goalId)) continue;
      
      final d = DateTime.parse(c['date']).toLocal();
      final weekStart = DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));
      
      goalWeeklyTicks[goalId]!.update(weekStart, (v) => v + 1, ifAbsent: () => 1);
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
      final weekStart = currentWeekStart.subtract(Duration(days: i * 7));
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

  Color _getHeatmapColor(int achieved, int totalGoals) {
    if (achieved == 0) return Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5);
    if (totalGoals == 0) return const Color(0xFF6C63FF).withOpacity(0.3);
    if (achieved >= totalGoals) return const Color(0xFF6C63FF);
    final double intensity = achieved / totalGoals;
    return const Color(0xFF6C63FF).withOpacity(0.3 + (0.7 * intensity));
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final analyticsState = ref.watch(myAnalyticsProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('My Analysis', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Month Selector
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, color: Theme.of(context).colorScheme.onSurface),
                  onPressed: _previousMonth,
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_selectedMonth),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface),
                  onPressed: _nextMonth,
                ),
              ],
            ),
          ),
          
          Expanded(
            child: analyticsState.when(
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))),
              error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
              data: (data) {
                final checkIns = data['checkIns'] as List<dynamic>;
                final groups = data['groups'] as List<dynamic>;
                final goals = data['goals'] as List<dynamic>;

                final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
                final List<Widget> dayBoxes = [];

                final weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                for (var day in weekDays) {
                  dayBoxes.add(
                    Center(child: Text(day, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), fontWeight: FontWeight.bold))),
                  );
                }

                final firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
                final emptyBoxesCount = firstDayOfMonth.weekday - 1;

                for (int i = 0; i < emptyBoxesCount; i++) {
                  dayBoxes.add(const SizedBox.shrink());
                }

                int totalExpected = 0;
                for (var goal in goals) {
                  totalExpected += ((goal['weeklyMinimum'] ?? 0) * 4) as int;
                }

                int activeDays = 0;
                int totalCompletions = 0;

                for (int day = 1; day <= lastDay; day++) {
                  final d = DateTime(_selectedMonth.year, _selectedMonth.month, day);
                  final achieved = _calculatePersonalTicks(d, checkIns);
                  
                  if (achieved > 0) activeDays++;
                  totalCompletions += achieved;

                  dayBoxes.add(
                    Container(
                      decoration: BoxDecoration(
                        color: _getHeatmapColor(achieved, goals.length),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Theme.of(context).colorScheme.surfaceVariant),
                      ),
                      child: Center(
                        child: Text('$day', style: TextStyle(
                          color: achieved > 0 ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.54),
                          fontSize: 12,
                          fontWeight: achieved > 0 ? FontWeight.bold : FontWeight.normal,
                        )),
                      ),
                    )
                  );
                }

                int currentStreak = _calculateWeeklyStreak(checkIns, goals);

                // Build Habit Breakdown
                Map<String, List<dynamic>> goalsByGroup = {};
                for (var goal in goals) {
                  final groupId = goal['groupId'];
                  if (!goalsByGroup.containsKey(groupId)) {
                    goalsByGroup[groupId] = [];
                  }
                  goalsByGroup[groupId]!.add(goal);
                }

                List<Widget> breakdownWidgets = [];
                for (var group in groups) {
                  final groupGoals = goalsByGroup[group['_id']] ?? [];
                  if (groupGoals.isEmpty) continue;

                  breakdownWidgets.add(
                    Padding(
                      padding: const EdgeInsets.only(top: 24, bottom: 12),
                      child: Text(group['name'], style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 14, fontWeight: FontWeight.w600)),
                    )
                  );

                  for (var goal in groupGoals) {
                    // Count completions for this goal in the selected month
                    int monthCompletions = 0;
                    for (var c in checkIns) {
                      if (c['goalId'] == goal['_id'] && c['completed'] == true) {
                        final cd = DateTime.parse(c['date']).toLocal();
                        if (cd.year == _selectedMonth.year && cd.month == _selectedMonth.month) {
                          monthCompletions++;
                        }
                      }
                    }

                    int expectedWeekly = goal['weeklyMinimum'] ?? 0;
                    int expectedMonthly = expectedWeekly * 4; // Approx 4 weeks
                    double progress = expectedMonthly > 0 ? (monthCompletions / expectedMonthly).clamp(0.0, 1.0) : 0.0;

                    breakdownWidgets.add(
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Text(goal['icon'] ?? '🎯', style: const TextStyle(fontSize: 24)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(goal['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: progress,
                                    backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                                    color: progress >= 1.0 ? Colors.greenAccent : const Color(0xFF6C63FF),
                                    minHeight: 6,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text('$monthCompletions', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    );
                  }
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSummaryCard('Rituals done/min needed', '$totalCompletions/$totalExpected', Icons.check_circle_outline, Colors.greenAccent),
                          const SizedBox(width: 12),
                          _buildSummaryCard('Completed ≥1 ritual', '$activeDays', Icons.calendar_today_rounded, Colors.blueAccent),
                          const SizedBox(width: 12),
                          _buildSummaryCard('Weekly Streak', '$currentStreak 🔥', Icons.local_fire_department_rounded, Colors.orangeAccent),
                        ]
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text('Consistency Heatmap', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 7,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      children: dayBoxes,
                    ),
                    if (breakdownWidgets.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      const Text('Monthly Rituals Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ...breakdownWidgets,
                    ]
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
