import { Response } from 'express';
import { AuthRequest } from '../middlewares/authMiddleware';
import { Goal } from '../models/Goal';
import { Group } from '../models/Group';
import { CheckIn } from '../models/CheckIn';
import { io } from '../index';

// @route POST /api/groups/:groupId/goals
// @desc  Add a new goal to a group (Admin only)
export const createGoal = async (req: AuthRequest, res: Response) => {
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

    const group = await Group.findById(groupId);
    if (!group) {
      return res.status(404).json({ message: 'Group not found' });
    }

    // Verify user is in group
    if (!group.members.includes(req.user!._id as any)) {
      return res.status(403).json({ message: 'Not authorized to view this group' });
    }

    // RBAC: Verify user is the admin
    if (!group.adminId.equals(req.user!._id)) {
      return res.status(403).json({ message: 'Only the admin can create goals' });
    }

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
export const getGoals = async (req: AuthRequest, res: Response) => {
  try {
    const { groupId } = req.params;

    // We should verify group membership, assuming valid for now
    const goals = await Goal.find({ groupId });
    res.status(200).json(goals);
  } catch (error: any) {
    res.status(500).json({ message: error.message });
  }
};

// @route POST /api/goals/:goalId/checkin
// @desc  Toggle check-in for a specific day
export const toggleCheckIn = async (req: AuthRequest, res: Response) => {
  try {
    const { goalId } = req.params;
    const { date } = req.body; // ISO String (e.g. "2026-05-18T00:00:00.000Z")

    if (!date) return res.status(400).json({ message: 'Date is required' });

    // Normalize date to start of day
    const checkDate = new Date(date);
    checkDate.setUTCHours(0, 0, 0, 0);

    let checkIn = await CheckIn.findOne({
      userId: req.user!._id,
      goalId,
      date: checkDate,
    });

    if (checkIn) {
      // Toggle it
      checkIn.completed = !checkIn.completed;
      await checkIn.save();
    } else {
      // Create new
      checkIn = await CheckIn.create({
        userId: req.user!._id,
        goalId: goalId as any,
        date: checkDate,
        completed: true,
      });
    }

    // Emit to group room AND each member's personal room (for home screen refresh)
    const goalData = await Goal.findById(goalId);
    if (goalData) {
      io.to(goalData.groupId.toString()).emit('checkin_updated', goalId);
      const group = await Group.findById(goalData.groupId);
      if (group) {
        group.members.forEach((memberId) => {
          io.to(`user_${memberId}`).emit('checkin_updated');
        });
      }
    }

    res.status(200).json(checkIn);
  } catch (error: any) {
    res.status(500).json({ message: error.message });
  }
};

// @route GET /api/goals/:goalId/checkins
// @desc  Get all check-ins for a goal (for all members in the group)
export const getCheckIns = async (req: AuthRequest, res: Response) => {
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
export const editGoal = async (req: AuthRequest, res: Response) => {
  try {
    const { goalId } = req.params;
    const { name, icon, weeklyMinimum } = req.body;

    const goal = await Goal.findById(goalId);
    if (!goal) {
      return res.status(404).json({ message: 'Goal not found' });
    }

    const group = await Group.findById(goal.groupId);
    if (!group) {
      return res.status(404).json({ message: 'Group not found' });
    }

    // RBAC: Verify user is the admin
    if (!group.adminId.equals(req.user!._id)) {
      return res.status(403).json({ message: 'Only the admin can edit goals' });
    }

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
export const deleteGoal = async (req: AuthRequest, res: Response) => {
  try {
    const { goalId } = req.params;

    const goal = await Goal.findById(goalId);
    if (!goal) {
      return res.status(404).json({ message: 'Goal not found' });
    }

    const group = await Group.findById(goal.groupId);
    if (!group) {
      return res.status(404).json({ message: 'Group not found' });
    }

    // RBAC: Verify user is the admin
    if (!group.adminId.equals(req.user!._id)) {
      return res.status(403).json({ message: 'Only the admin can delete goals' });
    }

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
export const updateCheckInNote = async (req: AuthRequest, res: Response) => {
  try {
    const { checkInId } = req.params;
    const { note } = req.body;

    const checkIn = await CheckIn.findById(checkInId);
    if (!checkIn) return res.status(404).json({ message: 'Check-in not found' });

    if (!checkIn.userId.equals(req.user!._id as any)) {
      return res.status(403).json({ message: 'You can only edit your own notes' });
    }

    checkIn.note = (note ?? '').toString().slice(0, 200); // cap at 200 chars
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

// @route POST /api/goals/:goalId/checkins/:checkInId/react
// @desc  Toggle a reaction emoji on a check-in
export const reactToCheckIn = async (req: AuthRequest, res: Response) => {
  try {
    const { checkInId } = req.params;
    const { emoji } = req.body;

    if (!emoji) return res.status(400).json({ message: 'Emoji is required' });

    const checkIn = await CheckIn.findById(checkInId);
    if (!checkIn) return res.status(404).json({ message: 'Check-in not found' });

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
// @desc  Get the current user's consecutive check-in streak across ALL goals in the group
//        A "streak day" = the user checked off at least 1 goal that day
export const getGroupStreak = async (req: AuthRequest, res: Response) => {
  try {
    const { groupId } = req.params;

    const goals = await Goal.find({ groupId });
    if (!goals.length) return res.status(200).json({ streak: 0 });
    const goalIds = goals.map(g => g._id);

    const checkIns = await CheckIn.find({ goalId: { $in: goalIds }, completed: true });
    const group = await Group.findById(groupId);
    const memberCount = group && group.members.length > 0 ? group.members.length : 1;

    // Helper to get week start (Monday)
    const getWeekStart = (d: Date) => {
      const date = new Date(d);
      const day = date.getDay();
      const diff = date.getDate() - day + (day === 0 ? -6 : 1); // adjust when day is sunday
      return new Date(date.setDate(diff)).toISOString().split('T')[0];
    };

    // 1. Calculate ticks per user per week per goal
    const goalWeekUserTicks = new Map<string, Map<string, Map<string, number>>>(); // goalId -> weekStart -> userId -> count
    
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

    // 2. Aggregate into weekly group ticks per goal (minimum across all members)
    const weeklyGoalTicks = new Map<string, Map<string, number>>(); // goalId -> { weekStart -> groupTicks }
    
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

    const today = new Date();
    const currentWeekStart = getWeekStart(today);

    // For each goal, compute its streak
    let minStreak: number | null = null;

    for (const goal of goals) {
      const goalWeeks = weeklyGoalTicks.get(goal._id.toString()) || new Map();
      const target = goal.weeklyMinimum || 0;
      let streak = 0;

      // Check current week
      if ((goalWeeks.get(currentWeekStart) || 0) >= target) {
        streak++;
      }

      // Check previous weeks
      for (let i = 1; i < 520; i++) {
        const pastWeek = new Date(today);
        pastWeek.setDate(today.getDate() - i * 7);
        const pastWeekStart = getWeekStart(pastWeek);
        
        if ((goalWeeks.get(pastWeekStart) || 0) >= target) {
          streak++;
        } else {
          break;
        }
      }

      if (minStreak === null || streak < minStreak) {
        minStreak = streak;
      }
    }

    res.status(200).json({ streak: minStreak || 0 });
  } catch (error: any) {
    res.status(500).json({ message: error.message });
  }
};
