import { Response } from 'express';
import { AuthRequest } from '../middlewares/authMiddleware';
import { Group } from '../models/Group';
import { Goal } from '../models/Goal';
import { CheckIn } from '../models/CheckIn';
import crypto from 'crypto';
import { io } from '../index';

// @route POST /api/groups
// @desc  Create a new group and add the user to it
export const createGroup = async (req: AuthRequest, res: Response) => {
  try {
    const { name } = req.body;
    
    if (!name) {
      return res.status(400).json({ message: 'Group name is required' });
    }

    // Generate a unique 6-character invite code
    const inviteCode = crypto.randomBytes(3).toString('hex').toUpperCase();

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
export const getGroup = async (req: AuthRequest, res: Response) => {
  try {
    const group = await Group.findById(req.params.id).populate('members', 'name profileImage');
    
    if (!group) {
      return res.status(404).json({ message: 'Group not found' });
    }

    // Ensure the user is part of the group
    const isMember = group.members.some((member: any) => member._id.equals(req.user!._id));
    if (!isMember) {
      return res.status(403).json({ message: 'Not authorized to view this group' });
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
export const deleteGroup = async (req: AuthRequest, res: Response) => {
  try {
    const group = await Group.findById(req.params.id);

    if (!group) {
      return res.status(404).json({ message: 'Group not found' });
    }

    // Ensure the user is the admin
    if (!group.adminId.equals(req.user!._id)) {
      return res.status(403).json({ message: 'Only the admin can delete the group' });
    }

    // Find all goals in this group
    const goals = await Goal.find({ group: group._id });
    const goalIds = goals.map(g => g._id);

    // Delete all check-ins for these goals
    await CheckIn.deleteMany({ goal: { $in: goalIds } });
    
    // Delete all goals
    await Goal.deleteMany({ group: group._id });

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
export const removeMember = async (req: AuthRequest, res: Response) => {
  try {
    const { id, memberId } = req.params;
    
    const group = await Group.findById(id);
    if (!group) {
      return res.status(404).json({ message: 'Group not found' });
    }

    // Ensure the user is the admin
    if (!group.adminId.equals(req.user!._id)) {
      return res.status(403).json({ message: 'Only the admin can remove members' });
    }

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
export const getGroupAnalytics = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;

    const group = await Group.findById(id);
    if (!group) {
      return res.status(404).json({ message: 'Group not found' });
    }

    // Verify user is in group
    if (!group.members.includes(req.user!._id as any)) {
      return res.status(403).json({ message: 'Not authorized to view this group' });
    }

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
