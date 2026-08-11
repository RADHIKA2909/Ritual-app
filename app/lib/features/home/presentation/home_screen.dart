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
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/status_style.dart';
import '../../../core/utils/plurals.dart';
import '../../../core/network/socket_service.dart';
import '../../../core/network/socket_events.dart';
import '../../analytics/domain/my_analytics_provider.dart';
import '../../goals/presentation/widgets/check_in_button.dart';
import '../../groups/domain/models/group_progress.dart';
import '../domain/my_progress_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  String _userName = 'there';
  bool _isDemoUser = false;
  bool _demoBannerDismissed = false;
  bool _nudgeDismissed = false;
  bool _confettiPlayed = false;
  late ConfettiController _confettiController;
  late final Function(dynamic) _checkinUpdatedHandler;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _confettiController = ConfettiController(duration: const Duration(seconds: 4));
    _checkinUpdatedHandler = (payload) {
      if (!mounted) return;
      // The personal-room payload names the group, so a teammate's check-in
      // only refreshes that group rather than every group the user is in.
      final groupId = groupIdFromCheckinPayload(payload);
      final notifier = ref.read(myProgressProvider.notifier);
      groupId != null ? notifier.refreshGroup(groupId) : notifier.refreshSilently();
      ref.invalidate(myAnalyticsProvider);
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
    SocketService().off(SocketEvents.checkinUpdated, _checkinUpdatedHandler);
    _confettiController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // Catch up on anything missed while backgrounded / disconnected.
      ref.read(myProgressProvider.notifier).refreshSilently();
      ref.invalidate(myAnalyticsProvider);
      SocketService().off(SocketEvents.checkinUpdated, _checkinUpdatedHandler);
      SocketService().on(SocketEvents.checkinUpdated, _checkinUpdatedHandler);
    }
  }

  // Must match backend/src/services/demoSeedService.ts's DEMO_EMAIL.
  static const _demoEmail = 'demo@ritual.app';

  Future<void> _loadUserNameAndSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name') ?? 'there';
    final email = prefs.getString('user_email');
    final userId = prefs.getString('user_id');
    if (mounted) {
      setState(() {
        _userName = name.split(' ').first;
        _isDemoUser = email == _demoEmail;
      });
    }
    if (userId != null) {
      // main() already bootstraps this; harmless to re-assert after a login.
      SocketService().initSocket();
      SocketService().joinUserRoom(userId);
    }
    SocketService().on(SocketEvents.checkinUpdated, _checkinUpdatedHandler);
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
                iconBg: AppTheme.danger.withOpacity(0.1),
                iconColor: AppTheme.danger,
                labelColor: AppTheme.danger,
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
    final progressState = ref.watch(myProgressProvider);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Demo account notice ──────────────────────────────────
              if (_isDemoUser && !_demoBannerDismissed)
                SliverToBoxAdapter(
                  child: _DemoBanner(
                    onDismiss: () => setState(() => _demoBannerDismissed = true),
                  ),
                ),

              // ── Group hero ────────────────────────────────────────────
              // The headline is OUR progress, not mine. One card per group,
              // swipeable when the user belongs to several.
              SliverToBoxAdapter(
                child: _GroupHeroCarousel(
                  greeting: _greeting,
                  userName: _userName,
                  todayLabel: _todayLabel,
                  progressState: progressState,
                  cs: cs,
                  isDark: isDark,
                  onSettings: () => _showSettings(context),
                ),
              ),

              // ── Streak at risk ────────────────────────────────────────
              progressState.maybeWhen(
                data: (groups) {
                  final atRisk = groups
                      .where((g) => g.streakStatus == StreakStatus.atRisk)
                      .toList();
                  if (_nudgeDismissed || atRisk.isEmpty) {
                    return const SliverToBoxAdapter(child: SizedBox.shrink());
                  }
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                      child: _StreakAtRiskBanner(
                        group: atRisk.first,
                        onDismiss: _dismissNudge,
                        cs: cs,
                      ),
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.3, end: 0),
                  );
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
              progressState.when(
                loading: () => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: _ShimmerRitualList(),
                  ),
                ),
                error: (_, __) => const SliverToBoxAdapter(child: SizedBox(height: 16)),
                data: (groups) {
                  // Flatten today's rituals across groups; pending first.
                  final pending = <(GroupProgress, GroupGoalProgress)>[];
                  final done = <(GroupProgress, GroupGoalProgress)>[];
                  for (final group in groups) {
                    for (final goal in group.goals) {
                      (goal.currentUserCompletedToday ? done : pending)
                          .add((group, goal));
                    }
                  }

                  final total = pending.length + done.length;
                  if (done.length == total && total > 0 && !_confettiPlayed) {
                    WidgetsBinding.instance.addPostFrameCallback((_) => _playConfettiOnce());
                  }

                  if (total == 0) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                        child: _EmptyRitualsCard(onTap: () => context.go('/dashboard')),
                      ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
                    );
                  }

                  final preview = [...pending, ...done].take(4).toList();

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final (group, goal) = preview[i];
                          return _RitualTile(
                            index: i,
                            goal: goal,
                            groupName: group.groupName,
                            groupId: group.groupId,
                            isSolo: group.isSolo,
                          );
                        },
                        childCount: preview.length,
                      ),
                    ),
                  );
                },
              ),

              // ── This Week ─────────────────────────────────────────────
              progressState.maybeWhen(
                data: (groups) {
                  final allGoals = [for (final g in groups) ...g.goals];
                  if (allGoals.isEmpty) {
                    return const SliverToBoxAdapter(child: SizedBox.shrink());
                  }

                  // Server-derived: my own check-ins this week, and how many
                  // rituals the GROUP has already met.
                  final totalThisWeek = allGoals.fold<int>(
                      0, (s, g) => s + g.currentUserCount);
                  final goalsMet = allGoals
                      .where((g) => g.status == GoalStatus.completed)
                      .length;

                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                      child: _WeekSummarySection(
                        totalThisWeek: totalThisWeek,
                        goalsMet: goalsMet,
                        totalGoals: allGoals.length,
                        weekday: DateTime.now().weekday,
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

/// The group hero — "OUR progress", one card per group.
///
/// Replaces the old personal hero that showed "N of M today" across every
/// group at once. With several groups this is a swipeable PageView; with one
/// it renders a single static card and no page dots.
class _GroupHeroCarousel extends StatefulWidget {
  final String greeting;
  final String userName;
  final String todayLabel;
  final AsyncValue<List<GroupProgress>> progressState;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onSettings;

  const _GroupHeroCarousel({
    required this.greeting,
    required this.userName,
    required this.todayLabel,
    required this.progressState,
    required this.cs,
    required this.isDark,
    required this.onSettings,
  });

  @override
  State<_GroupHeroCarousel> createState() => _GroupHeroCarouselState();
}

class _GroupHeroCarouselState extends State<_GroupHeroCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.995);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.progressState.value ?? const <GroupProgress>[];

    // No groups yet (or still loading) — keep the greeting card so the screen
    // never renders empty.
    if (groups.isEmpty) {
      return _HeroShell(
        cs: widget.cs,
        isDark: widget.isDark,
        allDone: false,
        onSettings: widget.onSettings,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _HeroGreeting(
            greeting: widget.greeting,
            userName: widget.userName,
            todayLabel: widget.todayLabel,
          ),
          const SizedBox(height: 20),
          Text(
            widget.progressState.isLoading
                ? 'Loading your rituals…'
                : 'Habits are better together',
            style: TextStyle(
                fontSize: 13, color: Colors.white.withOpacity(0.75)),
          ),
        ]),
      ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.1, end: 0);
    }

    final safePage = _page.clamp(0, groups.length - 1);

    return Column(
      children: [
        SizedBox(
          // Card's 56px top margin + 48px padding + content (~172px at
          // default text scale) left this at a knife-edge — a system
          // font-scale bump could overflow. +8px of slack here is close to
          // imperceptible; content is top-aligned in the card, so a much
          // bigger bump would show as visible empty space at the bottom.
          height: 284,
          child: PageView.builder(
            controller: _controller,
            physics: groups.length == 1
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            onPageChanged: (i) => setState(() => _page = i),
            itemCount: groups.length,
            itemBuilder: (_, i) => _GroupHeroCard(
              group: groups[i],
              greeting: widget.greeting,
              userName: widget.userName,
              todayLabel: widget.todayLabel,
              cs: widget.cs,
              isDark: widget.isDark,
              onSettings: widget.onSettings,
              showGreeting: i == 0,
            ),
          ),
        ),
        if (groups.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < groups.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == safePage ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == safePage
                        ? widget.cs.primary
                        : widget.cs.onSurface.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ],
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.1, end: 0);
  }
}

