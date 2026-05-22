import express from 'express';
import { protect } from '../middlewares/authMiddleware';
import { getMyAnalytics } from '../controllers/userController';

const router = express.Router();

router.get('/me/analytics', protect, getMyAnalytics);

export default router;
