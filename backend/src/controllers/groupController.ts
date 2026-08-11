import { Response } from 'express';
import { AuthRequest } from '../middlewares/authMiddleware';
import { GroupRequest } from '../middlewares/membershipMiddleware';
import { Group } from '../models/Group';
import { Goal } from '../models/Goal';
import { CheckIn } from '../models/CheckIn';
import { User } from '../models/User';
import { randomBytes } from 'crypto';
import { io } from '../index';
import { DEMO_EMAIL } from '../services/demoSeedService';

// @route POST /api/groups
// @desc  Create a new group and add the user to it
export const createGroup = async (req: AuthRequest, res: Response) => {
  try {
    if (req.user!.email === DEMO_EMAIL) {
      return res.status(403).json({
        message: 'This is a shared demo account — explore the pre-loaded groups instead of creating new ones.',
      });
    }

    let { name } = req.body;

    if (!name) {
      return res.status(400).json({ message: 'Group name is required' });
    }

    // Validate and sanitize input
    name = name.trim();
    if (name.length < 1 || name.length > 100) {
      return res.status(400).json({ message: 'Group name must be 1-100 characters' });
    }

    // Generate a unique 6-character invite code
    const inviteCode = randomBytes(3).toString('hex').toUpperCase();

    const group = await Group.create({
      name,
      inviteCode,
      adminId: req.user!._id,
      members: [req.user!._id],
    });

    io.to(`user_${req.user!._id}`).emit('group_updated');

    res.status(201).json(group);
  } catch (error: any) {
    res.status(500).json({ message: error.message });
  }
};

// @route GET /api/groups/:id
// @desc  Get group details including members
// Membership is enforced by requireGroupMember('id'). This still re-queries so
// it can populate member profiles, which the middleware's lookup does not.
export const getGroup = async (req: GroupRequest, res: Response) => {
  try {
    const group = await Group.findById(req.params.id).populate('members', 'name profileImage');

    if (!group) {
      return res.status(404).json({ message: 'Group not found' });
    }

    res.status(200).json(group);
  } catch (error: any) {
    res.status(500).json({ message: error.message });
  }
};

// @route GET /api/groups
// @desc  Get all groups the logged-in user belongs to (with member names + goal counts)
export const getMyGroups = async (req: AuthRequest, res: Response) => {
  try {
    const groups = await Group.find({ members: req.user!._id })
      .populate('members', 'name email');

    // Attach goal count for each group
    const { Goal } = await import('../models/Goal');
    const groupsWithMeta = await Promise.all(
      groups.map(async (g) => {
        const goalCount = await Goal.countDocuments({ groupId: g._id });
        return { ...g.toObject(), goalCount };
      })
    );

    res.status(200).json(groupsWithMeta);
  } catch (error: any) {
    res.status(500).json({ message: error.message });
  }
};

// @route POST /api/groups/join
// @desc  Join a group via invite code
export const joinGroup = async (req: AuthRequest, res: Response) => {
  try {
    if (req.user!.email === DEMO_EMAIL) {
      return res.status(403).json({
        message: 'This is a shared demo account — explore the pre-loaded groups instead of joining new ones.',
      });
    }

    const { inviteCode } = req.body;

    if (!inviteCode) {
      return res.status(400).json({ message: 'Invite code is required' });
    }

    const group = await Group.findOne({ inviteCode });
    if (!group) {
      return res.status(404).json({ message: 'Invalid invite code' });
    }

    if (group.members.some((m: any) => m.equals(req.user!._id))) {
      // Already a member — return group so client can navigate to it
      return res.status(200).json({ ...group.toObject(), alreadyMember: true });
    }

    group.members.push(req.user!._id as any);
    await group.save();

    group.members.forEach((memberId) => {
      io.to(`user_${memberId}`).emit('group_updated');
    });

    res.status(200).json(group);
  } catch (error: any) {
    res.status(500).json({ message: error.message });
  }
};

