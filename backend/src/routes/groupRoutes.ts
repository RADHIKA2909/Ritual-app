import express from 'express';
import { createGroup, getGroup, getMyGroups, joinGroup, deleteGroup, removeMember, getGroupAnalytics, getGroupFeed } from '../controllers/groupController';
import { getMessages, sendMessage } from '../controllers/chatController';
import { getGroupProgress } from '../controllers/progressController';
import { protect } from '../middlewares/authMiddleware';
import { requireGroupMember, requireGroupAdmin } from '../middlewares/membershipMiddleware';

const router = express.Router();

router.use(protect); // All group routes are protected

router.route('/').get(getMyGroups).post(createGroup);

// Must stay above '/:id' so the literal path isn't captured as an id.
router.post('/join', joinGroup);

router
  .route('/:id')
  .get(requireGroupMember('id'), getGroup)
  .delete(requireGroupAdmin('id', 'Only the admin can delete the group'), deleteGroup);

router.delete(
  '/:id/members/:memberId',
  requireGroupAdmin('id', 'Only the admin can remove members'),
  removeMember
);

router.get('/:id/progress', requireGroupMember('id'), getGroupProgress);
router.get('/:id/analytics', requireGroupMember('id'), getGroupAnalytics);
router.get('/:id/feed', requireGroupMember('id'), getGroupFeed);
router.get('/:id/messages', requireGroupMember('id'), getMessages);
router.post('/:id/messages', requireGroupMember('id'), sendMessage);

export default router;
