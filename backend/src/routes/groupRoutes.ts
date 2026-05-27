import express from 'express';
import { createGroup, getGroup, getMyGroups, joinGroup, deleteGroup, removeMember, getGroupAnalytics, getGroupFeed } from '../controllers/groupController';
import { getMessages, sendMessage } from '../controllers/chatController';
import { protect } from '../middlewares/authMiddleware';

const router = express.Router();

router.use(protect); // All group routes are protected

router.route('/').get(getMyGroups).post(createGroup);
router.post('/join', joinGroup);
router.route('/:id').get(getGroup).delete(deleteGroup);
router.delete('/:id/members/:memberId', removeMember);
router.get('/:id/analytics', getGroupAnalytics);
router.get('/:id/feed', getGroupFeed);
router.get('/:id/messages', getMessages);
router.post('/:id/messages', sendMessage);

export default router;
