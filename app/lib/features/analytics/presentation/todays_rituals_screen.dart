import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/my_analytics_provider.dart';

class TodaysRitualsScreen extends ConsumerWidget {
  const TodaysRitualsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsState = ref.watch(myAnalyticsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's Rituals",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _todayLabel(),
                    style: TextStyle(
                      fontSize: 14,
                      color: cs.onSurface.withOpacity(0.45),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Body ────────────────────────────────────────────────────
            Expanded(
              child: analyticsState.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off_rounded,
                          size: 48,
                          color: cs.onSurface.withOpacity(0.2)),
                      const SizedBox(height: 12),
                      Text('Could not load rituals',
                          style: TextStyle(
                              color: cs.onSurface.withOpacity(0.4))),
                    ],
                  ),
                ),
                data: (data) {
                  final goals = data['goals'] as List<dynamic>;
                  final groups = data['groups'] as List<dynamic>;
                  final checkIns = data['checkIns'] as List<dynamic>;

                  if (goals.isEmpty) {
                    return _EmptyRitualsView();
                  }

                  final now = DateTime.now();
                  final pending = <dynamic>[];
                  final completed = <dynamic>[];

                  for (final goal in goals) {
                    final isCompletedToday = checkIns.any((c) {
                      if (c['goalId'] != goal['_id']) return false;
                      final d = DateTime.parse(c['date']).toLocal();
                      return d.year == now.year &&
                          d.month == now.month &&
                          d.day == now.day;
                    });
                    isCompletedToday ? completed.add(goal) : pending.add(goal);
                  }

                  final total = goals.length;
                  final doneCount = completed.length;
                  final allDone = doneCount == total && total > 0;

                  return ListView(
                    padding:
                        const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    children: [
                      // ── Progress hero card ─────────────────────────
                      _ProgressHeroCard(
                        doneCount: doneCount,
                        total: total,
                        allDone: allDone,
                        cs: cs,
                      )
                          .animate()
                          .fadeIn(duration: 400.ms)
                          .slideY(begin: -0.1, end: 0, curve: Curves.easeOut),

                      const SizedBox(height: 24),

                      // ── Pending ────────────────────────────────────
                      if (pending.isNotEmpty) ...[
                        _SectionLabel(
                          label: 'To Complete',
                          count: pending.length,
                          color: cs.primary,
                        ),
                        const SizedBox(height: 10),
                        ...pending.asMap().entries.map((e) {
                          final goal = e.value;
                          final group = groups.firstWhere(
                            (g) => g['_id'] == goal['groupId'],
                            orElse: () =>
                                {'name': 'Unknown Group', '_id': ''},
                          );
                          return _RitualCard(
                            goal: goal,
                            group: group,
                            isDone: false,
                            cs: cs,
                          )
                              .animate(delay: (e.key * 60).ms)
                              .fadeIn(duration: 350.ms)
                              .slideX(
                                  begin: 0.06,
                                  end: 0,
                                  curve: Curves.easeOutCubic);
                        }),
                        const SizedBox(height: 20),
                      ],

                      // ── Completed ──────────────────────────────────
                      if (completed.isNotEmpty) ...[
                        _SectionLabel(
                          label: 'Completed',
                          count: completed.length,
                          color: const Color(0xFF48BB78),
                        ),
                        const SizedBox(height: 10),
                        ...completed.asMap().entries.map((e) {
                          final goal = e.value;
                          final group = groups.firstWhere(
                            (g) => g['_id'] == goal['groupId'],
                            orElse: () =>
                                {'name': 'Unknown Group', '_id': ''},
                          );
                          return _RitualCard(
                            goal: goal,
                            group: group,
                            isDone: true,
                            cs: cs,
                          )
                              .animate(
                                  delay: ((pending.length + e.key) * 60).ms)
                              .fadeIn(duration: 350.ms)
                              .slideX(
                                  begin: 0.06,
                                  end: 0,
                                  curve: Curves.easeOutCubic);
                        }),
                      ],

                      // All done celebration
                      if (allDone)
                        _AllDoneBanner()
                            .animate(delay: 200.ms)
                            .fadeIn(duration: 500.ms)
                            .scale(
                              begin: const Offset(0.9, 0.9),
                              end: const Offset(1.0, 1.0),
                              curve: Curves.elasticOut,
                            ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _todayLabel() {
    final now = DateTime.now();
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }
}

// ── Progress Hero Card ─────────────────────────────────────────────────────
class _ProgressHeroCard extends StatelessWidget {
  final int doneCount;
  final int total;
  final bool allDone;
  final ColorScheme cs;

  const _ProgressHeroCard({
    required this.doneCount,
    required this.total,
    required this.allDone,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? doneCount / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: allDone
              ? [const Color(0xFF38A169), const Color(0xFF48BB78)]
              : [cs.primary, cs.primary.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (allDone ? const Color(0xFF48BB78) : cs.primary)
                .withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(children: [
        // Circular progress
        SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => CircularProgressIndicator(
                  value: value,
                  strokeWidth: 6,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              Text(
                '$doneCount/$total',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(
              allDone
                  ? '🎉 All done!'
                  : doneCount == 0
                      ? 'Let\'s get started!'
                      : 'Keep it up!',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              allDone
                  ? 'You crushed today\'s rituals.'
                  : '${total - doneCount} ritual${total - doneCount == 1 ? '' : 's'} remaining today',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Section Label ──────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SectionLabel({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: color.withOpacity(0.7),
        ),
      ),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '$count',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    ]);
  }
}

// ── Ritual Card ────────────────────────────────────────────────────────────
class _RitualCard extends StatefulWidget {
  final dynamic goal;
  final dynamic group;
  final bool isDone;
  final ColorScheme cs;

  const _RitualCard({
    required this.goal,
    required this.group,
    required this.isDone,
    required this.cs,
  });

  @override
  State<_RitualCard> createState() => _RitualCardState();
}

class _RitualCardState extends State<_RitualCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = widget.cs;
    final goalName = widget.goal['name'] as String;
    final icon = widget.goal['icon'] as String? ?? '🎯';
    final groupName = widget.group['name'] as String;
    final groupId = widget.group['_id'] as String;

    return GestureDetector(
      onTapDown: widget.isDone ? null : (_) => setState(() => _pressed = true),
      onTapUp: widget.isDone
          ? null
          : (_) {
              setState(() => _pressed = false);
              context.push('/group/$groupId');
            },
      onTapCancel:
          widget.isDone ? null : () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.isDone
                ? const Color(0xFF48BB78).withOpacity(0.07)
                : isDark
                    ? cs.surfaceVariant.withOpacity(0.5)
                    : cs.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isDone
                  ? const Color(0xFF48BB78).withOpacity(0.25)
                  : cs.onSurface.withOpacity(0.07),
              width: 1.5,
            ),
            boxShadow: widget.isDone
                ? null
                : [
                    BoxShadow(
                      color: cs.onSurface.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(children: [
            // Icon box
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: widget.isDone
                    ? const Color(0xFF48BB78).withOpacity(0.12)
                    : cs.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                  child:
                      Text(icon, style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 14),

            // Text
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  goalName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: -0.3,
                    decoration:
                        widget.isDone ? TextDecoration.lineThrough : null,
                    decorationColor:
                        cs.onSurface.withOpacity(0.3),
                    color: widget.isDone
                        ? cs.onSurface.withOpacity(0.4)
                        : cs.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Row(children: [
                  Icon(Icons.groups_rounded,
                      size: 11,
                      color: cs.onSurface.withOpacity(
                          widget.isDone ? 0.25 : 0.35)),
                  const SizedBox(width: 4),
                  Text(
                    groupName,
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withOpacity(
                            widget.isDone ? 0.3 : 0.45),
                        fontWeight: FontWeight.w500),
                  ),
                ]),
              ]),
            ),

            // Status button
            if (widget.isDone)
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF48BB78).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    size: 18, color: Color(0xFF48BB78)),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primary, cs.primary.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Text(
                  'Go →',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

// ── All Done Banner ────────────────────────────────────────────────────────
class _AllDoneBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF38A169), Color(0xFF48BB78)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🔥', style: TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        const Text(
          'Streak alive! Come back tomorrow.',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ]),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────
class _EmptyRitualsView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            '✨',
            style: const TextStyle(fontSize: 64),
          )
              .animate()
              .scale(
                begin: const Offset(0.5, 0.5),
                end: const Offset(1.0, 1.0),
                curve: Curves.elasticOut,
                duration: 700.ms,
              ),
          const SizedBox(height: 20),
          const Text(
            'No rituals yet',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5),
          )
              .animate(delay: 100.ms)
              .fadeIn(duration: 400.ms),
          const SizedBox(height: 8),
          Text(
            'Join a group and add goals to\nsee your daily rituals here.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: cs.onSurface.withOpacity(0.45)),
          )
              .animate(delay: 200.ms)
              .fadeIn(duration: 400.ms),
        ]),
      ),
    );
  }
}
