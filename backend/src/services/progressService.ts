import { Types } from 'mongoose';
import { Goal, IGoal } from '../models/Goal';
import { IGroup } from '../models/Group';
import { CheckIn } from '../models/CheckIn';
import { User } from '../models/User';

// ─────────────────────────────────────────────────────────────────────────────
// Group progress service
//
// This module owns ALL group progress maths — weekly bucketing, the group
// streak, per-goal status, and group health. Nothing else (and in particular
// nothing in the Flutter client) should recompute any of it.
//
// The streak algorithm below was moved here verbatim from
// goalController.getGroupStreak. Its semantics are deliberately unchanged:
//
//   1. Check-ins are bucketed into Monday-starting weeks.
//   2. For each goal and week, every member's completed check-ins are counted
//      and the group's score is the MINIMUM across all current members — the
//      group only moves at the pace of its least active member.
//   3. A goal passes that week if its group score >= goal.weeklyMinimum.
//   4. A goal's streak is the number of consecutive passing weeks counting
//      back from the current week (capped at 520 weeks / ~10 years).
//   5. The group's streak is the MINIMUM streak across all of its goals.
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Minimal structural shapes so the helpers below accept both hydrated Mongoose
 * documents and `.lean()` results without casting at every call site.
 */
interface TickSource {
  date: Date;
  goalId: Types.ObjectId | string;
  userId: Types.ObjectId | string;
}

interface MemberSource {
  members: (Types.ObjectId | string)[];
}

/**
 * Start of the Monday-anchored week containing `d`, as a `YYYY-MM-DD` string.
 *
 * Works entirely in UTC, matching how check-in dates are stored (the client
 * sends `DateTime.utc(y, m, d)`, i.e. UTC midnight).
 *
 * This is a deliberate, behaviour-preserving change from the original, which
 * mixed local-time getters (getDay/getDate/setDate) with a UTC serialisation
 * (toISOString). Under `TZ=UTC` — which is what the Fly.io `node:18-alpine`
 * image runs — the two are provably identical, because getDay()===getUTCDay(),
 * getDate()===getUTCDate() and setDate()===setUTCDate(). So production week
 * boundaries and every historical streak are unchanged.
 *
 * On a machine with a non-UTC timezone the old version disagreed with itself:
 * `getWeekStart(new Date())` could land in a different week from
 * `getWeekStart(<a stored check-in date>)`, so the current week's lookups
 * silently missed and every goal read as 0. That's why this is now UTC-only.
 *
 * Do NOT reintroduce local-time getters, and do not set a TZ env var.
 */
export const getWeekStart = (d: Date): string => {
  const date = new Date(d);
  const day = date.getUTCDay();
  const diff = date.getUTCDate() - day + (day === 0 ? -6 : 1); // adjust when day is sunday
  return new Date(date.setUTCDate(diff)).toISOString().split('T')[0];
};

/** goalId -> weekStart -> userId -> completed check-in count */
export const buildGoalWeekUserTicks = (
  checkIns: TickSource[]
): Map<string, Map<string, Map<string, number>>> => {
  const goalWeekUserTicks = new Map<string, Map<string, Map<string, number>>>();

  for (const c of checkIns) {
    const d = new Date(c.date);
    const weekStart = getWeekStart(d);
    const goalId = c.goalId.toString();
    const userId = c.userId.toString();

    if (!goalWeekUserTicks.has(goalId)) goalWeekUserTicks.set(goalId, new Map());
    const weekMap = goalWeekUserTicks.get(goalId)!;

    if (!weekMap.has(weekStart)) weekMap.set(weekStart, new Map());
    const userMap = weekMap.get(weekStart)!;

    userMap.set(userId, (userMap.get(userId) || 0) + 1);
  }

  return goalWeekUserTicks;
};

/**
 * Collapse per-user ticks into the group's score for each goal/week: the
 * MINIMUM across all current members (the "weakest link" rule).
 */
