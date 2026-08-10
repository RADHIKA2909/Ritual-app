import express from 'express';
import { createGoal, getGoals, editGoal, toggleCheckIn, getCheckIns, updateCheckInNote, reactToCheckIn, deleteGoal, getGroupStreak } from '../controllers/goalController';
import { protect } from '../middlewares/authMiddleware';
import {
  requireGroupMember,
  requireGroupAdmin,
  requireGoalMember,
  requireGoalAdmin,
} from '../middlewares/membershipMiddleware';

const router = express.Router();

router.use(protect); // All goal routes protected

// Routes attached to /api/groups/:groupId/goals (handled in index.ts or group routes)
// But for simplicity we'll mount them directly here
router.post('/group/:groupId', requireGroupAdmin('groupId', 'Only the admin can create goals'), createGoal);
router.get('/group/:groupId', requireGroupMember('groupId'), getGoals);
router.get('/group/:groupId/streak', requireGroupMember('groupId'), getGroupStreak);

// Routes attached to /api/goals — the goalId is resolved to its group so
// membership can be checked before anything is read or written.
router.post('/:goalId/checkin', requireGoalMember(), toggleCheckIn);
router.get('/:goalId/checkins', requireGoalMember(), getCheckIns);
router.put('/:goalId/checkins/:checkInId/note', requireGoalMember(), updateCheckInNote);
router.post('/:goalId/checkins/:checkInId/react', requireGoalMember(), reactToCheckIn);
router.put('/:goalId', requireGoalAdmin('goalId', 'Only the admin can edit goals'), editGoal);
router.delete('/:goalId', requireGoalAdmin('goalId', 'Only the admin can delete goals'), deleteGoal);

export default router;