/// One group's card: who's checked in, the shared streak, and what today needs.
class _GroupHeroCard extends StatelessWidget {
  final GroupProgress group;
  final String greeting;
  final String userName;
  final String todayLabel;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onSettings;
  final bool showGreeting;

  const _GroupHeroCard({
    required this.group,
    required this.greeting,
    required this.userName,
    required this.todayLabel,
    required this.cs,
    required this.isDark,
    required this.onSettings,
    required this.showGreeting,
  });

  @override
  Widget build(BuildContext context) {
    final done = group.todaySummary.membersDoneToday;
    final total = group.memberCount;
    final allDone = group.goals.isNotEmpty &&
        group.todaySummary.goalsWaitingOnAnyoneToday == 0;
    final ringDone = group.goalsDoneByMeToday.length;
    final ringTotal = group.goals.length;

    return _HeroShell(
      cs: cs,
      isDark: isDark,
      allDone: allDone,
      onSettings: onSettings,
      child: Row(
        // .start, not .center: the settings gear is an absolutely-positioned
        // overlay pinned to the card's top-right (see _HeroShell), sharing
        // this Row's coordinate space. Centering made the ring's position
        // depend on the text column's height — on a short card (e.g. no
        // streak pill to show) the row shrinks and the vertically-centered
        // ring rides up into the gear icon. Top-aligning plus a fixed
        // clearance on the ring column keeps it clear of the icon always.
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showGreeting)
                  _HeroGreeting(
                    greeting: greeting,
                    userName: userName,
                    todayLabel: todayLabel,
                    compact: true,
                  )
                else
                  Text(todayLabel,
                      style: TextStyle(
                          fontSize: 12, color: Colors.white.withOpacity(0.65))),
                const SizedBox(height: 12),

                // The group, not the person.
                Text(
                  group.groupName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.6),
                ),
                const SizedBox(height: 4),
                Text(
                  // Explicitly "members" — this counts people, not rituals.
                  '$done/$total ${plural(total, 'member')} checked in',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.85)),
                ),
                const SizedBox(height: 10),

                // Shared streak, on white-on-gradient rather than the themed pill.
                if (group.groupStreak > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('🔥', style: TextStyle(fontSize: 11)),
                      const SizedBox(width: 4),
                      Text(
                        weekStreakLabel(group.groupStreak),
                        style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 10),
                ],

                Text(
                  StatusStyle.todayHeadline(group),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.8)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (ringTotal > 0)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Clears the gear icon's footprint (18px icon + 8px padding
                // each side = 34px) plus a small gap, regardless of how tall
                // the text column ends up being.
                const SizedBox(height: 40),
                _CompletionRing(
                  progress: ringDone / ringTotal,
                  done: ringDone,
                  total: ringTotal,
                ),
                const SizedBox(height: 4),
                // The ring counts MY rituals today, not the group's — this
                // sits right next to a member count, so the unit needs saying.
                Text(
                  'yours',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.6)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// The gradient card chrome shared by every hero variant.
