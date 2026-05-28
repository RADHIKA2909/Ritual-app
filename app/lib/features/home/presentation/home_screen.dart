import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import 'package:shimmer/shimmer.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(myAnalyticsProvider);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SocketService().off('checkin_updated', _checkinUpdatedHandler);
    _confettiController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.invalidate(myAnalyticsProvider);
      SocketService().off('checkin_updated', _checkinUpdatedHandler);
      SocketService().on('checkin_updated', _checkinUpdatedHandler);
    }
  }

  Future<void> _loadUserNameAndSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name') ?? 'there';
    final userId = prefs.getString('user_id');
    if (mounted) setState(() => _userName = name.split(' ').first);
    if (userId != null) {
      SocketService().initSocket();
      SocketService().joinUserRoom(userId);
    }
    SocketService().on('checkin_updated', _checkinUpdatedHandler);
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
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Consumer(builder: (ctx2, ref2, __) {
        final themeMode = ref2.watch(themeProvider).value ?? ThemeMode.dark;
        final isDark = themeMode == ThemeMode.dark;
        final cs2 = Theme.of(ctx2).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: cs2.onSurface.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text('Settings',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              const SizedBox(height: 20),
              _SettingsTile(
                icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                label: isDark ? 'Dark Mode' : 'Light Mode',
                iconBg: cs2.primary.withOpacity(0.1),
                iconColor: cs2.primary,
                trailing: Switch.adaptive(
                  value: isDark,
                  activeColor: cs2.primary,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Gradient Hero Header ──────────────────────────────────
              SliverToBoxAdapter(
                child: _HeroHeader(
                  greeting: _greeting,
                  userName: _userName,
                  todayLabel: _todayLabel,
                  analyticsState: analyticsState,
                  cs: cs,
                  isDark: isDark,
                  onSettings: () => _showSettings(context),
                ),
              ),

              // ── Missed Yesterday Nudge ────────────────────────────────
              analyticsState.maybeWhen(
                data: (data) {
                  final goals = data['goals'] as List<dynamic>;
                  final checkIns = data['checkIns'] as List<dynamic>;
                  if (!_nudgeDismissed && _hasMissedYesterday(goals, checkIns)) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                        child: _MissedYesterdayBanner(onDismiss: _dismissNudge, cs: cs),
                      ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.3, end: 0),
                    );
                  }
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                },
                orElse: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),

              // ── Today's Rituals header ────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Today's Rituals",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5))
                          .animate().fadeIn(delay: 200.ms).slideX(begin: -0.1, end: 0),
                      GestureDetector(
                        onTap: () => context.push('/todays-rituals'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: cs.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('See all',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.primary)),
                        ),
                      ).animate().fadeIn(delay: 300.ms),
                    ],
                  ),
                ),
              ),

              // ── Rituals list / empty state ────────────────────────────
              analyticsState.when(
                loading: () => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: _ShimmerRitualList(),
                  ),
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

                  final doneCount = done.length;
                  final total = goals.length;
                  if (doneCount == total && total > 0 && !_confettiPlayed) {
                    WidgetsBinding.instance.addPostFrameCallback((_) => _playConfettiOnce());
                  }

                  if (goals.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                        child: _EmptyRitualsCard(onTap: () => context.go('/dashboard')),
                      ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
                    );
                  }

                  final all = [...pending, ...done];
                  final preview = all.take(4).toList();

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final goal = preview[i];
                          final isCompleted = done.contains(goal);
                          final group = groups.firstWhere(
                            (g) => g['_id'] == goal['groupId'],
                            orElse: () => {'name': '', '_id': ''},
                          );
                          return _RitualTile(
                            index: i,
                            goal: goal,
                            group: group,
                            isCompleted: isCompleted,
                            onGo: () => context.push('/group/${group['_id']}'),
                          );
                        },
                        childCount: preview.length,
                      ),
                    ),
                  );
                },
              ),

              // ── This Week ─────────────────────────────────────────────
              analyticsState.maybeWhen(
                data: (data) {
                  final goals = data['goals'] as List<dynamic>;
                  final checkIns = data['checkIns'] as List<dynamic>;
                  if (goals.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

                  final now = DateTime.now();
                  final monday = DateTime(now.year, now.month, now.day)
                      .subtract(Duration(days: now.weekday - 1));
                  final sunday = monday.add(const Duration(days: 6));

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
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                      child: _WeekSummarySection(
                        totalThisWeek: totalThisWeek,
                        goalsMet: goalsMet,
                        totalGoals: goals.length,
                        weekday: now.weekday,
                        cs: cs,
                      ),
                    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.15, end: 0),
                  );
                },
                orElse: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),

          // ── Confetti overlay ──────────────────────────────────────────
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 40,
              gravity: 0.3,
              colors: [cs.primary, Colors.amber, Colors.pinkAccent, Colors.lightGreenAccent, Colors.cyan],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero Header ──────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final String greeting;
  final String userName;
  final String todayLabel;
  final AsyncValue<Map<String, dynamic>> analyticsState;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onSettings;

  const _HeroHeader({
    required this.greeting,
    required this.userName,
    required this.todayLabel,
    required this.analyticsState,
    required this.cs,
    required this.isDark,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final stateData = analyticsState.value;
    final doneCount = stateData?['goals'] != null
        ? _computeDone(
            stateData!['goals'] as List<dynamic>,
            stateData['checkIns'] as List<dynamic>,
          )
        : null;
    final total = (stateData?['goals'] as List<dynamic>?)?.length ?? 0;
    final progress = total == 0 ? 0.0 : (doneCount ?? 0) / total;
    final allDone = total > 0 && (doneCount ?? 0) == total;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 56, 20, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: allDone
              ? [const Color(0xFF48BB78), const Color(0xFF38A169)]
              : isDark
                  ? [cs.primary.withOpacity(0.9), cs.primary.withOpacity(0.5)]
                  : [cs.primary, cs.primary.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: (allDone ? const Color(0xFF48BB78) : cs.primary).withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(right: -20, top: -30,
            child: Container(width: 120, height: 120,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.06)))),
          Positioned(right: 30, bottom: -20,
            child: Container(width: 80, height: 80,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.04)))),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Settings button
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(greeting,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.75))),
                    GestureDetector(
                      onTap: onSettings,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.settings_outlined, size: 18, color: Colors.white.withOpacity(0.9)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(userName,
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800,
                          color: Colors.white, letterSpacing: -1)),
                  const SizedBox(height: 4),
                  Text(todayLabel,
                      style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.65))),
                  const SizedBox(height: 20),
                  // Progress
                  if (total > 0) ...[
                    Text(
                      allDone ? '🎉 All done!' : '${doneCount ?? 0} of $total today',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.9)),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ] else
                    Text('No rituals yet',
                        style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.65))),
                ]),
              ),
              const SizedBox(width: 20),
              // Ring
              if (total > 0)
                _CompletionRing(progress: progress, done: doneCount ?? 0, total: total),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.1, end: 0);
  }

  int _computeDone(List<dynamic> goals, List<dynamic> checkIns) {
    final now = DateTime.now();
    int done = 0;
    for (final g in goals) {
      final completed = checkIns.any((c) {
        if (c['goalId'] != g['_id']) return false;
        final d = DateTime.parse(c['date']).toLocal();
        return d.year == now.year && d.month == now.month && d.day == now.day;
      });
      if (completed) done++;
    }
    return done;
  }
}

