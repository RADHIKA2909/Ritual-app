import 'package:flutter/material.dart';
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
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: cs.onSurface),
          ),
        ),
        title: const Text("Today's Rituals",
            style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3)),
      ),
      body: SafeArea(
        child: analyticsState.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
              child: Text('Error: $err',
                  style: const TextStyle(color: Colors.red))),
          data: (data) {
            final goals = data['goals'] as List<dynamic>;
            final groups = data['groups'] as List<dynamic>;
            final checkIns = data['checkIns'] as List<dynamic>;

            if (goals.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.auto_awesome_rounded,
                        size: 52, color: cs.onSurface.withOpacity(0.15)),
                    const SizedBox(height: 16),
                    Text('No rituals for today.',
                        style: TextStyle(
                            color: cs.onSurface.withOpacity(0.45),
                            fontSize: 16)),
                  ]),
                ),
              );
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

            Widget buildCard(dynamic goal, bool isDone) {
              final group = groups.firstWhere(
                (g) => g['_id'] == goal['groupId'],
                orElse: () => {'name': 'Unknown Group', '_id': ''},
              );

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDone
                      ? cs.primary.withOpacity(0.07)
                      : cs.surfaceVariant.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDone
                        ? cs.primary.withOpacity(0.2)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: isDone
                          ? cs.primary.withOpacity(0.1)
                          : cs.surfaceVariant,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                        child: Text(goal['icon'] ?? '🎯',
                            style: TextStyle(
                                fontSize: 22,
                                color: isDone
                                    ? null
                                    : null))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(goal['name'],
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            decoration:
                                isDone ? TextDecoration.lineThrough : null,
                            color: isDone
                                ? cs.onSurface.withOpacity(0.4)
                                : cs.onSurface,
                          )),
                      const SizedBox(height: 2),
                      Text(group['name'],
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withOpacity(
                                  isDone ? 0.3 : 0.45))),
                    ]),
                  ),
                  if (isDone)
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check_rounded,
                          size: 16, color: cs.primary),
                    )
                  else
                    GestureDetector(
                      onTap: () =>
                          context.push('/group/${group['_id']}'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 9),
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Go',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ),
                    ),
                ]),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                // Summary chip
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: cs.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(children: [
                    Text(
                      '${completed.length} / ${goals.length}',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: cs.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('rituals done today',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface.withOpacity(0.5))),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: goals.isEmpty
                                ? 0
                                : completed.length / goals.length,
                            minHeight: 4,
                            backgroundColor:
                                cs.onSurface.withOpacity(0.08),
                            color: cs.primary,
                          ),
                        ),
                      ]),
                    ),
                  ]),
                ),

                if (pending.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10, left: 2),
                    child: Text('To Complete',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface.withOpacity(0.45),
                            letterSpacing: 0.3)),
                  ),
                  ...pending.map((g) => buildCard(g, false)),
                  const SizedBox(height: 16),
                ],

                if (completed.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10, left: 2),
                    child: Text('Completed',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface.withOpacity(0.35),
                            letterSpacing: 0.3)),
                  ),
                  ...completed.map((g) => buildCard(g, true)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