class _HeroShell extends StatelessWidget {
  final Widget child;
  final ColorScheme cs;
  final bool isDark;
  final bool allDone;
  final VoidCallback onSettings;

  const _HeroShell({
    required this.child,
    required this.cs,
    required this.isDark,
    required this.allDone,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 56, 20, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: allDone
              ? [AppTheme.success, AppTheme.successDeep]
              : isDark
                  ? [cs.primary.withOpacity(0.9), cs.primary.withOpacity(0.5)]
                  : [cs.primary, cs.primary.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusHero),
        boxShadow: [
          BoxShadow(
            color: (allDone ? AppTheme.success : cs.primary).withOpacity(0.35),
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

          // Settings button — top-right of card
          Positioned(
            top: 0, right: 0,
            child: GestureDetector(
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
          ),

          child,
        ],
      ),
    );
  }
}

class _HeroGreeting extends StatelessWidget {
  final String greeting;
  final String userName;
  final String todayLabel;
  final bool compact;

  const _HeroGreeting({
    required this.greeting,
    required this.userName,
    required this.todayLabel,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(greeting,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.75))),
      if (!compact) ...[
        const SizedBox(height: 6),
        Text(userName,
            style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -1)),
      ],
      const SizedBox(height: 4),
      Text(todayLabel,
          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.65))),
    ]);
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
  final GroupGoalProgress goal;
  final String groupName;
  final String groupId;
  final bool isSolo;

  const _RitualTile({
    required this.index,
    required this.goal,
    required this.groupName,
    required this.groupId,
    required this.isSolo,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = AppTheme.accentForIndex(index);
    // Personal: I checked in today (dims + strikes the title, my own to-do).
    // Group: the ritual met its weekly commitment (tints the card success
    // green). The two are independent — my own tint stays purple/primary so
    // it never reads as "the group finished this".
    final isCompleted = goal.currentUserCompletedToday;
    final isGroupComplete = goal.status == GoalStatus.completed;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isGroupComplete
            ? AppTheme.success.withOpacity(0.06)
            : isCompleted
                ? cs.primary.withOpacity(0.05)
                : Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1A1830)
                    : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isGroupComplete
              ? AppTheme.success.withOpacity(0.25)
              : isCompleted
                  ? cs.primary.withOpacity(0.2)
                  : cs.onSurface.withOpacity(0.06),
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
            color: isGroupComplete
                ? AppTheme.success
                : isCompleted
                    ? cs.primary.withOpacity(0.4)
                    : accent,
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
            color: isGroupComplete
                ? AppTheme.success.withOpacity(0.14)
                : accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(child: Text(goal.icon, style: const TextStyle(fontSize: 20))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push('/group/$groupId'),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(goal.goalName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                    color: isCompleted ? cs.onSurface.withOpacity(0.4) : cs.onSurface,
                  )),
              const SizedBox(height: 2),
              Text(
                // Once you're done, show what the group still needs.
                isCompleted && !isSolo ? StatusStyle.goalHint(goal, isSolo: isSolo) : groupName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.4)),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: CheckInButton(
            goalId: goal.goalId,
            groupId: groupId,
            date: DateTime.now(),
            isCompleted: isCompleted,
            size: CheckInButtonSize.compact,
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
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('This Week',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          GestureDetector(
            onTap: () => context.push('/my-analytics'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.bar_chart_rounded, size: 14, color: cs.primary),
                const SizedBox(width: 5),
                Text('My Analytics',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.primary)),
              ]),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(children: [
        // "Your" — this counts only my own check-ins across every group.
        _StatCard(icon: '✅', value: '$totalThisWeek', label: 'Your check-ins',
            color: const Color(0xFF48BB78), cs: cs),
        const SizedBox(width: 10),
        // "· group" — this is the GROUP's weakest-link count, not mine; it can
        // read 0 even when my own check-ins above are high.
        _StatCard(icon: '🎯', value: '$goalsMet/$totalGoals', label: 'Rituals met · group',
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
            'Build lasting habits with your friends & family. Create a group, set shared rituals, and check in every day.',
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

// ── Streak At Risk Banner ─────────────────────────────────────────────────────

/// Shown when a group's streak needs attention.
///
/// Replaces the old "You missed yesterday!" banner, which fired on a purely
/// personal signal. This is driven by the server's streakStatus, and its copy
/// comes from StatusStyle — encouraging, never blaming.
class _StreakAtRiskBanner extends StatelessWidget {
  final GroupProgress group;
  final VoidCallback onDismiss;
  final ColorScheme cs;

  const _StreakAtRiskBanner({
    required this.group,
    required this.onDismiss,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final style = StatusStyle.forStreak(group);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.warning, AppTheme.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppTheme.warning.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        const Text('\u{1F525}', style: TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Fixed lead-in first, variable group name last — a long name
            // now trims itself instead of clipping away the whole message.
            Text('Keep the streak alive — ${group.groupName}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
            Text(style.encouragement,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
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

// ── Demo account notice ─────────────────────────────────────────────────────
class _DemoBanner extends StatelessWidget {
  final VoidCallback onDismiss;

  const _DemoBanner({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withOpacity(0.25)),
      ),
      child: Row(children: [
        const Text('\u{1F440}', style: TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            "You're viewing a shared public demo — data resets daily.",
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
              color: cs.onSurface.withOpacity(0.8),
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.close_rounded, size: 18, color: cs.onSurface.withOpacity(0.5)),
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
