import { Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { User } from '../models/User';
import admin from '../config/firebase';
import { ensureDemoData } from '../services/demoSeedService';

// ── Google / Firebase Auth ────────────────────────────────────────────────────
// @route POST /api/auth/google
// @desc  Verify a Firebase ID token from the client, upsert user in MongoDB,
//        and return our own JWT that the app uses for all subsequent API calls.
export const googleLogin = async (req: Request, res: Response) => {
  try {
    const { idToken } = req.body;
    if (!idToken) {
      return res.status(400).json({ message: 'Firebase idToken is required' });
    }

    // 1. Verify the Firebase ID token
    const decoded = await admin.auth().verifyIdToken(idToken);

    const { uid, email, name, picture } = decoded;
    if (!email) {
      return res.status(400).json({ message: 'Email not available from Google account' });
    }

    // 2. Upsert user in MongoDB
    let user = await User.findOne({ googleId: uid });

    if (!user) {
      // Try finding by email (in case they previously used mock login)
      user = await User.findOne({ email });
      if (user) {
        // Link Google ID to existing account
        user.googleId = uid;
        // Use Google photo; fall back to PNG DiceBear (SVG won't render in Flutter)
        if (!user.profileImage || user.profileImage.includes('/svg')) {
          user.profileImage = picture || `https://api.dicebear.com/7.x/avataaars/png?seed=${uid}`;
        }
        await user.save();
      } else {
        // Brand new user
        user = await User.create({
          name: name || email.split('@')[0],
          email,
          googleId: uid,
          profileImage: picture || `https://api.dicebear.com/7.x/avataaars/png?seed=${uid}`,
        });
      }
    } else {
      // User already exists — update name & fix any SVG avatar from old code
      if (user.profileImage?.includes('/svg')) {
        user.profileImage = picture || `https://api.dicebear.com/7.x/avataaars/png?seed=${uid}`;
        await user.save();
      }
    }

    // 3. Issue our own JWT (short-lived for security)
    const token = jwt.sign(
      { id: user._id },
      process.env.JWT_SECRET || 'dev_secret',
      { expiresIn: '30d' }
    );

    return res.status(200).json({
      _id: user._id,
      name: user.name,
      email: user.email,
      profileImage: user.profileImage,
      token,
    });
  } catch (error: any) {
    console.error('Google auth error:', error);
    return res.status(401).json({ message: 'Invalid Firebase token', detail: error.message });
  }
};

// ── Mock Login (kept for local dev without Firebase) ─────────────────────────
// @route POST /api/auth/mock-login
// @desc  Dev-only endpoint for testing (disabled in production)
export const mockLogin = async (req: Request, res: Response) => {
  // Gate: only allow in development
  if (process.env.NODE_ENV === 'production') {
    return res.status(403).json({ message: 'Mock login is not available in production' });
  }

  try {
    const { name, email } = req.body;
    if (!name || !email) {
      return res.status(400).json({ message: 'Name and email are required' });
    }

    let user = await User.findOne({ email });
    if (!user) {
      user = await User.create({
        name,
        email,
        // PNG format — Flutter's NetworkImage cannot render SVG
        profileImage: `https://api.dicebear.com/7.x/avataaars/png?seed=${encodeURIComponent(name)}`,
      });
    } else if (user.profileImage?.includes('/svg')) {
      // Fix old SVG avatar for existing dev users
      user.profileImage = `https://api.dicebear.com/7.x/avataaars/png?seed=${encodeURIComponent(name)}`;
      await user.save();
    }

    const token = jwt.sign(
      { id: user._id },
      process.env.JWT_SECRET || 'dev_secret',
      { expiresIn: '30d' }
    );

    return res.status(200).json({
      _id: user._id,
      name: user.name,
      email: user.email,
      profileImage: user.profileImage,
      token,
    });
  } catch (error: any) {
    return res.status(500).json({ message: error.message });
  }
};

// ── Demo Login ─────────────────────────────────────────────────────────────
// @route POST /api/auth/demo-login
// @desc  Log in as the shared, public demo account. Its groups/check-ins are
//        regenerated on the fly (once per calendar day, on the first login of
//        that day) so the trailing history always covers "the last ~3 months"
//        relative to whenever someone actually opens the app. Deliberately
//        NOT gated by NODE_ENV — unlike mockLogin, this is meant to work on
//        the live production deployment; that's the whole point.
export const demoLogin = async (req: Request, res: Response) => {
  try {
    const TIMEOUT_MS = 15000;
    const user = await Promise.race([
      ensureDemoData(),
      new Promise<never>((_, reject) =>
        setTimeout(() => reject(new Error('DEMO_TIMEOUT')), TIMEOUT_MS)
      ),
    ]);

    const token = jwt.sign(
      { id: user._id },
      process.env.JWT_SECRET || 'dev_secret',
      { expiresIn: '30d' }
    );

    return res.status(200).json({
      _id: user._id,
      name: user.name,
      email: user.email,
      profileImage: user.profileImage,
      token,
    });
  } catch (error: any) {
    if (error.message === 'DEMO_TIMEOUT') {
      return res.status(503).json({ message: 'Demo is warming up, please try again in a moment' });
    }
    return res.status(500).json({ message: error.message });
  }
};
