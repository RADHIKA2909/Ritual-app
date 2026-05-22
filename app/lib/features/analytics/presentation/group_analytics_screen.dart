import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../domain/analytics_provider.dart';
import '../../../core/network/socket_service.dart';

class GroupAnalyticsScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GroupAnalyticsScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupAnalyticsScreen> createState() => _GroupAnalyticsScreenState();
}

class _GroupAnalyticsScreenState extends ConsumerState<GroupAnalyticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedMonth = DateTime.now();
  String? _selectedGoalId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Listen for real-time updates
    SocketService().on('checkin_updated', _onDataUpdated);
    SocketService().on('goal_updated', _onDataUpdated);
  }

  void _onDataUpdated(dynamic data) {
    if (mounted) {
      ref.invalidate(analyticsProvider(widget.groupId));
    }
  }

  @override
  void dispose() {
    SocketService().off('checkin_updated', _onDataUpdated);
    SocketService().off('goal_updated', _onDataUpdated);
    _tabController.dispose();
    super.dispose();
  }

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

  /// Calculates how many "Duo Ticks" (days where all members checked in) happened for a specific goal in a date range
  int _calculateDuoTicks(String goalId, DateTime start, DateTime end, List<dynamic> checkIns, int memberCount) {
    final Map<String, Set<String>> dayUserMap = {};
    for (final c in checkIns) {
      if (c['goalId'] != goalId || c['completed'] != true) continue;

      final d = DateTime.parse(c['date']).toLocal();
      final dayOnly = DateTime(d.year, d.month, d.day);
      
      if (dayOnly.isBefore(start) || dayOnly.isAfter(end)) continue;

      final key = '${d.year}-${d.month}-${d.day}';
      dayUserMap.putIfAbsent(key, () => <String>{});
      dayUserMap[key]!.add(c['userId'].toString());
    }

    int duoTicks = 0;
    dayUserMap.forEach((key, users) {
      if (users.length >= memberCount) {
        duoTicks++;
      }
    });

    return duoTicks;
  }

  int _computeGoalWeeklyStreak(Map<String, dynamic> goal, List<dynamic> checkIns, int memberCount) {
    final goalId = goal['_id'];
    final target = goal['weeklyMinimum'] ?? 0;
    final goalCheckIns = checkIns.where((c) => c['goalId'] == goalId && c['completed'] == true).toList();
    if (goalCheckIns.isEmpty) return 0;

    final Map<String, Set<String>> dayUserMap = {};
    for (final c in goalCheckIns) {
      final d = DateTime.parse(c['date']).toLocal();
      final key = '${d.year}-${d.month}-${d.day}';
      dayUserMap.putIfAbsent(key, () => <String>{});
      dayUserMap[key]!.add(c['userId'].toString());
    }

    final Map<DateTime, int> weeklyDuoTicks = {};
    dayUserMap.forEach((dateString, users) {
      if (users.length >= memberCount) {
        final parts = dateString.split('-');
        final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        final weekStart = d.subtract(Duration(days: d.weekday - 1));
        weeklyDuoTicks.update(weekStart, (v) => v + 1, ifAbsent: () => 1);
      }
    });

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final currentWeekStart = todayDate.subtract(Duration(days: todayDate.weekday - 1));
    
    int streak = 0;
    
    if ((weeklyDuoTicks[currentWeekStart] ?? 0) >= target) streak++;

    for (int i = 1; i < 520; i++) {
      final weekStart = currentWeekStart.subtract(Duration(days: i * 7));
      if ((weeklyDuoTicks[weekStart] ?? 0) >= target) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  Widget _buildGroupWeeklyView(Map<String, dynamic> data) {
    final goals = data['goals'] as List<dynamic>;
    final checkIns = data['checkIns'] as List<dynamic>;
    final members = data['members'] as List<dynamic>;
    final memberCount = members.isNotEmpty ? members.length : 1;

    final firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

    DateTime currentWeekStart = firstDayOfMonth.subtract(Duration(days: firstDayOfMonth.weekday - 1));
    
    final List<(DateTime, DateTime)> weekRanges = [];
    while (currentWeekStart.isBefore(lastDayOfMonth) || currentWeekStart.isAtSameMomentAs(lastDayOfMonth)) {
      final weekEnd = currentWeekStart.add(const Duration(days: 6));
      weekRanges.add((currentWeekStart, weekEnd));
      currentWeekStart = currentWeekStart.add(const Duration(days: 7));
    }

    if (goals.isEmpty) {
      return Center(child: Text('No goals in this group yet.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: weekRanges.length,
      itemBuilder: (context, index) {
        final start = weekRanges[index].$1;
        final end = weekRanges[index].$2;
        
        int totalTarget = 0;
        int totalAchieved = 0;

        final List<Widget> goalBreakdowns = [];

        for (final goal in goals) {
          final target = goal['weeklyMinimum'] ?? 0;
          final achieved = _calculateDuoTicks(goal['_id'], start, end, checkIns, memberCount);
          
          totalTarget += target as int;
          totalAchieved += achieved;

          goalBreakdowns.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(goal['icon'] ?? '🎯', style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(goal['name'], style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16)),
                    ],
                  ),
                  Text('$achieved / $target', style: TextStyle(
                    color: achieved >= target ? Colors.greenAccent : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    fontWeight: FontWeight.bold,
                  )),
                ],
              ),
            ),
          );
        }

        final percentage = totalTarget == 0 ? 0 : (totalAchieved / totalTarget * 100).clamp(0, 100).toInt();

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
            iconColor: Theme.of(context).colorScheme.onSurface,
            collapsedIconColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            title: Text('Week ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${DateFormat('MMM d').format(start)} - ${DateFormat('MMM d').format(end)}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54))),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$percentage%', style: TextStyle(
                  color: percentage >= 100 ? Colors.greenAccent : Colors.orangeAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16
                )),
                Text('Completion', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), fontSize: 10)),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(children: goalBreakdowns),
              )
            ],
          ),
          ),
        );
      },
    );
  }

  Widget _buildIndividualGoalView(Map<String, dynamic> data) {
    final goals = data['goals'] as List<dynamic>;
    final checkIns = data['checkIns'] as List<dynamic>;
    final members = data['members'] as List<dynamic>;
    final memberCount = members.isNotEmpty ? members.length : 1;

    if (goals.isEmpty) {
      return Center(child: Text('No goals in this group yet.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))));
    }

    if (_selectedGoalId == null && goals.isNotEmpty) {
      _selectedGoalId = goals.first['_id'];
    }

    final selectedGoal = goals.firstWhere((g) => g['_id'] == _selectedGoalId, orElse: () => goals.first);

    // Build Heatmap for the month
    final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final List<Widget> dayBoxes = [];

    // Add days of the week headers
    final weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    for (var day in weekDays) {
      dayBoxes.add(
        Center(child: Text(day, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), fontWeight: FontWeight.bold))),
      );
    }

    // Add empty boxes to align the 1st day of the month correctly
    final firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final emptyBoxesCount = firstDayOfMonth.weekday - 1;

    for (int i = 0; i < emptyBoxesCount; i++) {
      dayBoxes.add(const SizedBox.shrink());
    }

    int monthTotal = 0;

    for (int day = 1; day <= lastDay; day++) {
      final d = DateTime(_selectedMonth.year, _selectedMonth.month, day);
      final achieved = _calculateDuoTicks(selectedGoal['_id'], d, d, checkIns, memberCount);
      
      if (achieved > 0) monthTotal++;

      dayBoxes.add(
        Container(
          decoration: BoxDecoration(
            color: achieved > 0 ? const Color(0xFF6C63FF) : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
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

    final currentStreak = _computeGoalWeeklyStreak(selectedGoal, checkIns, memberCount);

    return Column(
      children: [
        // Goal Selector
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: goals.map((g) {
              final isSelected = g['_id'] == _selectedGoalId;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text('${g['icon'] ?? '🎯'} ${g['name']}'),
                  selected: isSelected,
                  selectedColor: const Color(0xFF6C63FF),
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.7),
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedGoalId = g['_id']);
                  },
                ),
              );
            }).toList(),
          ),
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Monthly Summary Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF4A47A3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Text('Current Weekly Streak', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 36),
                        const SizedBox(width: 8),
                        Text('$currentStreak', style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(color: Colors.white.withOpacity(0.2)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text('$monthTotal', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                            Text('Completed Days in ${DateFormat('MMM yyyy').format(_selectedMonth)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                        Column(
                          children: [
                            Text('${selectedGoal['weeklyMinimum'] ?? 0}×', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                            const Text('Weekly Target', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('Monthly Heatmap', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: dayBoxes,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final analyticsState = ref.watch(analyticsProvider(widget.groupId));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF6C63FF),
          tabs: const [
            Tab(text: 'Weekly Group View'),
            Tab(text: 'Individual Goals'),
          ],
        ),
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
              data: (data) {
                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildGroupWeeklyView(data),
                    _buildIndividualGoalView(data),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))),
              error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
            ),
          ),
        ],
      ),
    );
  }
}
