import 'dart:async';
import 'pending_check_in_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../groups/domain/group_provider.dart';
import '../../groups/domain/group_progress_provider.dart';
import '../../groups/domain/models/group_progress.dart';
import '../../home/domain/my_progress_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final goalsProvider = AsyncNotifierProvider<GoalsNotifier, List<dynamic>>(() {
  return GoalsNotifier();
});

class GoalsNotifier extends AsyncNotifier<List<dynamic>> {
  @override
  FutureOr<List<dynamic>> build() {
    return [];
  }

  Future<void> fetchGoals(String groupId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final response = await ApiClient.instance.get('/goals/group/$groupId');
      return response.data as List<dynamic>;
    });
  }

  Future<void> fetchGoalsSilently(String groupId) async {
    try {
      final response = await ApiClient.instance.get('/goals/group/$groupId');
      state = AsyncData(response.data as List<dynamic>);
    } catch (e) {
      // Ignore error for silent fetch
    }
  }

  Future<void> editGoal(String goalId, String groupId, {
    required String name,
    required String icon,
    required int weeklyMinimum,
  }) async {
    try {
      await ApiClient.instance.put('/goals/$goalId', data: {
        'name': name,
        'icon': icon,
        'weeklyMinimum': weeklyMinimum,
      });
      // Refresh goals list silently
      await fetchGoalsSilently(groupId);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteGoal(String goalId, String groupId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ApiClient.instance.delete('/goals/$goalId');
      ref.invalidate(groupProvider);
      final response = await ApiClient.instance.get('/goals/group/$groupId');
      return response.data as List<dynamic>;
    });
  }
}

final checkInProvider = AsyncNotifierProvider<CheckInNotifier, Map<String, List<dynamic>>>(() {
  return CheckInNotifier();
});

class CheckInNotifier extends AsyncNotifier<Map<String, List<dynamic>>> {
  @override
  FutureOr<Map<String, List<dynamic>>> build() {
    return {};
  }

  Future<void> fetchCheckIns(String goalId) async {
    final currentState = state.value ?? {};
    try {
      final response = await ApiClient.instance.get('/goals/$goalId/checkins');
      currentState[goalId] = response.data as List<dynamic>;
      state = AsyncData({...currentState});
    } catch (e) {
      // log error
    }
  }

  Future<void> updateNote(String goalId, String checkInId, String note) async {
    final currentState = state.value ?? {};
    final checkIns = List<dynamic>.from(currentState[goalId] ?? []);
    final idx = checkIns.indexWhere((c) => c['_id'] == checkInId);
    if (idx < 0) return;

    // Optimistic update
    checkIns[idx] = {...checkIns[idx], 'note': note};
    currentState[goalId] = checkIns;
    state = AsyncData({...currentState});

    try {
      final response = await ApiClient.instance.put(
        '/goals/$goalId/checkins/$checkInId/note',
        data: {'note': note},
      );
      final newCheckIns = List<dynamic>.from(currentState[goalId] ?? []);
      final realIdx = newCheckIns.indexWhere((c) => c['_id'] == checkInId);
      if (realIdx >= 0) newCheckIns[realIdx] = response.data;
      currentState[goalId] = newCheckIns;
      state = AsyncData({...currentState});
    } catch (_) {
      // silent fail — optimistic state stays
    }
  }

