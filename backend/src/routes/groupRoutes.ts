import express from 'express';
import { createGroup, getGroup, getMyGroups, joinGroup, deleteGroup, removeMember, getGroupAnalytics } from '../controllers/groupController';
import { protect } from '../middlewares/authMiddleware';

const router = express.Router();

router.use(protect); // All group routes are protected

router.route('/').get(getMyGroups).post(createGroup);
router.post('/join', joinGroup);
router.route('/:id').get(getGroup).delete(deleteGroup);
router.delete('/:id/members/:memberId', removeMember);
router.get('/:id/analytics', getGroupAnalytics);

export default router;
