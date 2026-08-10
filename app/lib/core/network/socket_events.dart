/// Socket.IO event names, emitted by backend/src.
///
/// Group-room events go to everyone viewing that group; personal-room events go
/// to `user_<userId>` and reach a member wherever they are in the app.
class SocketEvents {
  SocketEvents._();

  /// Group room. Payload: goalId (String).
  /// Personal room. Payload: { goalId, groupId }.
  static const String checkinUpdated = 'checkin_updated';

  /// Group room. No payload.
  static const String goalUpdated = 'goal_updated';

  /// Group room. Payload: the populated message.
  static const String newMessage = 'new_message';

  /// Personal room. No payload.
  static const String groupUpdated = 'group_updated';

  /// Personal room. Payload: { groupId, groupName }.
  static const String newGroupMessage = 'new_group_message';
}

/// Pulls the groupId out of a `checkin_updated` payload.
///
/// The group room sends a bare goalId string and the personal room sends a map,
/// so callers that want to refresh a single group have to tell them apart.
String? groupIdFromCheckinPayload(dynamic payload) {
  if (payload is Map && payload['groupId'] != null) {
    return payload['groupId'].toString();
  }
  return null;
}

/// Pulls the goalId out of either `checkin_updated` payload shape.
String? goalIdFromCheckinPayload(dynamic payload) {
  if (payload is String && payload.isNotEmpty) return payload;
  if (payload is Map && payload['goalId'] != null) {
    return payload['goalId'].toString();
  }
  return null;
}
