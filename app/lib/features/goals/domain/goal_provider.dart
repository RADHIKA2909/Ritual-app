import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../groups/domain/group_provider.dart';
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

  Future<void> toggleCheckIn(String goalId, DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) return;

    final currentState = state.value ?? {};
    final checkIns = List<dynamic>.from(currentState[goalId] ?? []);
    
    // Find if a check-in already exists for this date
    int existingIndex = checkIns.indexWhere((c) {
      if (c['userId'] != userId) return false;
      final checkInDate = DateTime.parse(c['date']).toLocal();
      return checkInDate.year == date.year &&
             checkInDate.month == date.month &&
             checkInDate.day == date.day;
    });

    // Optimistic Update
    if (existingIndex >= 0) {
      checkIns[existingIndex] = {
        ...checkIns[existingIndex],
        'completed': !checkIns[existingIndex]['completed'],
      };
    } else {
      checkIns.add({
        '_id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
        'userId': userId,
        'goalId': goalId,
        'date': date.toIso8601String(), // Mock local date
        'completed': true,
      });
    }

    currentState[goalId] = checkIns;
    state = AsyncData({...currentState});

    try {
      // Fire API call in background
      final response = await ApiClient.instance.post('/goals/$goalId/checkin', data: {
        'date': date.toIso8601String(),
      });
      
      // Replace with real data from server (to get real _id)
      final realCheckIn = response.data;
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
    } catch (e) {
      // Revert if failed
      await fetchCheckIns(goalId);
    }
  }
}
