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
    try {
      state = AsyncData(await _fetchAll());
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
    try {
      final response = await ApiClient.instance.get('/groups/$groupId/progress');
      final updated = GroupProgress.fromJson(response.data as Map<String, dynamic>);
      state = AsyncData([
        for (final g in current) g.groupId == groupId ? updated : g,
      ]);
    } catch (_) {
      // Keep the last good state.
    }
  }
}
