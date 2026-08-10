import { Response } from 'express';
import { GroupRequest } from '../middlewares/membershipMiddleware';
import { Goal } from '../models/Goal';
import { Group } from '../models/Group';
import { CheckIn } from '../models/CheckIn';
import {
  buildGoalWeekUserTicks,
  buildWeeklyGoalTicks,
  computeGroupStreak,
} from '../services/progressService';
import { io } from '../index';

// @route POST /api/groups/:groupId/goals
// @desc  Add a new goal to a group (Admin only)
// Membership + admin are enforced by requireGroupAdmin('groupId'), which
// attaches req.group.
export const createGoal = async (req: GroupRequest, res: Response) => {
  try {
    const { groupId } = req.params;
    let { name, icon, weeklyMinimum } = req.body;

    // Validate input
    if (!name) {
      return res.status(400).json({ message: 'Goal name is required' });
    }
    name = name.trim();
    if (name.length < 1 || name.length > 100) {
      return res.status(400).json({ message: 'Goal name must be 1-100 characters' });
    }
    if (weeklyMinimum && (weeklyMinimum < 1 || weeklyMinimum > 7)) {
      return res.status(400).json({ message: 'Weekly minimum must be between 1 and 7' });
    }

    const group = req.group!;

    const goal = await Goal.create({
      groupId: groupId as any,
      name,
      icon,
      weeklyMinimum,
    });

    io.to(groupId).emit('goal_updated');
    group.members.forEach((memberId) => {
      io.to(`user_${memberId}`).emit('group_updated');
    });

    res.status(201).json(goal);
  } catch (error: any) {
    res.status(500).json({ message: error.message });
  }
};

// @route GET /api/groups/:groupId/goals
// @desc  Get all goals for a group
// Membership is enforced by requireGroupMember('groupId').
export const getGoals = async (req: GroupRequest, res: Response) => {
  try {
    const { groupId } = req.params;

    const goals = await Goal.find({ groupId });
    res.status(200).json(goals);
  } catch (error: any) {
    res.status(500).json({ message: error.message });
  }
};

// @route POST /api/goals/:goalId/checkin
// @desc  Set (or toggle) the current user's check-in for a specific day.
//
//        Body { date }             -> toggles, as it always has.
//        Body { date, completed }  -> sets that exact value, idempotently.
//
//        The explicit form is preferred by the client: it makes a double tap
//        harmless instead of silently undoing the check-in, and the upsert
//        cannot lose the race that the find-then-create path could against the
//        unique (userId, goalId, date) index.
// Membership is enforced by requireGoalMember(), which attaches req.goal and
// req.group — without it any authenticated user could check into any group.
export const toggleCheckIn = async (req: GroupRequest, res: Response) => {
  try {
    const { goalId } = req.params;
    const { date, completed } = req.body; // ISO String (e.g. "2026-05-18T00:00:00.000Z")

    if (!date) return res.status(400).json({ message: 'Date is required' });

    // Normalize date to start of day
    const checkDate = new Date(date);
    checkDate.setUTCHours(0, 0, 0, 0);

    let checkIn;

    if (typeof completed === 'boolean') {
      // Explicit, idempotent set.
      checkIn = await CheckIn.findOneAndUpdate(
        { userId: req.user!._id, goalId, date: checkDate },
        {
          $set: { completed },
          $setOnInsert: { userId: req.user!._id, goalId, date: checkDate },
        },
        { new: true, upsert: true, setDefaultsOnInsert: true }
      );
    } else {
      // Legacy toggle — preserved byte-for-byte for older clients.
      checkIn = await CheckIn.findOne({
        userId: req.user!._id,
        goalId,
        date: checkDate,
      });

      if (checkIn) {
        checkIn.completed = !checkIn.completed;
        await checkIn.save();
      } else {
        checkIn = await CheckIn.create({
          userId: req.user!._id,
          goalId: goalId as any,
          date: checkDate,
          completed: true,
        });
      }
    }

    // Emit to group room AND each member's personal room (for home screen refresh)
    const group = req.group!;
    const groupId = group._id.toString();
    io.to(groupId).emit('checkin_updated', goalId);
    group.members.forEach((memberId) => {
      // Payload lets a listener refresh just this group instead of everything.
      io.to(`user_${memberId}`).emit('checkin_updated', { goalId, groupId });
    });

    res.status(200).json(checkIn);
  } catch (error: any) {
    res.status(500).json({ message: error.message });
  }
};

// @route GET /api/goals/:goalId/checkins
// @desc  Get all check-ins for a goal (for all members in the group)
// Membership is enforced by requireGoalMember().
export const getCheckIns = async (req: GroupRequest, res: Response) => {
  try {
    const { goalId } = req.params;
    const checkIns = await CheckIn.find({ goalId });
    res.status(200).json(checkIns);
  } catch (error: any) {
    res.status(500).json({ message: error.message });
  }
};

// @route PUT /api/goals/:goalId
// @desc  Edit a goal's name, icon, or weeklyMinimum (Admin only)
// Membership + admin are enforced by requireGoalAdmin(), which attaches
// req.goal and req.group.
export const editGoal = async (req: GroupRequest, res: Response) => {
  try {
    const { name, icon, weeklyMinimum } = req.body;

    const goal = req.goal!;

    if (name !== undefined) goal.name = name;
    if (icon !== undefined) goal.icon = icon;
    if (weeklyMinimum !== undefined) goal.weeklyMinimum = weeklyMinimum;
    await goal.save();

    io.to(goal.groupId.toString()).emit('goal_updated');

    res.status(200).json(goal);
  } catch (error: any) {
    res.status(500).json({ message: error.message });
  }
};