export const buildWeeklyGoalTicks = (
  goalWeekUserTicks: Map<string, Map<string, Map<string, number>>>,
  group: MemberSource | null
): Map<string, Map<string, number>> => {
  const weeklyGoalTicks = new Map<string, Map<string, number>>();

  for (const [goalId, weekMap] of goalWeekUserTicks.entries()) {
    weeklyGoalTicks.set(goalId, new Map());
    for (const [weekStart, userMap] of weekMap.entries()) {
      let groupTicks = 0;
      if (group && group.members.length > 0) {
        let minTicks = Infinity;
        for (const memberId of group.members) {
          const ticks = userMap.get(memberId.toString()) || 0;
          if (ticks < minTicks) minTicks = ticks;
        }
        groupTicks = minTicks === Infinity ? 0 : minTicks;
      } else {
        let minTicks = Infinity;
        for (const ticks of userMap.values()) {
          if (ticks < minTicks) minTicks = ticks;
        }
        groupTicks = minTicks === Infinity ? 0 : minTicks;
      }
      weeklyGoalTicks.get(goalId)!.set(weekStart, groupTicks);
    }
  }

  return weeklyGoalTicks;
};

/**
 * Consecutive passing weeks for a single goal, counting back from the week
 * containing `today`.
 */
export const computeGoalStreak = (
  goalWeeks: Map<string, number>,
  target: number,
  today: Date
): number => {
  const currentWeekStart = getWeekStart(today);
  let streak = 0;

  // Check current week
  if ((goalWeeks.get(currentWeekStart) || 0) >= target) {
    streak++;
  }

  // Check previous weeks
  for (let i = 1; i < 520; i++) {
    const pastWeek = new Date(today);
    pastWeek.setUTCDate(today.getUTCDate() - i * 7);
    const pastWeekStart = getWeekStart(pastWeek);

    if ((goalWeeks.get(pastWeekStart) || 0) >= target) {
      streak++;
    } else {
      break;
    }
  }

  return streak;
};

/** The group streak: the minimum streak across all goals. 0 when no goals. */
export const computeGroupStreak = (
  goals: { _id: unknown; weeklyMinimum: number }[],
  weeklyGoalTicks: Map<string, Map<string, number>>,
  today: Date
): number => {
  let minStreak: number | null = null;

  for (const goal of goals) {
    const goalWeeks = weeklyGoalTicks.get(String(goal._id)) || new Map<string, number>();
    const target = goal.weeklyMinimum || 0;
    const streak = computeGoalStreak(goalWeeks, target, today);

    if (minStreak === null || streak < minStreak) {
      minStreak = streak;
    }
  }

  return minStreak || 0;
};

// ─────────────────────────────────────────────────────────────────────────────
// View model
// ─────────────────────────────────────────────────────────────────────────────

export type GoalStatus =
  | 'completed'
  | 'on_track'
  | 'needs_attention'
  | 'at_risk'
  | 'incomplete';
export type StreakStatus = 'none' | 'building' | 'safe' | 'at_risk';
export type HealthLabel = 'strong' | 'needs_attention' | 'at_risk';

export interface MemberGoalProgressDTO {
  userId: string;
  name: string;
  profileImage?: string | null;
  completedCount: number;
  target: number;
  completedToday: boolean;
  isCurrentUser: boolean;
}

export interface GroupGoalProgressDTO {
  goalId: string;
  goalName: string;
  icon: string;
  weeklyMinimum: number;
  groupCompletedCount: number;
  groupTarget: number;
  groupProgress: number;
  status: GoalStatus;
  /** The weekly minimum can no longer be reached, even with a perfect finish. */
  unreachableThisWeek: boolean;
  goalStreak: number;
  currentUserCount: number;
  currentUserCompletedToday: boolean;
  currentUserCheckInId: string | null;
  membersPendingToday: string[];
  memberProgress: MemberGoalProgressDTO[];
}

export interface GroupMemberDTO {
  userId: string;
  name: string;
  profileImage?: string | null;
  isAdmin: boolean;
  isCurrentUser: boolean;
  completedToday: boolean;
  weeklyCompleted: number;
}

export interface GroupHealthDTO {
  score: number;
  label: HealthLabel;
  reason: string;
}