// @route DELETE /api/groups/:id
// @desc  Delete a group and its goals/checkins (Admin only)
// Membership + admin are enforced by requireGroupAdmin('id').
export const deleteGroup = async (req: GroupRequest, res: Response) => {
  try {
    const group = req.group!;

    // Find all goals in this group
    const goals = await Goal.find({ groupId: group._id });
    const goalIds = goals.map(g => g._id);

    // Delete all check-ins for these goals
    await CheckIn.deleteMany({ goalId: { $in: goalIds } });

    // Delete all goals
    await Goal.deleteMany({ groupId: group._id });

    // Delete group
    await Group.findByIdAndDelete(group._id);

    group.members.forEach((memberId) => {
      io.to(`user_${memberId}`).emit('group_updated');
    });

    res.status(200).json({ message: 'Group removed completely' });
  } catch (error: any) {
    res.status(500).json({ message: error.message });
  }
};

// @route DELETE /api/groups/:id/members/:memberId
// @desc  Remove a member from the group (Admin only)
// Membership + admin are enforced by requireGroupAdmin('id').
export const removeMember = async (req: GroupRequest, res: Response) => {
  try {
    const { memberId } = req.params;

    const group = req.group!;

    if (group.adminId.equals(memberId as any)) {
      return res.status(400).json({ message: 'Admin cannot be removed' });
    }

    // Remove member
    group.members = group.members.filter((m: any) => !m.equals(memberId));
    await group.save();

    res.status(200).json(group);
  } catch (error: any) {
    res.status(500).json({ message: error.message });
  }
};

// @route GET /api/groups/:id/analytics
// @desc  Get comprehensive analytics data for the group (all goals + all checkins)
// Membership is enforced by requireGroupMember('id').
export const getGroupAnalytics = async (req: GroupRequest, res: Response) => {
  try {
    const { id } = req.params;

    const group = req.group!;

    // Fetch all goals
    const goals = await Goal.find({ groupId: id });
    const goalIds = goals.map((g) => g._id);

    // Fetch all completed checkins for these goals
    const checkIns = await CheckIn.find({
      goalId: { $in: goalIds },
      completed: true,
    }).sort({ date: 1 }); // Sort chronologically

    res.status(200).json({ goals, checkIns, members: group.members });
  } catch (error: any) {
    res.status(500).json({ message: error.message });
  }
};

// @route GET /api/groups/:id/feed
// @desc  Get recent activity feed for a group (last 50 completed check-ins with user + goal info)
// Membership is enforced by requireGroupMember('id').
export const getGroupFeed = async (req: GroupRequest, res: Response) => {
  try {
    const { id } = req.params;

    const group = req.group!;

    const goals = await Goal.find({ groupId: id });
    const goalIds = goals.map((g) => g._id);

    // Build lookup maps
    const goalMap: Record<string, { name: string; icon: string }> = {};
    for (const g of goals) {
      goalMap[g._id.toString()] = { name: g.name, icon: g.icon };
    }

    const members = await User.find({ _id: { $in: group.members } }, 'name profileImage');
    const userMap: Record<string, { name: string; profileImage?: string }> = {};
    for (const u of members) {
      userMap[u._id.toString()] = { name: u.name, profileImage: u.profileImage };
    }

    const checkIns = await CheckIn.find({
      goalId: { $in: goalIds },
      completed: true,
    })
      .sort({ createdAt: -1 })
      .limit(50);

    const feed = checkIns.map((c) => ({
      _id: c._id,
      userId: c.userId,
      userName: userMap[c.userId.toString()]?.name ?? 'Unknown',
      userProfileImage: userMap[c.userId.toString()]?.profileImage ?? null,
      goalId: c.goalId,
      goalName: goalMap[c.goalId.toString()]?.name ?? 'Goal',
      goalIcon: goalMap[c.goalId.toString()]?.icon ?? '🎯',
      date: c.date,
      createdAt: c.createdAt,
      note: c.note ?? '',
      reactions: c.reactions ?? [],
    }));

    res.status(200).json(feed);
  } catch (error: any) {
    res.status(500).json({ message: error.message });
  }
};
