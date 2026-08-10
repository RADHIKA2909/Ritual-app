import { Response } from 'express';
import { AuthRequest } from '../middlewares/authMiddleware';
import { GroupRequest } from '../middlewares/membershipMiddleware';
import { Group } from '../models/Group';
import { buildGroupProgress, buildProgressForGroups } from '../services/progressService';

// @route GET /api/groups/:id/progress
// @desc  The full group view model: per-goal group vs personal progress, member
//        breakdown, streak status and group health.
// Membership is enforced by requireGroupMember('id'), which attaches req.group.
export const getGroupProgress = async (req: GroupRequest, res: Response) => {
  try {
    const progress = await buildGroupProgress(req.group!, String(req.user!._id));
    res.status(200).json(progress);
  } catch (error: any) {
    res.status(500).json({ message: error.message });
  }
};

// @route GET /api/users/me/progress
// @desc  The same view model for every group the caller belongs to, in one
//        round trip. Home and Today's Rituals are both cross-group screens, so
//        fetching per group would be a 1+N cascade on every socket event.
export const getMyProgress = async (req: AuthRequest, res: Response) => {
  try {
    const groups = await Group.find({ members: req.user!._id });
    const progress = await buildProgressForGroups(groups, String(req.user!._id));
    res.status(200).json({
      groups: progress,
      generatedAt: new Date().toISOString(),
    });
  } catch (error: any) {
    res.status(500).json({ message: error.message });
  }
};