class _CompletionRing extends StatelessWidget {
  final double progress;
  final int done;
  final int total;

  const _CompletionRing({required this.progress, required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(72, 72),
            painter: _RingPainter(progress: progress),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$done',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                    color: Colors.white, height: 1)),
            Text('/$total',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.7))),
          ]),
        ],
      ),
    ).animate().scale(begin: const Offset(0.7, 0.7), end: const Offset(1, 1),
        curve: Curves.elasticOut, duration: 800.ms, delay: 200.ms);
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;
    final paint = Paint()
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Background ring
    paint.color = Colors.white.withOpacity(0.2);
    canvas.drawCircle(center, radius, paint);

    // Progress arc
    paint.color = Colors.white;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ── Ritual Tile ──────────────────────────────────────────────────────────────

class _RitualTile extends StatelessWidget {
  final int index;
  final dynamic goal;
  final dynamic group;
  final bool isCompleted;
  final VoidCallback onGo;

  const _RitualTile({
    required this.index,
    required this.goal,
    required this.group,
    required this.isCompleted,
    required this.onGo,
  });

  static const _accentColors = [
    Color(0xFF7B6FE8), Color(0xFFE8A838), Color(0xFF48BB78),
    Color(0xFF4299E1), Color(0xFFED64A6), Color(0xFF9F7AEA),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = _accentColors[index % _accentColors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isCompleted
            ? cs.primary.withOpacity(0.05)
            : Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1A1830)
                : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCompleted ? cs.primary.withOpacity(0.2) : cs.onSurface.withOpacity(0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(children: [
        // Color accent bar
        Container(
          width: 4,
          height: 64,
          margin: const EdgeInsets.only(left: 0),
          decoration: BoxDecoration(
            color: isCompleted ? cs.primary.withOpacity(0.4) : accent,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              bottomLeft: Radius.circular(20),
            ),
          ),
        ),
        const SizedBox(width: 14),
        // Icon
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(child: Text(goal['icon'] ?? '🎯', style: const TextStyle(fontSize: 20))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(goal['name'],
                style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 15,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                  color: isCompleted ? cs.onSurface.withOpacity(0.4) : cs.onSurface,
                )),
            const SizedBox(height: 2),
            Text(group['name'] ?? '',
                style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.4))),
          ]),
        ),
        if (isCompleted)
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, size: 16, color: cs.primary),
          )
        else
          GestureDetector(
            onTap: onGo,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent, accent.withOpacity(0.75)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: accent.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: const Text('Go',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
      ]),
    ).animate(delay: Duration(milliseconds: 100 + index * 80))
        .fadeIn(duration: 400.ms)
        .slideX(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
  }
}

