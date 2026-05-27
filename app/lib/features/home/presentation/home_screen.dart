import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import '../../auth/domain/auth_provider.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/network/socket_service.dart';
import '../../analytics/domain/my_analytics_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  String _userName = 'there';
  bool _nudgeDismissed = false;
  bool _confettiPlayed = false;
  late ConfettiController _confettiController;

  // Named callback so we can remove ONLY this screen's listener in dispose
  late final Function(dynamic) _checkinUpdatedHandler;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _confettiController = ConfettiController(duration: const Duration(seconds: 4));
    _checkinUpdatedHandler = (_) {
      if (mounted) ref.invalidate(myAnalyticsProvider);
    };
    _loadUserNameAndSocket();
    _loadDismissState();
    // Always fetch fresh analytics when home screen appears
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(myAnalyticsProvider);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Pass the exact callback so other screens' listeners are NOT removed
    SocketService().off('checkin_updated', _checkinUpdatedHandler);
    _confettiController.dispose();
    super.dispose();
  }

  // Re-fetch analytics whenever the app comes back to the foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.invalidate(myAnalyticsProvider);
      // Re-register socket listener in case it was removed by another screen
      SocketService().off('checkin_updated', _checkinUpdatedHandler);
      SocketService().on('checkin_updated', _checkinUpdatedHandler);
    }
  }

  Future<void> _loadDismissState() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final dismissed = prefs.getBool('nudge_dismissed_$today') ?? false;
    final confettiPlayed = prefs.getBool('confetti_played_$today') ?? false;
    if (mounted) {
      setState(() {
        _nudgeDismissed = dismissed;
        _confettiPlayed = confettiPlayed;
      });
    }
  }

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> _dismissNudge() async {
    setState(() => _nudgeDismissed = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('nudge_dismissed_${_todayKey()}', true);
  }

  Future<void> _playConfettiOnce() async {
    if (_confettiPlayed) return;
    setState(() => _confettiPlayed = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('confetti_played_${_todayKey()}', true);
    _confettiController.play();
  }

  bool _hasMissedYesterday(List<dynamic> goals, List<dynamic> checkIns) {
    if (goals.isEmpty) return false;
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yDate = DateTime(yesterday.year, yesterday.month, yesterday.day);
    return !checkIns.any((c) {
      final d = DateTime.parse(c['date']).toLocal();
      return DateTime(d.year, d.month, d.day) == yDate;
    });
  }

  Future<void> _loadUserNameAndSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name') ?? 'there';
    final userId = prefs.getString('user_id');
    if (mounted) setState(() => _userName = name.split(' ').first);

    // Join personal user room so we receive checkin_updated events
    if (userId != null) {
      SocketService().initSocket();
      SocketService().joinUserRoom(userId);
    }
    SocketService().on('checkin_updated', _checkinUpdatedHandler);
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _todayLabel {
    final n = DateTime.now();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return '${days[n.weekday - 1]}, ${months[n.month - 1]} ${n.day}';
  }

  void _showSettings(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Theme.of(ctx).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Consumer(builder: (ctx2, ref2, __) {
        final themeMode = ref2.watch(themeProvider).value ?? ThemeMode.dark;
        final isDark = themeMode == ThemeMode.dark;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Theme.of(ctx2).colorScheme.onSurface.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text('Settings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              _SettingsTile(
                icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                label: isDark ? 'Dark Mode' : 'Light Mode',
                iconBg: Theme.of(ctx2).colorScheme.primary.withOpacity(0.1),
                iconColor: Theme.of(ctx2).colorScheme.primary,
                trailing: Switch.adaptive(
                  value: isDark,
                  activeColor: Theme.of(ctx2).colorScheme.primary,
                  onChanged: (_) => ref2.read(themeProvider.notifier).toggle(),
                ),
              ),
              const Divider(height: 16),
              _SettingsTile(
                icon: Icons.logout_rounded,
                label: 'Log Out',
                iconBg: Colors.red.withOpacity(0.1),
                iconColor: Colors.redAccent,
                labelColor: Colors.redAccent,
                onTap: () {
                  Navigator.pop(ctx2);
                  ref2.read(authProvider.notifier).logout();
                  ctx2.go('/auth');
                },
              ),
            ]),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final analyticsState = ref.watch(myAnalyticsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
        child: CustomScrollView(slivers: [
          // ── Header ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_greeting,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface.withOpacity(0.45))),
                    const SizedBox(height: 2),
                    Text(_userName,
                        style: const TextStyle(
                            fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1.2)),
                    const SizedBox(height: 2),
                    Text(_todayLabel,
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withOpacity(0.35))),
                  ]),
                  Row(children: [
                    GestureDetector(
                      onTap: () => context.push('/profile'),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.surfaceVariant.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.person_outline_rounded, size: 22, color: cs.onSurface),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _showSettings(context),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.surfaceVariant.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.settings_outlined, size: 22, color: cs.onSurface),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),

          // ── Today's Rituals ───────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text("Today's Rituals",
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
                  GestureDetector(
                    onTap: () => context.push('/todays-rituals'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('See all',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: cs.primary)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          analyticsState.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator())),
            ),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox(height: 16)),
            data: (data) {
              final goals = data['goals'] as List<dynamic>;
              final groups = data['groups'] as List<dynamic>;
              final checkIns = data['checkIns'] as List<dynamic>;
              final now = DateTime.now();
              final pending = <dynamic>[];
              final done = <dynamic>[];

              for (final g in goals) {
                final completed = checkIns.any((c) {
                  if (c['goalId'] != g['_id']) return false;
                  final d = DateTime.parse(c['date']).toLocal();
                  return d.year == now.year && d.month == now.month && d.day == now.day;
                });
                completed ? done.add(g) : pending.add(g);
              }

              // Trigger confetti when all goals done
              final doneCount = done.length;
              final total = goals.length;
              if (doneCount == total && total > 0 && !_confettiPlayed) {
                WidgetsBinding.instance.addPostFrameCallback((_) => _playConfettiOnce());
              }

              // Missed yesterday nudge
              final showNudge = !_nudgeDismissed && _hasMissedYesterday(goals, checkIns);

              if (goals.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                    child: Column(children: [
                      if (showNudge) ...[
                        _MissedYesterdayBanner(onDismiss: _dismissNudge, cs: cs),
                        const SizedBox(height: 10),
                      ],
                      _EmptyRitualsCard(onTap: () => context.push('/dashboard')),
                    ]),
                  ),
                );
              }

              final all = [...pending, ...done];
              final preview = all.take(4).toList();

              // Build item list: [nudge?] + progress bar + goal tiles
              final items = <Widget>[
                if (showNudge) _MissedYesterdayBanner(onDismiss: _dismissNudge, cs: cs),
                _ProgressBar(done: doneCount, total: total),
                ...preview.map((goal) {
                  final isCompleted = done.contains(goal);
                  final group = groups.firstWhere(
                    (g) => g['_id'] == goal['groupId'],
                    orElse: () => {'name': '', '_id': ''},
                  );
                  return _TodayRitualTile(
                    goal: goal,
                    group: group,
                    isCompleted: isCompleted,
                    onGo: () => context.push('/group/${group['_id']}'),
                  );
                }),
              ];

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => items[i],
                    childCount: items.length,
                  ),
                ),
              );
            },
          ),

          // ── This Week Summary ─────────────────────────────────────
          analyticsState.maybeWhen(
            data: (data) {
              final goals = data['goals'] as List<dynamic>;
              final checkIns = data['checkIns'] as List<dynamic>;
              if (goals.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

              final now = DateTime.now();
              final monday = DateTime(now.year, now.month, now.day)
                  .subtract(Duration(days: now.weekday - 1));
              final sunday = monday.add(const Duration(days: 6));

              // Count check-ins this week per goal
              int totalThisWeek = 0;
              int goalsMet = 0;
              for (final g in goals) {
                final gId = g['_id'];
                final weekCount = checkIns.where((c) {
                  if (c['goalId'] != gId) return false;
                  final d = DateTime.parse(c['date']).toLocal();
                  final day = DateTime(d.year, d.month, d.day);
                  return !day.isBefore(monday) && !day.isAfter(sunday);
                }).length;
                totalThisWeek += weekCount;
                if (weekCount >= (g['weeklyMinimum'] as num? ?? 3)) goalsMet++;
              }

              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('This Week',
                        style: TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
                    const SizedBox(height: 12),
                    Row(children: [
                      _WeekStatChip(
                        icon: '✅',
                        value: '$totalThisWeek',
                        label: 'Check-ins',
                        cs: cs,
                      ),
                      const SizedBox(width: 10),
                      _WeekStatChip(
                        icon: '🎯',
                        value: '$goalsMet / ${goals.length}',
                        label: 'Goals met',
                        cs: cs,
                      ),
                      const SizedBox(width: 10),
                      _WeekStatChip(
                        icon: '📅',
                        value: '${now.weekday}/7',
                        label: 'Day of week',
                        cs: cs,
                      ),
                    ]),
                  ]),
                ),
              );
            },
            orElse: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

          // ── Quick Access ──────────────────────────────────────────
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 32, 24, 0),
              child: Text('Quick Access',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 48),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.35,
              ),
              delegate: SliverChildListDelegate([
                _QuickCard(
                  label: 'My Groups',
                  icon: Icons.groups_rounded,
                  color: const Color(0xFF7B6FE8),
                  onTap: () => context.push('/dashboard'),
                ),
                _QuickCard(
                  label: 'Group\nAnalytics',
                  icon: Icons.bar_chart_rounded,
                  color: const Color(0xFFE8A838),
                  onTap: () => context.push('/select-group-analytics'),
                ),
                _QuickCard(
                  label: 'My\nAnalytics',
                  icon: Icons.insights_rounded,
                  color: const Color(0xFF48BB78),
                  onTap: () => context.push('/my-analytics'),
                ),
                _QuickCard(
                  label: "Today's\nRituals",
                  icon: Icons.task_alt_rounded,
                  color: const Color(0xFF4299E1),
                  onTap: () => context.push('/todays-rituals'),
                ),
              ]),
            ),
          ),
        ]),
      ), // closes SafeArea

      // ── Confetti overlay ─────────────────────────────────────────
      Align(
        alignment: Alignment.topCenter,
        child: ConfettiWidget(
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: false,
          numberOfParticles: 30,
          gravity: 0.3,
          colors: [
            cs.primary,
            Colors.amber,
            Colors.pinkAccent,
            Colors.lightGreenAccent,
            Colors.cyan,
          ],
        ),
      ),
    ], // closes Stack children
    ), // closes Stack
    ); // closes Scaffold
  }
}