// @route DELETE /api/goals/:goalId
// @desc  Delete a goal and its checkins (Admin only)
// Membership + admin are enforced by requireGoalAdmin().
export const deleteGoal = async (req: GroupRequest, res: Response) => {
  try {
    const { goalId } = req.params;

    const goal = req.goal!;
    const group = req.group!;

    // Delete check-ins
    await CheckIn.deleteMany({ goalId });
    
    // Delete goal
    await Goal.findByIdAndDelete(goalId);

    io.to(goal.groupId.toString()).emit('goal_updated');
    group.members.forEach((memberId) => {
      io.to(`user_${memberId}`).emit('group_updated');
    });

    res.status(200).json({ message: 'Goal removed completely' });
  } catch (error: any) {
    res.status(500).json({ message: error.message });
  }
};

// @route PUT /api/goals/:goalId/checkins/:checkInId/note
// @desc  Add or update a note on a check-in (only the owner can edit)
// Membership is enforced by requireGoalMember().
export const updateCheckInNote = async (req: GroupRequest, res: Response) => {
  try {
    const { checkInId } = req.params;
    const { note } = req.body;

    const checkIn = await CheckIn.findById(checkInId);
    if (!checkIn) return res.status(404).json({ message: 'Check-in not found' });

    // The check-in must belong to the goal in the path. Without this, the
    // membership middleware could be satisfied with a goal from your own group
    // while checkInId pointed at a check-in in someone else's.
    if (!checkIn.goalId.equals(req.goal!._id as any)) {
      return res.status(404).json({ message: 'Check-in not found' });
    }

    if (!checkIn.userId.equals(req.user!._id as any)) {
      return res.status(403).json({ message: 'You can only edit your own notes' });
    }

    checkIn.note = (note ?? '').toString().slice(0, 200); // cap at 200 chars
    await checkIn.save();

    io.to(req.group!._id.toString()).emit('checkin_updated', checkIn.goalId.toString());

    res.status(200).json(checkIn);
  } catch (error: any) {
    res.status(500).json({ message: error.message });
  }
};

// @route POST /api/goals/:goalId/checkins/:checkInId/react
// @desc  Toggle a reaction emoji on a check-in
// Membership is enforced by requireGoalMember().
export const reactToCheckIn = async (req: GroupRequest, res: Response) => {
  try {
    const { checkInId } = req.params;
    const { emoji } = req.body;

    if (!emoji) return res.status(400).json({ message: 'Emoji is required' });

    const checkIn = await CheckIn.findById(checkInId);
    if (!checkIn) return res.status(404).json({ message: 'Check-in not found' });

    // The check-in must belong to the goal in the path — see updateCheckInNote.
    // This handler has no owner check by design (you react to other people's
    // check-ins), so without this guard any member could react to any check-in
    // in the database by pairing it with one of their own goal ids.
    if (!checkIn.goalId.equals(req.goal!._id as any)) {
      return res.status(404).json({ message: 'Check-in not found' });
    }

    const userId = req.user!._id;

    // Find if user already reacted (with any emoji)
    const existingIndex = checkIn.reactions.findIndex(
      (r) => r.userId.equals(userId as any)
    );
    const alreadySameEmoji =
      existingIndex >= 0 && checkIn.reactions[existingIndex].emoji === emoji;

    // Remove any existing reaction from this user
    if (existingIndex >= 0) {
      checkIn.reactions.splice(existingIndex, 1);
    }

    // Only add new reaction if it wasn't the same emoji (i.e. not a toggle-off)
    if (!alreadySameEmoji) {
      checkIn.reactions.push({ userId: userId as any, emoji });
    }

    await checkIn.save();

    const goalData = await Goal.findById(checkIn.goalId);
    if (goalData) {
      io.to(goalData.groupId.toString()).emit('checkin_updated', checkIn.goalId.toString());
    }

    res.status(200).json(checkIn);
  } catch (error: any) {
    res.status(500).json({ message: error.message });
  }
};

// @route GET /api/goals/group/:groupId/streak
// @desc  The group's shared weekly streak.
//        Check-ins are bucketed into Monday-starting weeks. For each goal and
//        week the group's score is the MINIMUM number of completed check-ins
//        across all current members, so the group only advances at the pace of
//        its least active member. A goal passes a week when that score reaches
//        its weeklyMinimum; its streak is the run of consecutive passing weeks
//        counting back from this week. The group's streak is the minimum streak
//        across all of its goals.
//        The implementation lives in services/progressService.ts.
export const getGroupStreak = async (req: GroupRequest, res: Response) => {
  try {
    const { groupId } = req.params;

    const goals = await Goal.find({ groupId });
    if (!goals.length) return res.status(200).json({ streak: 0 });
    const goalIds = goals.map(g => g._id);

    const checkIns = await CheckIn.find({ goalId: { $in: goalIds }, completed: true });
    const group = req.group ?? (await Group.findById(groupId)) ?? null;

    const weeklyGoalTicks = buildWeeklyGoalTicks(
      buildGoalWeekUserTicks(checkIns),
      group
    );
    const streak = computeGroupStreak(
      goals.map(g => ({ _id: g._id, weeklyMinimum: g.weeklyMinimum || 0 })),
      weeklyGoalTicks,
      new Date()
    );

    res.status(200).json({ streak });
  } catch (error: any) {
    res.status(500).json({ message: error.message });
  }
};