// ── Week Summary ─────────────────────────────────────────────────────────────

class _WeekSummarySection extends StatelessWidget {
  final int totalThisWeek;
  final int goalsMet;
  final int totalGoals;
  final int weekday;
  final ColorScheme cs;

  const _WeekSummarySection({
    required this.totalThisWeek,
    required this.goalsMet,
    required this.totalGoals,
    required this.weekday,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('This Week',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
      const SizedBox(height: 12),
      Row(children: [
        _StatCard(icon: '✅', value: '$totalThisWeek', label: 'Check-ins',
            color: const Color(0xFF48BB78), cs: cs),
        const SizedBox(width: 10),
        _StatCard(icon: '🎯', value: '$goalsMet/$totalGoals', label: 'Goals met',
            color: const Color(0xFF7B6FE8), cs: cs),
        const SizedBox(width: 10),
        _StatCard(icon: '📅', value: '$weekday/7', label: 'Day of week',
            color: const Color(0xFFE8A838), cs: cs),
      ]),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final String icon;
  final String value;
  final String label;
  final Color color;
  final ColorScheme cs;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? color.withOpacity(0.1) : color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 10, color: cs.onSurface.withOpacity(0.45),
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ── Empty Rituals Card ────────────────────────────────────────────────────────

class _EmptyRitualsCard extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyRitualsCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.primary.withOpacity(0.1), cs.primary.withOpacity(0.03)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cs.primary.withOpacity(0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('✨', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 16),
          const Text('Welcome to Ritual!',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Text(
            'Build lasting habits with your friends & family. Create a group, set shared goals, and check in every day.',
            style: TextStyle(fontSize: 14, color: cs.onSurface.withOpacity(0.55), height: 1.55),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.primary.withOpacity(0.8)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: cs.primary.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: const Text('Get Started →',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ]),
      ),
    );
  }
}

// ── Missed Yesterday Banner ───────────────────────────────────────────────────

class _MissedYesterdayBanner extends StatelessWidget {
  final VoidCallback onDismiss;
  final ColorScheme cs;
  const _MissedYesterdayBanner({required this.onDismiss, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8C00), Color(0xFFFF6B35)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        const Text('⚡', style: TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('You missed yesterday!',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
            Text("Don't break your streak — check in today.",
                style: TextStyle(fontSize: 11, color: Colors.white70)),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white70),
          onPressed: onDismiss,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ]),
    );
  }
}

// ── Shimmer Loading ───────────────────────────────────────────────────────────

class _ShimmerRitualList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF1A1830) : const Color(0xFFE8E4F5);
    final highlightColor = isDark ? const Color(0xFF231F3B) : const Color(0xFFF0EEF9);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Column(
        children: List.generate(3, (i) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          height: 72,
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(20),
          ),
        )),
      ),
    );
  }
}

// ── Settings Tile ─────────────────────────────────────────────────────────────

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
          style: TextStyle(fontWeight: FontWeight.w600,
              color: labelColor ?? Theme.of(context).colorScheme.onSurface)),
      trailing: trailing,
    );
  }
}
