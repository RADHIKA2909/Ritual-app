import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/socket_service.dart';
import '../../../core/utils/plurals.dart';

final _feedProvider = FutureProvider.family<List<dynamic>, String>((ref, groupId) async {
  final response = await ApiClient.instance.get('/groups/$groupId/feed');
  return response.data as List<dynamic>;
});

class GroupFeedScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupFeedScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupFeedScreen> createState() => _GroupFeedScreenState();
}

class _GroupFeedScreenState extends ConsumerState<GroupFeedScreen> {
  late final Function(dynamic) _checkinHandler;

  @override
  void initState() {
    super.initState();
    _checkinHandler = (_) {
      if (mounted) ref.invalidate(_feedProvider(widget.groupId));
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(_feedProvider(widget.groupId));
    });
    SocketService().on('checkin_updated', _checkinHandler);
  }

  @override
  void dispose() {
    SocketService().off('checkin_updated', _checkinHandler);
    super.dispose();
  }

  String _timeAgo(String isoDate) {
    final date = DateTime.parse(isoDate).toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(itemDay).inDays;

    // A future-dated check-in (clock skew between devices) shouldn't render
    // as "-1 days ago" — treat anything non-positive as "Today".
    if (diff <= 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '${count(diff, 'day')} ago';
    return '${count((diff / 7).floor(), 'week')} ago';
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(_feedProvider(widget.groupId));
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
        title: const Text('Activity',
            style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3)),
      ),
      body: feedState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (feed) {
          if (feed.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.dynamic_feed_rounded,
                      size: 56, color: cs.onSurface.withOpacity(0.15)),
                  const SizedBox(height: 16),
                  Text('No activity yet.',
                      style: TextStyle(
                          fontSize: 16,
                          color: cs.onSurface.withOpacity(0.4))),
                  const SizedBox(height: 6),
                  Text('Check-ins will appear here.',
                      style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.withOpacity(0.25))),
                ]),
              ),
            );
          }

          // Group feed items by date label
          final grouped = <String, List<dynamic>>{};
          for (final item in feed) {
            final label = _timeAgo(item['date'] as String);
            grouped.putIfAbsent(label, () => []).add(item);
          }

          final sections = grouped.entries.toList();

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            itemCount: sections.length,
            itemBuilder: (ctx, si) {
              final section = sections[si];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date header
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 10, left: 2),
                    child: Text(
                      section.key,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: cs.onSurface.withOpacity(0.4),
                      ),
                    ),
                  ),
                  ...section.value.map((item) => _FeedItem(item: item)),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _FeedItem extends StatelessWidget {
  final Map<String, dynamic> item;
  const _FeedItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = item['userName'] as String? ?? '';
    final goalName = item['goalName'] as String? ?? '';
    final goalIcon = item['goalIcon'] as String? ?? '🎯';
    final note = (item['note'] as String?) ?? '';
    final reactions = (item['reactions'] as List<dynamic>?) ?? [];

    // Aggregate reactions: emoji → count
    final Map<String, int> reactionCounts = {};
    for (final r in reactions) {
      final emoji = r['emoji'] as String;
      reactionCounts[emoji] = (reactionCounts[emoji] ?? 0) + 1;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.onSurface.withOpacity(0.05)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Avatar
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.primary.withOpacity(0.12),
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Name + goal
            RichText(
              text: TextSpan(
                style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface,
                    height: 1.4),
                children: [
                  TextSpan(
                    text: name.split(' ').first,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: ' checked in  $goalIcon $goalName',
                    style: TextStyle(color: cs.onSurface.withOpacity(0.7)),
                  ),
                ],
              ),
            ),

            // Note
            if (note.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '"$note"',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: cs.onSurface.withOpacity(0.65),
                    height: 1.4,
                  ),
                ),
              ),
            ],

            // Reactions
            if (reactionCounts.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 5,
                children: reactionCounts.entries.map((e) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: cs.onSurface.withOpacity(0.08)),
                    ),
                    child: Text(
                      '${e.key} ${e.value}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                }).toList(),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}
