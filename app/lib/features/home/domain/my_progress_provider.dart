import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../groups/domain/models/group_progress.dart';

/// Progress for every group the user belongs to, in one request.
///
/// Home and Today's Rituals are both cross-group screens, so fetching per group
/// would be a 1+N cascade every time any member checks in anywhere.
///
/// Not autoDispose, for the same reason myAnalyticsProvider isn't: socket
/// handlers hold a ref and invalidate it from outside the widget tree.
final myProgressProvider =
    AsyncNotifierProvider<MyProgressNotifier, List<GroupProgress>>(
  MyProgressNotifier.new,
);

class MyProgressNotifier extends AsyncNotifier<List<GroupProgress>> {
  // A single check-in can trigger several concurrent refreshes of this same
  // data (the direct post-check-in refresh, plus a socket `checkin_updated`
  // echoed back to the acting user's own room, plus whatever else is
  // in-flight) with no guarantee they resolve in the order they started.
  // Each refresh captures the counter before it awaits anything and only
  // applies its result if nothing newer has started since — so a slow,
  // stale response can never stomp a result that already landed.
  int _requestId = 0;

  @override
  Future<List<GroupProgress>> build() async {
    return _fetchAll();
  }

  Future<List<GroupProgress>> _fetchAll() async {
    final response = await ApiClient.instance.get('/users/me/progress');
    return GroupProgress.listFromResponse(response.data);
  }

  /// Refresh everything without a loading flash.
  Future<void> refreshSilently() async {
    final requestId = ++_requestId;
    try {
      final result = await _fetchAll();
      if (requestId != _requestId) return; // superseded — discard
      state = AsyncData(result);
    } catch (_) {
      // Keep the last good state.
    }
  }

  /// Refresh a single group in place.
  ///
  /// `checkin_updated` on the personal room carries a groupId, so a teammate
  /// checking in only needs that one group refetched rather than all of them.
  Future<void> refreshGroup(String groupId) async {
    final current = state.value;
    if (current == null || !current.any((g) => g.groupId == groupId)) {
      // Not a group we're showing (or nothing loaded yet) — fall back to a
      // full refresh so newly joined groups still appear.
      return refreshSilently();
    }
    final requestId = ++_requestId;
    try {
      final response = await ApiClient.instance.get('/groups/$groupId/progress');
      if (requestId != _requestId) return; // superseded — discard
      final updated = GroupProgress.fromJson(response.data as Map<String, dynamic>);
      final latest = state.value ?? current;
      state = AsyncData([
        for (final g in latest) g.groupId == groupId ? updated : g,
      ]);
    } catch (_) {
      // Keep the last good state.
    }
  }

  /// Apply progress the caller already has in hand — e.g. the check-in
  /// endpoint now returns the group's updated progress in the same response,
  /// so the client that just made the change doesn't need to turn around and
  /// ask the server for it again. No network call, so this is effectively
  /// instant; still bumps the request counter so any older, still-in-flight
  /// [refreshGroup]/[refreshSilently] call can't land after this and revert it.
  void applyGroupProgress(GroupProgress progress) {
    ++_requestId;
    final current = state.value;
    if (current == null || !current.any((g) => g.groupId == progress.groupId)) {
      return; // Not a group we're showing (or nothing loaded yet) — ignore.
    }
    state = AsyncData([
      for (final g in current) g.groupId == progress.groupId ? progress : g,
    ]);
  }
}