class _ProgressBar extends StatelessWidget {
  final int done;
  final int total;
  const _ProgressBar({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = total == 0 ? 0.0 : done / total;
    final allDone = done == total && total > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: allDone
            ? cs.primary.withOpacity(0.1)
            : cs.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: allDone ? cs.primary.withOpacity(0.3) : Colors.transparent,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(
            allDone ? '🎉 All done for today!' : '$done of $total completed',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: allDone ? cs.primary : cs.onSurface.withOpacity(0.6),
            ),
          ),
          Text('${(progress * 100).toInt()}%',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: allDone ? cs.primary : cs.onSurface.withOpacity(0.4))),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: cs.onSurface.withOpacity(0.08),
            color: allDone ? cs.primary : cs.primary.withOpacity(0.7),
          ),
        ),
      ]),
    );
  }
}

class _TodayRitualTile extends StatelessWidget {
  final dynamic goal;
  final dynamic group;
  final bool isCompleted;
  final VoidCallback onGo;

  const _TodayRitualTile({
    required this.goal,
    required this.group,
    required this.isCompleted,
    required this.onGo,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isCompleted ? cs.primary.withOpacity(0.07) : cs.surfaceVariant.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted ? cs.primary.withOpacity(0.2) : Colors.transparent,
        ),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: cs.surfaceVariant.withOpacity(0.8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
              child: Text(goal['icon'] ?? '🎯', style: const TextStyle(fontSize: 20))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(goal['name'],
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                  color: isCompleted ? cs.onSurface.withOpacity(0.45) : null,
                )),
            Text(group['name'] ?? '',
                style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.4))),
          ]),
        ),
        if (isCompleted)
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, size: 15, color: cs.primary),
          )
        else
          GestureDetector(
            onTap: onGo,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Go',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
      ]),
    );
  }
}

