import express from 'express';
import { protect } from '../middlewares/authMiddleware';
import { getMyAnalytics, getMe, updateProfile } from '../controllers/userController';

const router = express.Router();

router.get('/me', protect, getMe);
router.put('/me', protect, updateProfile);
router.get('/me/analytics', protect, getMyAnalytics);

export default router;
