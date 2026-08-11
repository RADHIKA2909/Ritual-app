import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/socket_service.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/utils/plurals.dart' as plurals;

// Fetches goals + all their check-ins for a group
final _leaderboardDataProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, groupId) async {
  final goalsResp = await ApiClient.instance.get('/goals/group/$groupId');
  final goals = goalsResp.data as List<dynamic>;

  final Map<String, List<dynamic>> checkInsByGoal = {};
  await Future.wait(goals.map((g) async {
    final r = await ApiClient.instance.get('/goals/${g['_id']}/checkins');
    checkInsByGoal[g['_id'].toString()] = r.data as List<dynamic>;
  }));

  return {'goals': goals, 'checkInsByGoal': checkInsByGoal};
});

class GroupLeaderboardScreen extends ConsumerStatefulWidget {
  final String groupId;
  final List<dynamic> members;

  const GroupLeaderboardScreen({
    super.key,
    required this.groupId,
    required this.members,
  });

  @override
  ConsumerState<GroupLeaderboardScreen> createState() =>
      _GroupLeaderboardScreenState();
}

class _GroupLeaderboardScreenState
    extends ConsumerState<GroupLeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final Function(dynamic) _checkinHandler;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkinHandler = (_) {
      if (mounted) ref.invalidate(_leaderboardDataProvider(widget.groupId));
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(_leaderboardDataProvider(widget.groupId));
    });
    SocketService().on('checkin_updated', _checkinHandler);
  }

  @override
  void dispose() {
    _tabController.dispose();
    SocketService().off('checkin_updated', _checkinHandler);
    super.dispose();
  }

  // Returns { memberId: checkInCount } for the current week
  Map<String, int> _weeklyTotals(Map<String, List<dynamic>> checkInsByGoal) {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));

    final Map<String, int> totals = {};
    for (final member in widget.members) {
      totals[member['_id'].toString()] = 0;
    }

    for (final checkIns in checkInsByGoal.values) {
      for (final c in checkIns) {
        if (c['completed'] != true) continue;
        final d = DateTime.parse(c['date']).toLocal();
        final day = DateTime(d.year, d.month, d.day);
        if (day.isBefore(monday) || day.isAfter(sunday)) continue;
        final uid = c['userId'].toString();
        totals[uid] = (totals[uid] ?? 0) + 1;
      }
    }
    return totals;
  }

  // Returns { memberId: checkInCount } all-time
  Map<String, int> _allTimeTotals(Map<String, List<dynamic>> checkInsByGoal) {
    final Map<String, int> totals = {};
    for (final member in widget.members) {
      totals[member['_id'].toString()] = 0;
    }
    for (final checkIns in checkInsByGoal.values) {
      for (final c in checkIns) {
        if (c['completed'] != true) continue;
        final uid = c['userId'].toString();
        totals[uid] = (totals[uid] ?? 0) + 1;
      }
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    final dataState = ref.watch(_leaderboardDataProvider(widget.groupId));
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
        title: const Text('Leaderboard',
            style:
                TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3)),
        bottom: TabBar(
          controller: _tabController,
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          unselectedLabelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'This Week'),
            Tab(text: 'All Time'),
          ],
        ),
      ),
      body: dataState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) =>
            Center(child: Text('Error: $err')),
        data: (data) {
          final checkInsByGoal =
              data['checkInsByGoal'] as Map<String, List<dynamic>>;
          final goals = data['goals'] as List<dynamic>;
          final maxGoalCheckins = goals.length * 7; // max possible this week

          final weeklyTotals = _weeklyTotals(checkInsByGoal);
          final allTimeTotals = _allTimeTotals(checkInsByGoal);

          return TabBarView(
            controller: _tabController,
            children: [
              _buildList(cs, weeklyTotals,
                  subtitle: (n) => '${plurals.count(n, 'check-in')} this week',
                  maxValue: maxGoalCheckins > 0 ? maxGoalCheckins : 1),
              _buildList(cs, allTimeTotals,
                  subtitle: (n) => '${plurals.count(n, 'check-in')} total',
                  maxValue: allTimeTotals.values.fold(0, (a, b) => a > b ? a : b)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(
    ColorScheme cs,
    Map<String, int> totals, {
    required String Function(int) subtitle,
    required int maxValue,
  }) {
    // Sort members by count descending
    final sorted = [...widget.members];
    sorted.sort((a, b) {
      final aCount = totals[a['_id'].toString()] ?? 0;
      final bCount = totals[b['_id'].toString()] ?? 0;
      return bCount.compareTo(aCount);
    });

    if (sorted.isEmpty) {
      return Center(
        child: Text('No members yet.',
            style: TextStyle(color: cs.onSurface.withOpacity(0.4))),
      );
    }

    // Compute tied ranks: same count → same rank
    final ranks = <String, int>{};
    int currentRank = 1;
    for (int i = 0; i < sorted.length; i++) {
      final memberId = sorted[i]['_id'].toString();
      final count = totals[memberId] ?? 0;
      if (i == 0) {
        ranks[memberId] = 1;
      } else {
        final prevId = sorted[i - 1]['_id'].toString();
        final prevCount = totals[prevId] ?? 0;
        if (count == prevCount) {
          ranks[memberId] = ranks[prevId]!; // same rank as previous
        } else {
          currentRank = i + 1; // skip ranks for ties
          ranks[memberId] = currentRank;
        }
      }
    }

    final topCount = totals[sorted.first['_id'].toString()] ?? 0;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      itemCount: sorted.length,
      itemBuilder: (ctx, i) {
        final member = sorted[i];
        final memberId = member['_id'].toString();
        final count = totals[memberId] ?? 0;
        final name = member['name'] as String;
        final progress =
            maxValue > 0 ? (count / maxValue).clamp(0.0, 1.0) : 0.0;

        return _LeaderboardTile(
          rank: ranks[memberId]!,
          name: name,
          profileImage: member['profileImage'] as String?,
          count: count,
          subtitle: subtitle(count),
          progress: progress,
          isTopScore: count > 0 && count == topCount,
          cs: cs,
        );
      },
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final int rank;
  final String name;
  final String? profileImage;
  final int count;
  final String subtitle;
  final double progress;
  final bool isTopScore;
  final ColorScheme cs;

  const _LeaderboardTile({
    required this.rank,
    required this.name,
    this.profileImage,
    required this.count,
    required this.subtitle,
    required this.progress,
    required this.isTopScore,
    required this.cs,
  });

  String get _medal {
    if (count == 0) return '';
    switch (rank) {
      case 1: return '🥇';
      case 2: return '🥈';
      case 3: return '🥉';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFirst = rank == 1 && count > 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isFirst
            ? cs.primary.withOpacity(0.1)
            : cs.surfaceVariant.withOpacity(0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isFirst
              ? cs.primary.withOpacity(0.3)
              : cs.onSurface.withOpacity(0.06),
          width: 1.5,
        ),
      ),
      child: Row(children: [
        // Rank badge
        SizedBox(
          width: 36,
          child: _medal.isNotEmpty
              ? Text(_medal,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22))
              : Text(
                  '#$rank',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface.withOpacity(0.3),
                  ),
                ),
        ),
        const SizedBox(width: 12),

        // Avatar
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isFirst
                  ? cs.primary.withOpacity(0.4)
                  : cs.onSurface.withOpacity(0.1),
              width: 1.5,
            ),
          ),
          child: ClipOval(
            child: UserAvatar(
              name: name,
              profileImage: profileImage,
              radius: 21,
              colorScheme: cs,
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Name + progress
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              Text(
                name.split(' ').first,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isFirst ? cs.onSurface : cs.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isFirst
                      ? cs.primary
                      : cs.onSurface.withOpacity(0.6),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: cs.onSurface.withOpacity(0.08),
                color: isFirst
                    ? cs.primary
                    : cs.onSurface.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withOpacity(0.4),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
