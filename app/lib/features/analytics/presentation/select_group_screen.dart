import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../groups/domain/group_provider.dart';

class SelectGroupAnalyticsScreen extends ConsumerWidget {
  const SelectGroupAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupState = ref.watch(groupProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Select a Group'),
      ),
      body: SafeArea(
        child: groupState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (groups) {
            if (groups.isEmpty) {
              return Center(
                child: Text(
                  'You are not in any groups yet.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    title: Text(
                      group['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    subtitle: Text(
                      '${group['members'].length} members',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54)),
                    ),
                    trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54)),
                    onTap: () {
                      context.push('/group/${group['_id']}/analytics');
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
