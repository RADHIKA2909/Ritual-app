import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/network/socket_service.dart';
import '../domain/group_provider.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/plurals.dart';
import 'widgets/join_group_dialog.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _currentUserId;
  late final Function(dynamic) _groupUpdatedHandler;

  @override
  void initState() {
    super.initState();
    _groupUpdatedHandler = (_) {
      if (mounted) ref.read(groupProvider.notifier).refreshGroupsSilently();
    };
    SharedPreferences.getInstance().then((p) {
      if (mounted) {
        setState(() => _currentUserId = p.getString('user_id'));
        if (_currentUserId != null) _setupSocket(_currentUserId!);
      }
    });
  }

  void _setupSocket(String userId) {
    SocketService().initSocket();
    SocketService().joinUserRoom(userId);
    SocketService().on('group_updated', _groupUpdatedHandler);
  }

  @override
  void dispose() {
    SocketService().off('group_updated', _groupUpdatedHandler);
    super.dispose();
  }

  void _showAddGroup(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text('Add a Group',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            const SizedBox(height: 6),
            Text(
              'Create your own or join an existing one',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
              ),
            ),
            const SizedBox(height: 24),
            _BottomSheetTile(
              icon: Icons.add_circle_outline_rounded,
              title: 'Create New Group',
              subtitle: 'Start a fresh accountability space',
              accent: const Color(0xFF7C3AED),
              onTap: () {
                Navigator.pop(context);
                context.push('/create-group');
              },
            ),
            const SizedBox(height: 10),
            _BottomSheetTile(
              icon: Icons.group_add_outlined,
              title: 'Join via Invite Code',
              subtitle: 'Enter a 6-letter code from a friend',
              accent: const Color(0xFF48BB78),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                    context: context,
                    builder: (_) => const JoinGroupDialog());
              },
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupState = ref.watch(groupProvider);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Groups',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.2,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        groupState.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (groups) => Text(
                            groups.isEmpty
                                ? 'No groups yet'
                                : '${count(groups.length, 'active group')}',
                            style: TextStyle(
                              fontSize: 14,
                              color: cs.onSurface.withOpacity(0.45),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Theme toggle
                  GestureDetector(
                    onTap: () => ref.read(themeProvider.notifier).toggle(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cs.surfaceVariant.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: cs.onSurface.withOpacity(0.06)),
                      ),
                      child: Icon(
                        isDark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        size: 18,
                        color: cs.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Body ────────────────────────────────────────────────────
            Expanded(
              child: groupState.when(
                loading: () => _ShimmerGroupList(),
                error: (err, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off_rounded,
                          size: 48,
                          color: cs.onSurface.withOpacity(0.2)),
                      const SizedBox(height: 12),
                      Text('Could not load groups',
                          style: TextStyle(
                              color: cs.onSurface.withOpacity(0.4))),
                    ],
                  ),
                ),
                data: (groups) {
                  if (groups.isEmpty) {
                    return _EmptyGroupsView(
                      onCreateTap: () => context.push('/create-group'),
                      onJoinTap: () => showDialog(
                          context: context,
                          builder: (_) => const JoinGroupDialog()),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                    itemCount: groups.length,
                    itemBuilder: (ctx, i) {
                      final group = groups[i];
                      final members =
                          (group['members'] as List<dynamic>?) ?? [];
                      final goalCount =
                          (group['goalCount'] as num?)?.toInt() ?? 0;
                      // Was a verbatim duplicate of AppTheme.groupAccents.
                      final accent = AppTheme.accentForIndex(i);

                      final otherMembers = members.where((m) {
                        final id =
                            m is Map ? m['_id']?.toString() : m?.toString();
                        return id != _currentUserId;
                      }).toList();

                      String memberSummary;
                      if (members.length <= 1 || otherMembers.isEmpty) {
                        // Also covers a malformed/empty members list, and the
                        // brief window before _currentUserId has loaded where
                        // otherMembers can't be resolved yet — otherMembers[0]
                        // below would otherwise throw RangeError.
                        memberSummary = 'Just you';
                      } else if (otherMembers.length == 1) {
                        final name = otherMembers[0] is Map
                            ? (otherMembers[0]['name'] as String? ?? 'Someone')
                            : 'Someone';
                        memberSummary = 'You & ${name.split(' ').first}';
                      } else {
                        final first = otherMembers[0] is Map
                            ? ((otherMembers[0]['name'] as String? ?? 'Someone')
                                .split(' ')
                                .first)
                            : 'Someone';
                        memberSummary =
                            'You, $first +${otherMembers.length - 1}';
                      }

                      return _GroupCard(
                        group: group,
                        accent: accent,
                        memberSummary: memberSummary,
                        goalCount: goalCount,
                        index: i,
                      )
                          .animate(delay: (i * 60).ms)
                          .fadeIn(duration: 400.ms)
                          .slideX(
                            begin: 0.08,
                            end: 0,
                            curve: Curves.easeOutCubic,
                            duration: 400.ms,
                          );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddGroup(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Group',
            style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 4,
      )
          .animate(delay: 300.ms)
          .fadeIn(duration: 400.ms)
          .slideY(begin: 0.4, end: 0, curve: Curves.easeOutCubic),
    );
  }
}

// ── Group Card ─────────────────────────────────────────────────────────────
class _GroupCard extends StatefulWidget {
  final Map<String, dynamic> group;
  final Color accent;
  final String memberSummary;
  final int goalCount;
  final int index;

  const _GroupCard({
    required this.group,
    required this.accent,
    required this.memberSummary,
    required this.goalCount,
    required this.index,
  });

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = widget.group['name'] as String;
    final initials = name.length >= 2
        ? name.substring(0, 2).toUpperCase()
        : name.substring(0, 1).toUpperCase();

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        context.push('/group/${widget.group['_id']}');
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: isDark
                ? cs.surfaceVariant.withOpacity(0.5)
                : cs.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: widget.accent.withOpacity(0.25), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: widget.accent.withOpacity(isDark ? 0.07 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Subtle accent glow top-right
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.accent.withOpacity(0.06),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(children: [
                  // Avatar
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.accent,
                          widget.accent.withOpacity(0.6),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: widget.accent.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Text
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                        name,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4),
                      ),
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.people_rounded,
                            size: 12,
                            color: cs.onSurface.withOpacity(0.35)),
                        const SizedBox(width: 4),
                        Text(
                          widget.memberSummary,
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withOpacity(0.45),
                              fontWeight: FontWeight.w500),
                        ),
                      ]),
                    ]),
                  ),

                  // Goal badge + arrow
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: widget.accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        count(widget.goalCount, 'ritual'),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: widget.accent),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Icon(Icons.chevron_right_rounded,
                        color: cs.onSurface.withOpacity(0.25), size: 20),
                  ]),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────
