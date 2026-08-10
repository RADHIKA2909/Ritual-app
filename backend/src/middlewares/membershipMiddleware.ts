import { Response, NextFunction } from 'express';
import { AuthRequest } from './authMiddleware';
import { Group, IGroup } from '../models/Group';
import { Goal, IGoal } from '../models/Goal';

// ─────────────────────────────────────────────────────────────────────────────
// Group membership authorization
//
// Every route that reads or mutates a group's data must prove the caller is a
// member of that group. These middlewares centralise that check and attach the
// resolved documents to the request, so handlers don't re-fetch them.
//
// All of them assume `protect` has already run and populated req.user — both
// routers call router.use(protect) before any route is registered.
//
// Each body is wrapped in try/catch because index.ts registers no error
// handling middleware: an unhandled async rejection under Express 5 would
// return default HTML that the Dio client cannot parse as JSON.
// ─────────────────────────────────────────────────────────────────────────────

export interface GroupRequest extends AuthRequest {
  group?: IGroup;
  goal?: IGoal;
}

const isMember = (group: IGroup, userId: unknown): boolean =>
  group.members.some((m: any) => m.equals(userId));

/**
 * Requires the caller to be a member of the group identified by `req.params[param]`.
 * Attaches `req.group`.
 */
export const requireGroupMember =
  (param = 'id') =>
  async (req: GroupRequest, res: Response, next: NextFunction) => {
    try {
      const group = await Group.findById(req.params[param]);
      if (!group) {
        return res.status(404).json({ message: 'Group not found' });
      }
      if (!isMember(group, req.user!._id)) {
        return res.status(403).json({ message: 'Not authorized to view this group' });
      }
      req.group = group;
      next();
    } catch (error: any) {
      res.status(500).json({ message: error.message });
    }
  };

/**
 * Requires the caller to be the group's admin. `message` is supplied by the
 * caller so each route keeps the exact 403 string it returned before.
 * Attaches `req.group`.
 */
export const requireGroupAdmin =
  (param = 'id', message = 'Only the admin can do this') =>
  async (req: GroupRequest, res: Response, next: NextFunction) => {
    try {
      const group = await Group.findById(req.params[param]);
      if (!group) {
        return res.status(404).json({ message: 'Group not found' });
      }
      if (!isMember(group, req.user!._id)) {
        return res.status(403).json({ message: 'Not authorized to view this group' });
      }
      if (!group.adminId.equals(req.user!._id as any)) {
        return res.status(403).json({ message });
      }
      req.group = group;
      next();
    } catch (error: any) {
      res.status(500).json({ message: error.message });
    }
  };

/**
 * Resolves a goal to its group and requires membership of that group.
 *
 * This is the goalId -> groupId indirection: routes under /api/goals carry a
 * goalId in the path, not a groupId, so membership cannot be checked without
 * loading the goal first. Attaches both `req.goal` and `req.group`.
 */
export const requireGoalMember =
  (param = 'goalId') =>
  async (req: GroupRequest, res: Response, next: NextFunction) => {
    try {
      const goal = await Goal.findById(req.params[param]);
      if (!goal) {
        return res.status(404).json({ message: 'Goal not found' });
      }
      const group = await Group.findById(goal.groupId);
      if (!group) {
        return res.status(404).json({ message: 'Group not found' });
      }
      if (!isMember(group, req.user!._id)) {
        return res.status(403).json({ message: 'Not a member of this group' });
      }
      req.goal = goal;
      req.group = group;
      next();
    } catch (error: any) {
      res.status(500).json({ message: error.message });
    }
  };

/**
 * Requires the caller to be the admin of the group owning `req.params[param]`'s
 * goal. Runs the goal/membership resolution first, so `req.goal` and
 * `req.group` are available to the handler.
 */
export const requireGoalAdmin =
  (param = 'goalId', message = 'Only the admin can do this') =>
  async (req: GroupRequest, res: Response, next: NextFunction) => {
    await requireGoalMember(param)(req, res, () => {
      if (!req.group!.adminId.equals(req.user!._id as any)) {
        return res.status(403).json({ message });
      }
      next();
    });
  };
