import { Response } from 'express';
import { AuthRequest } from '../middlewares/authMiddleware';
import { Group } from '../models/Group';
import { Goal } from '../models/Goal';
import { CheckIn } from '../models/CheckIn';

export const getMyAnalytics = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?._id;
    if (!userId) {
      return res.status(401).json({ message: 'Not authorized' });
    }

    // 1. Get all groups user is a part of
    const groups = await Group.find({ members: userId });
    const groupIds = groups.map(g => g._id);

    // 2. Get all goals for those groups
    const goals = await Goal.find({ groupId: { $in: groupIds } });
    const goalIds = goals.map(g => g._id);

    // 3. Get all personal check-ins for these goals
    const checkIns = await CheckIn.find({
      userId: userId,
      goalId: { $in: goalIds },
      completed: true,
    });

    res.status(200).json({
      groups,
      goals,
      checkIns,
    });
  } catch (error: any) {
    res.status(500).json({ message: error.message });
  }
};