export interface GroupProgressDTO {
  groupId: string;
  groupName: string;
  adminId: string;
  isAdmin: boolean;
  inviteCode?: string;
  memberCount: number;
  weekStart: string;
  daysElapsedInWeek: number;
  daysLeftInWeek: number;
  groupStreak: number;
  streakStatus: StreakStatus;
  health: GroupHealthDTO | null;
  todaySummary: {
    membersDoneToday: number;
    /** Goals where at least one member still has to check in today. */
    goalsWaitingOnAnyoneToday: number;
    /** Goals where I've checked in today but someone else hasn't. */
    goalsWaitingOnOthersOnlyToday: number;
    /** Goals not yet weekly-complete where I haven't checked in today. */
    goalsWaitingOnMeToday: number;
    /**
     * @deprecated Misnamed — it always counted "anyone pending", not
     * "everyone pending", which made the UI say "needs both of you" when only
     * one member was outstanding. Use goalsWaitingOnAnyoneToday. Kept for one
     * release so an older client doesn't break.
     */
    goalsNeedingEveryoneToday: number;
  };
  members: GroupMemberDTO[];
  goals: GroupGoalProgressDTO[];
}

/** Mon = 1 … Sun = 7, in UTC to match getWeekStart. */
const dayOfWeekIndex = (d: Date): number => {
  const day = d.getUTCDay();
  return day === 0 ? 7 : day;
};

const dateKey = (d: Date): string => new Date(d).toISOString().split('T')[0];

/**
 * How a goal is tracking, judged against BOTH feasibility and pace.
 *
 * The earlier version took only `daysLeftInWeek` and so was a pure feasibility
 * test — it reported "on track" for 1 of 3 on a Friday, because finishing was
 * still arithmetically possible. It also had no tier for "behind, but still
 * doable", which is the single most common mid-week state.
 *
 *   expectedByNow  = floor(weeklyMinimum * daysElapsed / 7)
 *   daysRemaining  = 7 - daysElapsed          (days AFTER today)
 *
 * `floor` keeps early week forgiving — on Monday a 3x/week goal expects 0, so
 * a group that hasn't started yet is "not started", not "behind". By Sunday it
 * expects the full minimum. (deriveHealth deliberately keeps `ceil`; it is a
 * separate, softer signal and moving it would shift health scores.)
 */
export const deriveGoalStatus = (
  groupCompletedCount: number,
  weeklyMinimum: number,
  daysElapsedInWeek: number
): GoalStatus => {
  if (weeklyMinimum <= 0) return 'completed';
  if (groupCompletedCount >= weeklyMinimum) return 'completed';

  const remaining = weeklyMinimum - groupCompletedCount;
  const daysRemaining = Math.max(0, 7 - daysElapsedInWeek);

  // Needs today AND every day after it — or is already unreachable. Both
  // genuinely threaten the streak, which is what "at risk" is for.
  if (remaining > daysRemaining) return 'at_risk';

  const expectedByNow = Math.floor((weeklyMinimum * daysElapsedInWeek) / 7);
  if (groupCompletedCount < expectedByNow) return 'needs_attention';

  if (groupCompletedCount === 0) return 'incomplete';
  return 'on_track';
};

/** True when the weekly minimum is arithmetically unreachable. */
export const isGoalUnreachable = (
  groupCompletedCount: number,
  weeklyMinimum: number,
  daysElapsedInWeek: number
): boolean => {
  const remaining = weeklyMinimum - groupCompletedCount;
  if (remaining <= 0) return false;
  // At most one check-in per day, and today is still available.
  const daysUsable = Math.max(0, 7 - daysElapsedInWeek) + 1;
  return remaining > daysUsable;
};

const deriveStreakStatus = (
  groupStreak: number,
  goals: GroupGoalProgressDTO[],
  hasHistory: boolean
): StreakStatus => {
  if (goals.length === 0) return 'none';
  if (goals.every((g) => g.status === 'completed')) return 'safe';
  if (groupStreak >= 1 && goals.some((g) => g.status === 'at_risk')) return 'at_risk';
  if (groupStreak >= 1) return 'safe';
  return hasHistory ? 'building' : 'none';
};

