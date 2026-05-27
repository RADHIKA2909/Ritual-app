import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/socket_service.dart';
import '../domain/group_provider.dart';
import '../../auth/domain/auth_provider.dart';
import '../../../core/theme/theme_provider.dart';
import 'widgets/join_group_dialog.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
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
    SocketService().on('group_updated', (_) {
      if (mounted) ref.read(groupProvider.notifier).refreshGroupsSilently();
    });
  }

  @override
  void dispose() {
    SocketService().off('group_updated');
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
            const Text('Add Group',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            _BottomSheetTile(
              icon: Icons.add_circle_outline_rounded,
              title: 'Create New Group',
              subtitle: 'Start a fresh accountability space',
              onTap: () {
                Navigator.pop(context);
                context.push('/create-group');
              },
            ),
            const SizedBox(height: 10),
            _BottomSheetTile(
              icon: Icons.group_add_outlined,
              title: 'Join via Invite Code',
              subtitle: 'Enter a code from your partner',
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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () =>
              context.canPop() ? context.pop() : context.go('/home'),
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
        title: const Text('My Groups',
            style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3)),
      ),
      body: SafeArea(
        child: groupState.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (err, _) =>
              Center(child: Text('Error: $err')),
          data: (groups) {
            if (groups.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Text('🏆', style: const TextStyle(fontSize: 64)),
                  const SizedBox(height: 20),
                  const Text('Start your first group',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 8),
                  Text(
                    'Invite friends, family, or teammates.\nSet shared goals and build habits together.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: cs.onSurface.withOpacity(0.5)),
                  ),
                  const SizedBox(height: 32),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    ElevatedButton.icon(
                      onPressed: () => context.push('/create-group'),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Create'),
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14)),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => showDialog(
                          context: context,
                          builder: (_) => const JoinGroupDialog()),
                      icon: const Icon(Icons.group_add_outlined, size: 18),
                      label: const Text('Join'),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                          side: BorderSide(
                              color: cs.primary.withOpacity(0.4))),
                    ),
                  ]),
                ]),
              );
            }

            const groupAccents = [
              Color(0xFF7B6FE8), Color(0xFF48BB78), Color(0xFFED8936),
              Color(0xFFE8A838), Color(0xFF4299E1), Color(0xFFED64A6),
            ];

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              itemCount: groups.length,
              itemBuilder: (ctx, i) {
                final group = groups[i];
                final members =
                    (group['members'] as List<dynamic>?) ?? [];
                final goalCount =
                    (group['goalCount'] as num?)?.toInt() ?? 0;
                final accent = groupAccents[i % groupAccents.length];

                final otherMembers = members.where((m) {
                  final id = m is Map ? m['_id']?.toString() : m?.toString();
                  return id != _currentUserId;
                }).toList();

                String memberSummary;
                if (members.length == 1) {
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
                  memberSummary = 'You, $first +${otherMembers.length - 1}';
                }

                return GestureDetector(
                  onTap: () => context.push('/group/${group['_id']}'),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cs.surfaceVariant.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                          color: accent.withOpacity(0.2), width: 1.5),
                    ),
                    child: Row(children: [
                      // Avatar circle
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [accent, accent.withOpacity(0.55)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            (group['name'] as String)
                                .substring(0, 1)
                                .toUpperCase(),
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(group['name'],
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3)),
                          const SizedBox(height: 3),
                          Text(memberSummary,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurface.withOpacity(0.45))),
                        ]),
                      ),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$goalCount ${goalCount == 1 ? 'goal' : 'goals'}',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: accent),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Icon(Icons.chevron_right_rounded,
                            color: accent.withOpacity(0.4), size: 18),
                      ]),
                    ]),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddGroup(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Group',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _BottomSheetTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _BottomSheetTile({
    required this.icon,
    required this.title,
    required this.subtitle,
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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.primary.withOpacity(0.1)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: cs.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15)),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 12, color: cs.onSurface.withOpacity(0.45))),
          ]),
        ]),
      ),
    );
  }
}
