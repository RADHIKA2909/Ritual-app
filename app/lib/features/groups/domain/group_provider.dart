import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

final groupProvider = AsyncNotifierProvider<GroupNotifier, List<dynamic>>(() {
  return GroupNotifier();
});

class GroupNotifier extends AsyncNotifier<List<dynamic>> {
  @override
  FutureOr<List<dynamic>> build() async {
    final response = await ApiClient.instance.get('/groups');
    return response.data as List<dynamic>;
  }

  Future<void> refreshGroupsSilently() async {
    try {
      final response = await ApiClient.instance.get('/groups');
      state = AsyncData(response.data as List<dynamic>);
    } catch (_) {}
  }

  Future<void> createGroup(String name) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final response = await ApiClient.instance.post('/groups', data: {'name': name});
      final currentGroups = state.value ?? [];
      return [...currentGroups, response.data];
    });
  }

  /// Returns the group ID after joining (or the existing group ID if already a member).
  Future<String> joinGroup(String inviteCode) async {
    final response = await ApiClient.instance.post('/groups/join', data: {'inviteCode': inviteCode});
    final groupData = response.data as Map<String, dynamic>;
    final alreadyMember = groupData['alreadyMember'] == true;

    final currentGroups = List<dynamic>.from(state.value ?? []);

    if (!alreadyMember) {
      // Only add to list if genuinely new
      state = AsyncData([...currentGroups, groupData]);
    }

    return groupData['_id'] as String;
  }

  Future<void> deleteGroup(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ApiClient.instance.delete('/groups/$id');
      final currentGroups = state.value ?? [];
      return currentGroups.where((g) => g['_id'] != id).toList();
    });
  }

  Future<void> removeMember(String groupId, String memberId) async {
    // We don't necessarily need to update the group list state here unless 
    // we want to proactively modify the group's member list in the state.
    // However, the member list is usually fetched inside GroupDetailScreen.
    await ApiClient.instance.delete('/groups/$groupId/members/$memberId');
  }
}