/**
 * Group health — a softer, pace-aware companion to the (deliberately strict,
 * binary) streak. A group can have a broken streak and still be healthy.
 *
 * Prorated by how much of the week has elapsed so a group is never told it is
 * "at risk" on a Monday morning simply because the week just started.
 */
const deriveHealth = (
  goals: GroupGoalProgressDTO[],
  lastWeekTicksByGoal: Map<string, number>,
  daysElapsedInWeek: number,
  membersActiveThisWeek: number,
  memberCount: number,
  hasHistoryBeforeThisWeek: boolean
): GroupHealthDTO | null => {
  if (goals.length === 0) return null;

  const paces = goals.map((g) => {
    const expectedSoFar = Math.ceil((g.weeklyMinimum * daysElapsedInWeek) / 7);
    if (expectedSoFar === 0) return 1;
    return Math.min(1, g.groupCompletedCount / expectedSoFar);
  });
  const currentTerm = paces.reduce((a, b) => a + b, 0) / paces.length;

  const partTerm = memberCount > 0 ? membersActiveThisWeek / memberCount : 0;

  let score: number;
  if (hasHistoryBeforeThisWeek) {
    const lastWeekRatios = goals.map((g) => {
      const ticks = lastWeekTicksByGoal.get(g.goalId) || 0;
      return g.weeklyMinimum === 0 ? 1 : Math.min(1, ticks / g.weeklyMinimum);
    });
    const lastWeekTerm =
      lastWeekRatios.reduce((a, b) => a + b, 0) / lastWeekRatios.length;
    score = Math.round(100 * (0.5 * currentTerm + 0.3 * lastWeekTerm + 0.2 * partTerm));
  } else {
    // Brand-new group: drop the history term and renormalise, so a group that
    // just started never opens on "At risk".
    score = Math.round(100 * ((0.5 * currentTerm + 0.2 * partTerm) / 0.7));
  }

  score = Math.max(0, Math.min(100, score));

  let label: HealthLabel;
  if (score >= 80) label = 'strong';
  else if (score >= 50) label = 'needs_attention';
  else label = 'at_risk';

  // Machine-readable only — all human copy lives in the Flutter StatusStyle
  // file so tone can be reviewed in one place.
  let reason: string;
  if (!hasHistoryBeforeThisWeek) reason = 'new_group';
  else if (membersActiveThisWeek === 0) reason = 'no_checkins_this_week';
  else if (membersActiveThisWeek < memberCount) reason = 'someone_behind';
  else reason = 'everyone_active';

  return { score, label, reason };
};

/**
 * Pure assembly — no I/O. Given a group and its already-fetched goals,
 * completed check-ins and member profiles, produce the full view model.
 */
