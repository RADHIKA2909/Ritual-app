import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import 'models/group_progress.dart';

/// Per-group progress, scoped by groupId.
///
/// Deliberately a family: the older `goalsProvider` is a single global notifier
/// filled imperatively, so opening a second group overwrites the first one's
/// data. Keying by groupId means two groups can be in memory at once without
/// clobbering each other.
final groupProgressProvider =
    AsyncNotifierProvider.family<GroupProgressNotifier, GroupProgress, String>(
  GroupProgressNotifier.new,
);

class GroupProgressNotifier extends AsyncNotifier<GroupProgress> {
  GroupProgressNotifier(this.groupId);

  final String groupId;

  // Several things can trigger a refresh of the same group in quick
  // succession (the direct post-check-in refresh, a socket `checkin_updated`
  // for this group, another member's action) with no guarantee of arrival
  // order. Capture the counter before awaiting and only apply the result if
  // nothing newer has started since, so a slow, stale response can't stomp
  // a result that already landed.
  int _requestId = 0;

  @override
  Future<GroupProgress> build() async {
    return _fetch();
  }

  Future<GroupProgress> _fetch() async {
    final response = await ApiClient.instance.get('/groups/$groupId/progress');
    return GroupProgress.fromJson(response.data as Map<String, dynamic>);
  }

  /// Refresh without flashing a loading state — for socket-driven updates,
  /// where the screen already has good data on screen.
  Future<void> refreshSilently() async {
    final requestId = ++_requestId;
    try {
      final progress = await _fetch();
      if (requestId != _requestId) return; // superseded — discard
      state = AsyncData(progress);
    } catch (_) {
      // Keep the last good state; a transient socket-triggered refetch failing
      // shouldn't blank out a working screen.
    }
  }
}
