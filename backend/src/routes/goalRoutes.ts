import express from 'express';
import { createGoal, getGoals, editGoal, toggleCheckIn, getCheckIns, updateCheckInNote, reactToCheckIn, deleteGoal, getGroupStreak } from '../controllers/goalController';
import { protect } from '../middlewares/authMiddleware';

const router = express.Router();

router.use(protect); // All goal routes protected

// Routes attached to /api/groups/:groupId/goals (handled in index.ts or group routes)
// But for simplicity we'll mount them directly here
router.post('/group/:groupId', createGoal);
router.get('/group/:groupId', getGoals);
router.get('/group/:groupId/streak', getGroupStreak);

// Routes attached to /api/goals
router.post('/:goalId/checkin', toggleCheckIn);
router.get('/:goalId/checkins', getCheckIns);
router.put('/:goalId/checkins/:checkInId/note', updateCheckInNote);
router.post('/:goalId/checkins/:checkInId/react', reactToCheckIn);
router.put('/:goalId', editGoal);
router.delete('/:goalId', deleteGoal);

export default router;