export const assembleGroupProgress = (
  group: IGroup,
  goals: IGoal[],
  checkIns: TickSource[],
  userNames: Map<string, { name: string; profileImage?: string | null }>,
  currentUserId: string,
  checkInIdsByGoalUserDate?: Map<string, string>
): GroupProgressDTO => {
  const today = new Date();
  const currentWeekStart = getWeekStart(today);
  const todayKey = dateKey(today);
  const daysElapsedInWeek = dayOfWeekIndex(today);
  const daysLeftInWeek = 7 - daysElapsedInWeek + 1; // includes today

  const lastWeek = new Date(today);
  lastWeek.setUTCDate(today.getUTCDate() - 7);
  const lastWeekStart = getWeekStart(lastWeek);

  const goalWeekUserTicks = buildGoalWeekUserTicks(checkIns);
  const weeklyGoalTicks = buildWeeklyGoalTicks(goalWeekUserTicks, group);

  const memberIds = group.members.map((m) => m.toString());
  const adminId = group.adminId.toString();

  // Today's completed check-ins, keyed goalId -> Set<userId>.
  const doneTodayByGoal = new Map<string, Set<string>>();
  for (const c of checkIns) {
    if (dateKey(c.date) !== todayKey) continue;
    const gId = c.goalId.toString();
    if (!doneTodayByGoal.has(gId)) doneTodayByGoal.set(gId, new Set());
    doneTodayByGoal.get(gId)!.add(c.userId.toString());
  }

  const lastWeekTicksByGoal = new Map<string, number>();
  const goalDtos: GroupGoalProgressDTO[] = goals.map((goal) => {
    const goalId = String(goal._id);
    const weekMap = weeklyGoalTicks.get(goalId) || new Map<string, number>();
    const userTicksThisWeek =
      goalWeekUserTicks.get(goalId)?.get(currentWeekStart) || new Map<string, number>();

    lastWeekTicksByGoal.set(goalId, weekMap.get(lastWeekStart) || 0);

    const groupCompletedCount = weekMap.get(currentWeekStart) || 0;
    const weeklyMinimum = goal.weeklyMinimum || 0;
    const doneToday = doneTodayByGoal.get(goalId) || new Set<string>();

    const memberProgress: MemberGoalProgressDTO[] = memberIds.map((id) => {
      const profile = userNames.get(id);
      return {
        userId: id,
        name: profile?.name ?? 'Member',
        profileImage: profile?.profileImage ?? null,
        completedCount: userTicksThisWeek.get(id) || 0,
        target: weeklyMinimum,
        completedToday: doneToday.has(id),
        isCurrentUser: id === currentUserId,
      };
    });

    return {
      goalId,
      goalName: goal.name,
      icon: goal.icon,
      weeklyMinimum,
      groupCompletedCount,
      groupTarget: weeklyMinimum,
      groupProgress:
        weeklyMinimum === 0 ? 1 : Math.min(1, groupCompletedCount / weeklyMinimum),
      status: deriveGoalStatus(groupCompletedCount, weeklyMinimum, daysElapsedInWeek),
      unreachableThisWeek: isGoalUnreachable(
        groupCompletedCount,
        weeklyMinimum,
        daysElapsedInWeek
      ),
      goalStreak: computeGoalStreak(weekMap, weeklyMinimum, today),
      currentUserCount: userTicksThisWeek.get(currentUserId) || 0,
      currentUserCompletedToday: doneToday.has(currentUserId),
      currentUserCheckInId:
        checkInIdsByGoalUserDate?.get(`${goalId}|${currentUserId}|${todayKey}`) ?? null,
      membersPendingToday: memberIds.filter((id) => !doneToday.has(id)),
      memberProgress,
    };
  });

  // Per-member rollups across the whole group.
  const weeklyCompletedByUser = new Map<string, number>();
  const activeThisWeek = new Set<string>();
  const doneTodayAnyGoal = new Set<string>();
  for (const c of checkIns) {
    const uId = c.userId.toString();
    if (getWeekStart(new Date(c.date)) === currentWeekStart) {
      weeklyCompletedByUser.set(uId, (weeklyCompletedByUser.get(uId) || 0) + 1);
      activeThisWeek.add(uId);
    }
    if (dateKey(c.date) === todayKey) doneTodayAnyGoal.add(uId);
  }

  const members: GroupMemberDTO[] = memberIds.map((id) => {
    const profile = userNames.get(id);
    return {
      userId: id,
      name: profile?.name ?? 'Member',
      profileImage: profile?.profileImage ?? null,
      isAdmin: id === adminId,
      isCurrentUser: id === currentUserId,
      completedToday: doneTodayAnyGoal.has(id),
      weeklyCompleted: weeklyCompletedByUser.get(id) || 0,
    };
  });

  const groupStreak = computeGroupStreak(
    goals.map((g) => ({ _id: g._id, weeklyMinimum: g.weeklyMinimum || 0 })),
    weeklyGoalTicks,
    today
  );

  const hasHistoryBeforeThisWeek = checkIns.some(
    (c) => getWeekStart(new Date(c.date)) < currentWeekStart
  );

  const waitingOnAnyone = goalDtos.filter(
    (g) => g.status !== 'completed' && g.membersPendingToday.length > 0
  ).length;

  const isAdmin = adminId === currentUserId;

  const dto: GroupProgressDTO = {
    groupId: String(group._id),
    groupName: group.name,
    adminId,
    isAdmin,
    memberCount: memberIds.length,
    weekStart: currentWeekStart,
    daysElapsedInWeek,
    daysLeftInWeek,
    groupStreak,
    streakStatus: deriveStreakStatus(groupStreak, goalDtos, hasHistoryBeforeThisWeek),
    health: deriveHealth(
      goalDtos,
      lastWeekTicksByGoal,
      daysElapsedInWeek,
      activeThisWeek.size,
      memberIds.length,
      hasHistoryBeforeThisWeek
    ),
    todaySummary: {
      membersDoneToday: members.filter((m) => m.completedToday).length,
      goalsWaitingOnAnyoneToday: waitingOnAnyone,
      goalsWaitingOnOthersOnlyToday: goalDtos.filter(
        (g) =>
          g.status !== 'completed' &&
          g.currentUserCompletedToday &&
          g.membersPendingToday.length > 0
      ).length,
      goalsWaitingOnMeToday: goalDtos.filter(
        (g) => g.status !== 'completed' && !g.currentUserCompletedToday
      ).length,
      // Deprecated alias — same value it always had.
      goalsNeedingEveryoneToday: waitingOnAnyone,
    },
    members,
    goals: goalDtos,
  };

  // The invite code is an admin-only affordance; don't leak it to members.
  if (isAdmin) dto.inviteCode = group.inviteCode;

  return dto;
};

