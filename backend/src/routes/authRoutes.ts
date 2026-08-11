import express from 'express';
import { mockLogin, googleLogin, demoLogin } from '../controllers/authController';

const router = express.Router();

router.post('/mock-login', mockLogin);
router.post('/google', googleLogin);        // Firebase Google ID token → our JWT
router.post('/demo-login', demoLogin);      // Shared public demo account — see demoSeedService.ts

export default router;
