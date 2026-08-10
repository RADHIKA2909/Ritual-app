// ─────────────────────────────────────────────────────────────────────────────
// Group progress view model.
//
// These mirror the payload built by backend/src/services/progressService.ts.
// All of the group maths — weekly buckets, the weakest-link group score, the
// streak, per-goal status and group health — is derived on the server. Nothing
// here recomputes any of it; this layer only parses and renders.
//
// Hand-written on purpose: the rest of the app passes raw Map<String, dynamic>
// around, and adding a codegen toolchain (freezed / json_serializable) for one
// payload isn't worth the dependency. Everything else stays raw.
// ─────────────────────────────────────────────────────────────────────────────

/// How a goal is tracking against its weekly minimum, for the group as a whole.
enum GoalStatus {
  /// The group has met the weekly minimum.
  completed,

  /// Progress made and enough days left to finish comfortably.
  onTrack,

  /// No slack left — every remaining day must count, or it's already missed.
  atRisk,

  /// Nothing logged yet this week, but there's still room.
  incomplete;

  static GoalStatus fromWire(String? value) {
    switch (value) {
      case 'completed':
        return GoalStatus.completed;
      case 'on_track':
        return GoalStatus.onTrack;
      case 'at_risk':
        return GoalStatus.atRisk;
      case 'incomplete':
        return GoalStatus.incomplete;
      default:
        // Unknown values from a newer backend degrade to the mildest state
        // rather than throwing.
        return GoalStatus.incomplete;
    }
  }
}

/// Whether the group's shared streak is safe, building, or needs attention.
enum StreakStatus {
  none,
  building,
  safe,
  atRisk;

  static StreakStatus fromWire(String? value) {
    switch (value) {
      case 'building':
        return StreakStatus.building;
      case 'safe':
        return StreakStatus.safe;
      case 'at_risk':
        return StreakStatus.atRisk;
      case 'none':
      default:
        return StreakStatus.none;
    }
  }
}

enum HealthLabel {
  strong,
  needsAttention,
  atRisk;

  static HealthLabel fromWire(String? value) {
    switch (value) {
      case 'strong':
        return HealthLabel.strong;
      case 'at_risk':
        return HealthLabel.atRisk;
      case 'needs_attention':
      default:
        return HealthLabel.needsAttention;
    }
  }
}