class _EmptyRitualsCard extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyRitualsCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.primary.withOpacity(0.08), cs.primary.withOpacity(0.03)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cs.primary.withOpacity(0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('✨', style: const TextStyle(fontSize: 36)),
          const SizedBox(height: 14),
          const Text(
            'Welcome to Ritual!',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.5),
          ),
          const SizedBox(height: 6),
          Text(
            'Build lasting habits with your friends & family. Create a group, set shared goals, and check in every day.',
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withOpacity(0.55),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Get Started →',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _MissedYesterdayBanner extends StatelessWidget {
  final VoidCallback onDismiss;
  final ColorScheme cs;

  const _MissedYesterdayBanner({
    required this.onDismiss,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Text('⚡', style: TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
              'You missed yesterday!',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.orange),
            ),
            Text(
              "Don't break your streak — check in today.",
              style: TextStyle(fontSize: 11, color: Colors.orange.withOpacity(0.8)),
            ),
          ]),
        ),
        IconButton(
          icon: Icon(Icons.close_rounded, size: 18, color: Colors.orange.withOpacity(0.7)),
          onPressed: onDismiss,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ]),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.09),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.18), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.25)),
          ],
        ),
      ),
    );
  }
}

class _WeekStatChip extends StatelessWidget {
  final String icon;
  final String value;
  final String label;
  final ColorScheme cs;

  const _WeekStatChip({
    required this.icon,
    required this.value,
    required this.label,
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
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

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconBg;
  final Color iconColor;
  final Color? labelColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.iconBg,
    required this.iconColor,
    this.labelColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(label,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              color: labelColor ?? Theme.of(context).colorScheme.onSurface)),
      trailing: trailing,
    );
  }
}
