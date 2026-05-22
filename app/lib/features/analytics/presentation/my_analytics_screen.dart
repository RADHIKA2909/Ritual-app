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
        count++; // Found a tick on this day
        break; // Only need to know if they ticked at least one goal
      }
    }
    return count;
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

                int monthTotal = 0;

                for (int day = 1; day <= lastDay; day++) {
                  final d = DateTime(_selectedMonth.year, _selectedMonth.month, day);
                  final achieved = _calculatePersonalTicks(d, checkIns);
                  
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

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
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
                          const Text('Personal Consistency', style: TextStyle(color: Colors.white70, fontSize: 14)),
                          const SizedBox(height: 8),
                          Text('$monthTotal', style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Active Days in ${DateFormat('MMMM yyyy').format(_selectedMonth)}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
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