  Future<void> reactToCheckIn(String goalId, String checkInId, String emoji) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) return;

    final currentState = state.value ?? {};
    final checkIns = List<dynamic>.from(currentState[goalId] ?? []);
    final idx = checkIns.indexWhere((c) => c['_id'] == checkInId);
    if (idx < 0) return;

    // Optimistic update — same logic as backend
    final reactions = List<dynamic>.from(checkIns[idx]['reactions'] ?? []);
    final existingIdx = reactions.indexWhere((r) => r['userId'] == userId);
    final alreadySameEmoji =
        existingIdx >= 0 && reactions[existingIdx]['emoji'] == emoji;

    if (existingIdx >= 0) reactions.removeAt(existingIdx);
    if (!alreadySameEmoji) reactions.add({'userId': userId, 'emoji': emoji});

    checkIns[idx] = {...checkIns[idx], 'reactions': reactions};
    currentState[goalId] = checkIns;
    state = AsyncData({...currentState});

    try {
      final response = await ApiClient.instance.post(
        '/goals/$goalId/checkins/$checkInId/react',
        data: {'emoji': emoji},
      );
      // Replace with real server data
      final newCheckIns = List<dynamic>.from(currentState[goalId] ?? []);
      final realIdx = newCheckIns.indexWhere((c) => c['_id'] == checkInId);
      if (realIdx >= 0) newCheckIns[realIdx] = response.data;
      currentState[goalId] = newCheckIns;
      state = AsyncData({...currentState});
    } catch (_) {
      // silent fail — optimistic state stays
    }
  }

  /// Is there a completed check-in for this user/goal/day in local state?
  bool isCompletedOn(String goalId, String userId, DateTime date) {
    final checkIns = state.value?[goalId] ?? const [];
    for (final c in checkIns) {
      if (c['userId'] != userId) continue;
      final d = DateTime.parse(c['date']).toLocal();
      if (d.year == date.year && d.month == date.month && d.day == date.day) {
        return c['completed'] == true;
      }
    }
    return false;
  }

  /// Set the current user's check-in for [date] to [completed].
  ///
  /// Preferred over [toggleCheckIn]: it sends an explicit target value, so a
  /// double tap converges instead of silently undoing the check-in, and two
  /// devices acting at once agree rather than flip-flopping.
  ///
  /// [groupId] is the goal's group — after a successful POST this awaits that
  /// group's progress refresh (both the cross-group and single-group caches)
  /// before returning, so `pending` never clears until the data driving
  /// `isCompleted` elsewhere in the UI is actually fresh. Doing this here,
  /// once, means every call site gets it for free instead of each one having
  /// to remember to refresh — and previously one of them didn't.
  ///
  /// Returns false when the request was skipped (already in flight) or failed.
  Future<bool> setCheckIn(
    String goalId,
    String groupId,
    DateTime date,
    bool completed,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) return false;

    final pending = ref.read(pendingCheckInProvider.notifier);
    final key = pendingCheckInKey(goalId, date);
    // Duplicate guard: a second tap while the first is in flight is a no-op.
    if (!pending.begin(key)) return false;

    final currentState = state.value ?? {};
    final checkIns = List<dynamic>.from(currentState[goalId] ?? []);

    final existingIndex = checkIns.indexWhere((c) {
      if (c['userId'] != userId) return false;
      final checkInDate = DateTime.parse(c['date']).toLocal();
      return checkInDate.year == date.year &&
          checkInDate.month == date.month &&
          checkInDate.day == date.day;
    });

    // Optimistic update — to the explicit target, not a flip.
    if (existingIndex >= 0) {
      checkIns[existingIndex] = {...checkIns[existingIndex], 'completed': completed};
    } else {
      checkIns.add({
        '_id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
        'userId': userId,
        'goalId': goalId,
        'date': DateTime.utc(date.year, date.month, date.day).toIso8601String(),
        'completed': completed,
      });
    }

    currentState[goalId] = checkIns;
    state = AsyncData({...currentState});

    try {
      // Send UTC midnight to avoid date shifting across timezones.
      final response = await ApiClient.instance.post(
        '/goals/$goalId/checkin',
        data: {
          'date': DateTime.utc(date.year, date.month, date.day).toIso8601String(),
          'completed': completed,
        },
      );

      // Swap the optimistic row for the server's, so we hold the real _id.
      final realCheckIn = response.data['checkIn'];
      final newCheckIns = List<dynamic>.from(currentState[goalId] ?? []);
      final replaceIndex = newCheckIns.indexWhere((c) {
        if (c['userId'] != userId) return false;
        final d = DateTime.parse(c['date']).toLocal();
        return d.year == date.year && d.month == date.month && d.day == date.day;
      });
      if (replaceIndex >= 0) {
        newCheckIns[replaceIndex] = realCheckIn;
      }

      currentState[goalId] = newCheckIns;
      state = AsyncData({...currentState});

      // The check-in endpoint computes and returns this group's updated
      // progress in the same response, so both caches (Home/Today's Rituals
      // via myProgressProvider, Group Detail via groupProgressProvider) can
      // be updated directly — no second request needed. That follow-up GET
      // was the actual cost behind the visible delay after a tap; this way
      // the spinner only ever covers one round trip, not two.
      final progress = GroupProgress.fromJson(
        response.data['progress'] as Map<String, dynamic>,
      );
      ref.read(myProgressProvider.notifier).applyGroupProgress(progress);
      ref.read(groupProgressProvider(groupId).notifier).applyProgress(progress);
      return true;
    } catch (e) {
      // Revert to server truth.
      await fetchCheckIns(goalId);
      return false;
    } finally {
      pending.end(key);
    }
  }
}
