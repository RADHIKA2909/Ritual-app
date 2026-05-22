import { Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { User } from '../models/User';
import admin from '../config/firebase';

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
        if (!user.profileImage && picture) user.profileImage = picture;
        await user.save();
      } else {
        // Brand new user
        user = await User.create({
          name: name || email.split('@')[0],
          email,
          googleId: uid,
          profileImage: picture || `https://api.dicebear.com/7.x/avataaars/svg?seed=${uid}`,
        });
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
export const mockLogin = async (req: Request, res: Response) => {
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
        profileImage: `https://api.dicebear.com/7.x/avataaars/svg?seed=${name}`,
      });
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