int _asInt(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

double _asDouble(dynamic v, [double fallback = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

class GroupHealth {
  final int score;
  final HealthLabel label;

  /// Machine-readable key (`everyone_active`, `someone_behind`,
  /// `no_checkins_this_week`, `new_group`). Human copy lives in StatusStyle.
  final String reason;

  const GroupHealth({
    required this.score,
    required this.label,
    required this.reason,
  });

  factory GroupHealth.fromJson(Map<String, dynamic> json) => GroupHealth(
        score: _asInt(json['score']),
        label: HealthLabel.fromWire(json['label'] as String?),
        reason: (json['reason'] as String?) ?? '',
      );
}

/// One member's contribution to a single goal this week.
class MemberGoalProgress {
  final String userId;
  final String name;
  final String? profileImage;
  final int completedCount;
  final int target;
  final bool completedToday;
  final bool isCurrentUser;

  const MemberGoalProgress({
    required this.userId,
    required this.name,
    required this.profileImage,
    required this.completedCount,
    required this.target,
    required this.completedToday,
    required this.isCurrentUser,
  });

  factory MemberGoalProgress.fromJson(Map<String, dynamic> json) => MemberGoalProgress(
        userId: (json['userId'] ?? '').toString(),
        name: (json['name'] as String?) ?? 'Member',
        profileImage: json['profileImage'] as String?,
        completedCount: _asInt(json['completedCount']),
        target: _asInt(json['target']),
        completedToday: json['completedToday'] == true,
        isCurrentUser: json['isCurrentUser'] == true,
      );

  bool get hasMetTarget => target > 0 && completedCount >= target;
}

/// A group goal, with the group's shared progress and each member's share.
class GroupGoalProgress {
  final String goalId;
  final String goalName;
  final String icon;
  final int weeklyMinimum;

  /// The group's score: the MINIMUM completed count across all members.
  final int groupCompletedCount;
  final int groupTarget;
  final double groupProgress;
  final GoalStatus status;
  final int goalStreak;

  final int currentUserCount;
  final bool currentUserCompletedToday;

  /// Today's check-in id for the current user, when one exists — lets notes and
  /// reactions attach without another round trip.
  final String? currentUserCheckInId;

  final List<String> membersPendingToday;
  final List<MemberGoalProgress> memberProgress;

  const GroupGoalProgress({
    required this.goalId,
    required this.goalName,
    required this.icon,
    required this.weeklyMinimum,
    required this.groupCompletedCount,
    required this.groupTarget,
    required this.groupProgress,
    required this.status,
    required this.goalStreak,
    required this.currentUserCount,
    required this.currentUserCompletedToday,
    required this.currentUserCheckInId,
    required this.membersPendingToday,
    required this.memberProgress,
  });

  factory GroupGoalProgress.fromJson(Map<String, dynamic> json) => GroupGoalProgress(
        goalId: (json['goalId'] ?? '').toString(),
        goalName: (json['goalName'] as String?) ?? 'Ritual',
        icon: (json['icon'] as String?) ?? '🎯',
        weeklyMinimum: _asInt(json['weeklyMinimum']),
        groupCompletedCount: _asInt(json['groupCompletedCount']),
        groupTarget: _asInt(json['groupTarget']),
        groupProgress: _asDouble(json['groupProgress']).clamp(0.0, 1.0),
        status: GoalStatus.fromWire(json['status'] as String?),
        goalStreak: _asInt(json['goalStreak']),
        currentUserCount: _asInt(json['currentUserCount']),
        currentUserCompletedToday: json['currentUserCompletedToday'] == true,
        currentUserCheckInId: json['currentUserCheckInId'] as String?,
        membersPendingToday: ((json['membersPendingToday'] as List<dynamic>?) ?? [])
            .map((e) => e.toString())
            .toList(),
        memberProgress: ((json['memberProgress'] as List<dynamic>?) ?? [])
            .map((e) => MemberGoalProgress.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// How many more group check-ins are needed to meet the weekly minimum.
  int get remaining =>
      (groupTarget - groupCompletedCount).clamp(0, groupTarget == 0 ? 0 : groupTarget);

  /// Members other than the current user who haven't checked in today.
  List<MemberGoalProgress> get othersPendingToday => memberProgress
      .where((m) => !m.isCurrentUser && !m.completedToday)
      .toList(growable: false);

  /// The current user has done their part today but someone else hasn't —
  /// the moment where a nudge is the useful action.
  bool get waitingOnOthersToday =>
      currentUserCompletedToday &&
      status != GoalStatus.completed &&
      othersPendingToday.isNotEmpty;
}

/// A member's standing across the whole group.
class GroupMemberProgress {
  final String userId;
  final String name;
  final String? profileImage;
  final bool isAdmin;
  final bool isCurrentUser;
  final bool completedToday;
  final int weeklyCompleted;

  const GroupMemberProgress({
    required this.userId,
    required this.name,
    required this.profileImage,
    required this.isAdmin,
    required this.isCurrentUser,
    required this.completedToday,
    required this.weeklyCompleted,
  });

  factory GroupMemberProgress.fromJson(Map<String, dynamic> json) => GroupMemberProgress(
        userId: (json['userId'] ?? '').toString(),
        name: (json['name'] as String?) ?? 'Member',
        profileImage: json['profileImage'] as String?,
        isAdmin: json['isAdmin'] == true,
        isCurrentUser: json['isCurrentUser'] == true,
        completedToday: json['completedToday'] == true,
        weeklyCompleted: _asInt(json['weeklyCompleted']),
      );

  String get firstName => name.split(' ').first;

  /// What to call this person in copy addressed to the current user.
  String get displayName => isCurrentUser ? 'You' : firstName;
}

class TodaySummary {
  final int membersDoneToday;
  final int goalsNeedingEveryoneToday;
  final int goalsWaitingOnMeToday;

  const TodaySummary({
    required this.membersDoneToday,
    required this.goalsNeedingEveryoneToday,
    required this.goalsWaitingOnMeToday,
  });

  factory TodaySummary.fromJson(Map<String, dynamic> json) => TodaySummary(
        membersDoneToday: _asInt(json['membersDoneToday']),
        goalsNeedingEveryoneToday: _asInt(json['goalsNeedingEveryoneToday']),
        goalsWaitingOnMeToday: _asInt(json['goalsWaitingOnMeToday']),
      );
}

class GroupProgress {
  final String groupId;
  final String groupName;
  final String adminId;
  final bool isAdmin;

  /// Only present for the admin.
  final String? inviteCode;

  final int memberCount;
  final String weekStart;
  final int daysElapsedInWeek;
  final int daysLeftInWeek;
  final int groupStreak;
  final StreakStatus streakStatus;
  final GroupHealth? health;
  final TodaySummary todaySummary;
  final List<GroupMemberProgress> members;
  final List<GroupGoalProgress> goals;

  const GroupProgress({
    required this.groupId,
    required this.groupName,
    required this.adminId,
    required this.isAdmin,
    required this.inviteCode,
    required this.memberCount,
    required this.weekStart,
    required this.daysElapsedInWeek,
    required this.daysLeftInWeek,
    required this.groupStreak,
    required this.streakStatus,
    required this.health,
    required this.todaySummary,
    required this.members,
    required this.goals,
  });

  factory GroupProgress.fromJson(Map<String, dynamic> json) => GroupProgress(
        groupId: (json['groupId'] ?? '').toString(),
        groupName: (json['groupName'] as String?) ?? 'Group',
        adminId: (json['adminId'] ?? '').toString(),
        isAdmin: json['isAdmin'] == true,
        inviteCode: json['inviteCode'] as String?,
        memberCount: _asInt(json['memberCount']),
        weekStart: (json['weekStart'] as String?) ?? '',
        daysElapsedInWeek: _asInt(json['daysElapsedInWeek'], 1),
        daysLeftInWeek: _asInt(json['daysLeftInWeek'], 1),
        groupStreak: _asInt(json['groupStreak']),
        streakStatus: StreakStatus.fromWire(json['streakStatus'] as String?),
        health: json['health'] == null
            ? null
            : GroupHealth.fromJson(json['health'] as Map<String, dynamic>),
        todaySummary: TodaySummary.fromJson(
            (json['todaySummary'] as Map<String, dynamic>?) ?? const {}),
        members: ((json['members'] as List<dynamic>?) ?? [])
            .map((e) => GroupMemberProgress.fromJson(e as Map<String, dynamic>))
            .toList(),
        goals: ((json['goals'] as List<dynamic>?) ?? [])
            .map((e) => GroupGoalProgress.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  static List<GroupProgress> listFromResponse(dynamic data) {
    if (data is Map<String, dynamic>) {
      final groups = data['groups'];
      if (groups is List) {
        return groups
            .map((e) => GroupProgress.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    if (data is List) {
      return data.map((e) => GroupProgress.fromJson(e as Map<String, dynamic>)).toList();
    }
    return const [];
  }

  bool get isSolo => memberCount <= 1;

  /// Goals the current user still has to do today.
  List<GroupGoalProgress> get goalsPendingForMeToday =>
      goals.where((g) => !g.currentUserCompletedToday).toList(growable: false);

  List<GroupGoalProgress> get goalsDoneByMeToday =>
      goals.where((g) => g.currentUserCompletedToday).toList(growable: false);

  int get goalsCompletedThisWeek =>
      goals.where((g) => g.status == GoalStatus.completed).length;

  GroupMemberProgress? get currentUser {
    for (final m in members) {
      if (m.isCurrentUser) return m;
    }
    return null;
  }

  List<GroupMemberProgress> get otherMembers =>
      members.where((m) => !m.isCurrentUser).toList(growable: false);
}
