import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';

class GoalHistoryScreen extends ConsumerStatefulWidget {
  final String goalId;
  final String goalName;
  final String goalIcon;
  final List<dynamic> groupMembers;

  const GoalHistoryScreen({
    super.key,
    required this.goalId,
    required this.goalName,
    required this.goalIcon,
    required this.groupMembers,
  });

  @override
  ConsumerState<GoalHistoryScreen> createState() => _GoalHistoryScreenState();
}

class _GoalHistoryScreenState extends ConsumerState<GoalHistoryScreen> {
  List<dynamic> _checkIns = [];
  String? _currentUserId;
  bool _isLoading = true;

  // How many weeks to show
  static const int _totalWeeks = 16;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    try {
      final response =
          await ApiClient.instance.get('/goals/${widget.goalId}/checkins');
      if (mounted) {
        setState(() {
          _checkIns = response.data as List<dynamic>;
          _currentUserId = userId;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Returns true if the given userId checked in on the given date
  bool _checkedIn(String userId, DateTime date) {
    return _checkIns.any((c) {
      if (c['userId'].toString() != userId) return false;
      if (c['completed'] != true) return false;
      final d = DateTime.parse(c['date']).toLocal();
      return d.year == date.year &&
          d.month == date.month &&
          d.day == date.day;
    });
  }

  // Build dates: _totalWeeks × 7 days, starting from Monday of the oldest week
  List<DateTime> _buildDates() {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    // Monday of current week
    final currentMonday =
        todayDate.subtract(Duration(days: todayDate.weekday - 1));
    // Monday of oldest week
    final startMonday =
        currentMonday.subtract(Duration(days: (_totalWeeks - 1) * 7));
    return List.generate(
        _totalWeeks * 7, (i) => startMonday.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.canPop() ? context.pop() : context.go('/home'),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.surfaceVariant.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded,
                size: 16, color: cs.onSurface),
          ),
        ),
        title: Row(children: [
          Text(widget.goalIcon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(widget.goalName,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, letterSpacing: -0.3)),
        ]),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(cs),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    final dates = _buildDates();
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Which members to show
    final members = widget.groupMembers.isNotEmpty
        ? widget.groupMembers
        : (_currentUserId != null
            ? [
                {'_id': _currentUserId, 'name': 'You'}
              ]
            : []);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        // ── Stats summary ─────────────────────────────────────────────
        _buildStats(cs, dates, todayDate),
        const SizedBox(height: 24),

        // ── Heatmap per member ────────────────────────────────────────
        ...members.map((member) {
          final memberId = member['_id'].toString();
          final name = (member['name'] as String).split(' ').first;
          final isMe = memberId == _currentUserId;

          return Padding(
            padding: const EdgeInsets.only(bottom: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? 'YOU' : name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: cs.onSurface.withOpacity(0.45),
                  ),
                ),
                const SizedBox(height: 10),
                _buildHeatmap(cs, dates, todayDate, memberId),
              ],
            ),
          );
        }),

        // ── Month labels ──────────────────────────────────────────────
        _buildMonthLabels(cs, dates),
      ],
    );
  }

  Widget _buildStats(ColorScheme cs, List<DateTime> dates, DateTime todayDate) {
    if (_currentUserId == null) return const SizedBox.shrink();

    final pastDates =
        dates.where((d) => !d.isAfter(todayDate)).toList();
    final totalDays = pastDates.length;
    final checkedDays =
        pastDates.where((d) => _checkedIn(_currentUserId!, d)).length;
    final rate =
        totalDays > 0 ? (checkedDays / totalDays * 100).round() : 0;

    // Current streak
    int streak = 0;
    for (int i = pastDates.length - 1; i >= 0; i--) {
      if (_checkedIn(_currentUserId!, pastDates[i])) {
        streak++;
      } else {
        break;
      }
    }

    return Row(children: [
      _StatChip(
        label: 'This Period',
        value: '$checkedDays days',
        icon: '📅',
        cs: cs,
      ),
      const SizedBox(width: 10),
      _StatChip(
        label: 'Consistency',
        value: '$rate%',
        icon: '📊',
        cs: cs,
      ),
      const SizedBox(width: 10),
      _StatChip(
        label: 'Streak',
        value: '$streak days',
        icon: '🔥',
        cs: cs,
      ),
    ]);
  }

  Widget _buildHeatmap(
    ColorScheme cs,
    List<DateTime> dates,
    DateTime todayDate,
    String userId,
  ) {
    // dates is a flat list of _totalWeeks*7 days, Mon→Sun per week
    // Render as 7 rows × _totalWeeks columns
    const cellSize = 16.0;
    const cellGap = 3.0;

    return Column(
      children: List.generate(7, (row) {
        // row 0 = Monday, row 6 = Sunday
        return Padding(
          padding: const EdgeInsets.only(bottom: cellGap),
          child: Row(
            children: List.generate(_totalWeeks, (col) {
              final date = dates[col * 7 + row];
              final isFuture = date.isAfter(todayDate);
              final isToday = date.isAtSameMomentAs(todayDate);
              final checked = !isFuture && _checkedIn(userId, date);

              Color color;
              if (isFuture) {
                color = cs.onSurface.withOpacity(0.05);
              } else if (checked) {
                color = cs.primary.withOpacity(isToday ? 1.0 : 0.75);
              } else {
                color = cs.onSurface.withOpacity(0.08);
              }

              return Container(
                width: cellSize,
                height: cellSize,
                margin: const EdgeInsets.only(right: cellGap),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                  border: isToday
                      ? Border.all(color: cs.primary, width: 1.5)
                      : null,
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  Widget _buildMonthLabels(ColorScheme cs, List<DateTime> dates) {
    // Show month name at the start of each month (first Monday of that month in our range)
    final labels = <Widget>[];
    const cellSize = 16.0;
    const cellGap = 3.0;

    String? lastMonth;
    for (int col = 0; col < _totalWeeks; col++) {
      final date = dates[col * 7]; // Monday of this week
      final monthKey = '${date.year}-${date.month}';
      final monthName = _monthAbbr(date.month);

      if (monthKey != lastMonth) {
        lastMonth = monthKey;
        labels.add(SizedBox(
          width: cellSize + cellGap,
          child: Text(
            monthName,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withOpacity(0.4),
            ),
          ),
        ));
      } else {
        labels.add(SizedBox(width: cellSize + cellGap));
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: labels),
    );
  }

  String _monthAbbr(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final String icon;
  final ColorScheme cs;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.onSurface.withOpacity(0.07)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: cs.onSurface.withOpacity(0.45),
                  fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}