class _EmptyGroupsView extends StatelessWidget {
  final VoidCallback onCreateTap;
  final VoidCallback onJoinTap;

  const _EmptyGroupsView({
    required this.onCreateTap,
    required this.onJoinTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF7C3AED).withOpacity(0.15),
                    const Color(0xFF7C3AED).withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFF7C3AED).withOpacity(0.2),
                    width: 1.5),
              ),
              child: const Center(
                  child: Text('🏆', style: TextStyle(fontSize: 44))),
            )
                .animate()
                .scale(
                  begin: const Offset(0.6, 0.6),
                  end: const Offset(1.0, 1.0),
                  curve: Curves.elasticOut,
                  duration: 700.ms,
                ),
            const SizedBox(height: 24),
            const Text(
              'Start your first group',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8),
              textAlign: TextAlign.center,
            )
                .animate(delay: 100.ms)
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.2, end: 0),
            const SizedBox(height: 10),
            Text(
              'Invite friends, family, or teammates.\nSet shared rituals and build habits together.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: cs.onSurface.withOpacity(0.5)),
            )
                .animate(delay: 200.ms)
                .fadeIn(duration: 400.ms),
            const SizedBox(height: 36),
            Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              _ActionButton(
                label: 'Create Group',
                icon: Icons.add_rounded,
                isPrimary: true,
                onTap: onCreateTap,
              ),
              const SizedBox(width: 12),
              _ActionButton(
                label: 'Join',
                icon: Icons.group_add_outlined,
                isPrimary: false,
                onTap: onJoinTap,
              ),
            ])
                .animate(delay: 300.ms)
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.2, end: 0),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (isPrimary) {
      return ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(color: cs.primary.withOpacity(0.4)),
      ),
    );
  }
}

// ── Shimmer loading list ───────────────────────────────────────────────────
class _ShimmerGroupList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF2A2A3A) : const Color(0xFFE8E8F0);
    final highlightColor =
        isDark ? const Color(0xFF3A3A4A) : const Color(0xFFF5F5FA);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        itemCount: 5,
        itemBuilder: (ctx, i) => Container(
          margin: const EdgeInsets.only(bottom: 14),
          height: 88,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }
}

// ── Bottom sheet tile ──────────────────────────────────────────────────────
class _BottomSheetTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _BottomSheetTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withOpacity(0.15)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 12, color: cs.onSurface.withOpacity(0.45))),
          ]),
          const Spacer(),
          Icon(Icons.chevron_right_rounded,
              color: cs.onSurface.withOpacity(0.2)),
        ]),
      ),
    );
  }
}
