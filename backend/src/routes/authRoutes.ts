import express from 'express';
import { mockLogin, googleLogin } from '../controllers/authController';

const router = express.Router();

router.post('/mock-login', mockLogin);
router.post('/google', googleLogin);        // Firebase Google ID token → our JWT

export default router;
