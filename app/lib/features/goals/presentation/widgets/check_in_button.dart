import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/goal_provider.dart';
import '../../domain/pending_check_in_provider.dart';

enum CheckInButtonSize { compact, regular }

/// The check-in affordance, used everywhere a ritual can be completed.
///
/// Replaces the old "Go →" pills, which looked like buttons but were decoration
/// inside a card-wide tap target that merely navigated to the group.
///
/// Three states:
///   • not done  → filled "Check in"
///   • in flight → same pill, disabled, spinner
///   • done      → ghost "✓ Done", tap to undo
///
/// Duplicate taps are dropped by `pendingCheckInProvider`, and the underlying
/// request sends an explicit `completed` value, so a fast double tap converges
/// instead of silently undoing the check-in.
class CheckInButton extends ConsumerWidget {
  final String goalId;

  /// The goal's group — needed to refresh that group's progress once the
  /// check-in lands, so the button and every group total update together.
  final String groupId;

  final DateTime date;
  final bool isCompleted;
  final CheckInButtonSize size;

  /// Called after a successful change, with the new completed value.
  final void Function(bool completed)? onChanged;

  const CheckInButton({
    super.key,
    required this.goalId,
    required this.groupId,
    required this.date,
    required this.isCompleted,
    this.size = CheckInButtonSize.regular,
    this.onChanged,
  });

  Future<void> _handleTap(WidgetRef ref) async {
    final target = !isCompleted;
    HapticFeedback.selectionClick();
    // `setCheckIn` refreshes this group's progress itself (both the
    // cross-group and single-group caches) before returning, so `pending`
    // here — and thus the spinner — covers the full round trip: no gap where
    // the spinner's gone but `isCompleted` hasn't caught up yet.
    final ok =
        await ref.read(checkInProvider.notifier).setCheckIn(goalId, groupId, date, target);
    if (!ok) return;
    onChanged?.call(target);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final pending = ref.watch(pendingCheckInProvider).contains(
          pendingCheckInKey(goalId, date),
        );

    final compact = size == CheckInButtonSize.compact;
    final hPad = compact ? 12.0 : 16.0;
    final vPad = compact ? 8.0 : 10.0;
    final fontSize = compact ? 12.0 : 13.0;
    final spinnerSize = compact ? 14.0 : 16.0;

    // Done — ghost pill in success green, tappable to undo.
    if (isCompleted && !pending) {
      return Semantics(
        button: true,
        label: 'Checked in. Tap to undo.',
        child: GestureDetector(
          onTap: () => _handleTap(ref),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              border: Border.all(color: AppTheme.success.withOpacity(0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_rounded, size: fontSize + 3, color: AppTheme.success),
                const SizedBox(width: 5),
                Text(
                  'Done',
                  style: TextStyle(
                    color: AppTheme.success,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Not done, or a request in flight.
    return Semantics(
      button: true,
      enabled: !pending,
      label: pending ? 'Checking in' : 'Check in',
      child: GestureDetector(
        onTap: pending ? null : () => _handleTap(ref),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                cs.primary.withOpacity(pending ? 0.6 : 1.0),
                cs.primary.withOpacity(pending ? 0.45 : 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            boxShadow: pending
                ? null
                : [
                    BoxShadow(
                      color: cs.primary.withOpacity(0.32),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: pending
              ? SizedBox(
                  height: spinnerSize,
                  width: spinnerSize + 42,
                  child: const Center(
                    child: SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  ),
                )
              : Text(
                  'Check in',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
        ),
      ),
    );
  }
}