/** Build the view model for several groups using a fixed 3 queries total. */
export const buildProgressForGroups = async (
  groups: IGroup[],
  currentUserId: string
): Promise<GroupProgressDTO[]> => {
  if (groups.length === 0) return [];

  const groupIds = groups.map((g) => g._id);
  const goals = await Goal.find({ groupId: { $in: groupIds } });
  const goalIds = goals.map((g) => g._id);

  const checkIns = await CheckIn.find({
    goalId: { $in: goalIds },
    completed: true,
  }).select('userId goalId date completed');

  const memberIdSet = new Set<string>();
  for (const g of groups) for (const m of g.members) memberIdSet.add(m.toString());
  const users = await User.find(
    { _id: { $in: Array.from(memberIdSet) } },
    'name profileImage'
  );

  const userNames = new Map<string, { name: string; profileImage?: string | null }>();
  for (const u of users) {
    userNames.set(String(u._id), { name: u.name, profileImage: u.profileImage ?? null });
  }

  // goalId|userId|dateKey -> checkInId, so the client can attach notes and
  // reactions to today's check-in without a second round trip.
  const checkInIds = new Map<string, string>();
  for (const c of checkIns) {
    checkInIds.set(
      `${c.goalId.toString()}|${c.userId.toString()}|${dateKey(c.date)}`,
      String(c._id)
    );
  }

  const goalsByGroup = new Map<string, IGoal[]>();
  for (const goal of goals) {
    const key = goal.groupId.toString();
    if (!goalsByGroup.has(key)) goalsByGroup.set(key, []);
    goalsByGroup.get(key)!.push(goal);
  }

  const checkInsByGoal = new Map<string, TickSource[]>();
  for (const c of checkIns) {
    const key = c.goalId.toString();
    if (!checkInsByGoal.has(key)) checkInsByGoal.set(key, []);
    checkInsByGoal.get(key)!.push(c);
  }

  return groups.map((group) => {
    const groupGoals = goalsByGroup.get(String(group._id)) || [];
    const groupCheckIns = groupGoals.flatMap(
      (g) => checkInsByGoal.get(String(g._id)) || []
    );
    return assembleGroupProgress(
      group,
      groupGoals,
      groupCheckIns,
      userNames,
      currentUserId,
      checkInIds
    );
  });
};

/** Build the view model for a single group. */
export const buildGroupProgress = async (
  group: IGroup,
  currentUserId: string
): Promise<GroupProgressDTO> => {
  const [dto] = await buildProgressForGroups([group], currentUserId);
  return dto;
};
