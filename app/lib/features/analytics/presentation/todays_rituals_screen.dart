import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/my_analytics_provider.dart';

class TodaysRitualsScreen extends ConsumerWidget {
  const TodaysRitualsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsState = ref.watch(myAnalyticsProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Today\'s Rituals', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: analyticsState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
          data: (data) {
            final goals = data['goals'] as List<dynamic>;
            final groups = data['groups'] as List<dynamic>;
            final checkIns = data['checkIns'] as List<dynamic>;

            if (goals.isEmpty) {
              return Center(
                child: Text(
                  'No rituals for today.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                ),
              );
            }

            final now = DateTime.now();
            final pendingGoals = [];
            final completedGoals = [];

            for (final goal in goals) {
              bool isCompletedToday = false;
              for (final c in checkIns) {
                if (c['goalId'] == goal['_id']) {
                  final d = DateTime.parse(c['date']).toLocal();
                  if (d.year == now.year && d.month == now.month && d.day == now.day) {
                    isCompletedToday = true;
                    break;
                  }
                }
              }

              if (isCompletedToday) {
                completedGoals.add(goal);
              } else {
                pendingGoals.add(goal);
              }
            }

            Widget buildGoalCard(dynamic goal, bool isCompleted) {
              final group = groups.firstWhere(
                (g) => g['_id'] == goal['groupId'], 
                orElse: () => {'name': 'Unknown Group'}
              );

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(isCompleted ? 0.4 : 0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: Text(goal['icon'] ?? '🎯', style: TextStyle(fontSize: 24, color: isCompleted ? Theme.of(context).colorScheme.onSurface.withOpacity(0.54) : Theme.of(context).colorScheme.onSurface)),
                  title: Text(
                    goal['name'],
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 18,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                      color: isCompleted ? Theme.of(context).colorScheme.onSurface.withOpacity(0.54) : null,
                    ),
                  ),
                  subtitle: Text(
                    group['name'],
                    style: TextStyle(color: isCompleted ? Theme.of(context).colorScheme.onSurface.withOpacity(0.38) : Theme.of(context).colorScheme.onSurface.withOpacity(0.54)),
                  ),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCompleted ? Theme.of(context).colorScheme.surface : const Color(0xFF6C63FF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      context.push('/group/${group['_id']}');
                    },
                    child: Text(
                      isCompleted ? 'See' : 'Go', 
                      style: TextStyle(color: isCompleted ? Theme.of(context).colorScheme.onSurface.withOpacity(0.54) : Colors.white)
                    ),
                  ),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (pendingGoals.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12, left: 4),
                    child: Text('To Complete', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                  ),
                  ...pendingGoals.map((g) => buildGoalCard(g, false)),
                  const SizedBox(height: 24),
                ],
                if (completedGoals.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12, left: 4),
                    child: Text('Completed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54))),
                  ),
                  ...completedGoals.map((g) => buildGoalCard(g, true)),
                ],
                if (pendingGoals.isEmpty && completedGoals.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Text('No rituals for today.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
