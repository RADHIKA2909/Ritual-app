import { Response } from 'express';
import { GroupRequest } from '../middlewares/membershipMiddleware';
import { Message } from '../models/Message';
import { io } from '../index';
import { DEMO_EMAIL } from '../services/demoSeedService';

// The demo account's chat is a public, unmoderated surface (anyone who opens
// the demo can post to it, visible to every other visitor until the next
// daily reset) — cap it to bound worst-case exposure. Single account, single
// instance, so a plain in-memory sliding window is enough; no new dependency.
const DEMO_MESSAGE_WINDOW_MS = 60 * 60 * 1000;
const DEMO_MESSAGE_LIMIT = 20;
let demoMessageTimestamps: number[] = [];

function demoRateLimitExceeded(): boolean {
  const now = Date.now();
  demoMessageTimestamps = demoMessageTimestamps.filter((t) => now - t < DEMO_MESSAGE_WINDOW_MS);
  if (demoMessageTimestamps.length >= DEMO_MESSAGE_LIMIT) return true;
  demoMessageTimestamps.push(now);
  return false;
}

// @route GET /api/groups/:id/messages
// @desc  Get last 100 messages for a group (members only)
// Membership is enforced by requireGroupMember('id').
export const getMessages = async (req: GroupRequest, res: Response) => {
  try {
    const { id } = req.params;

    const messages = await Message.find({ groupId: id })
      .sort({ createdAt: -1 })
      .limit(100)
      .populate('userId', 'name profileImage');

    res.status(200).json(messages.reverse());
  } catch (error: any) {
    res.status(500).json({ message: error.message });
  }
};

// @route POST /api/groups/:id/messages
// @desc  Send a message to a group chat
// Membership is enforced by requireGroupMember('id').
export const sendMessage = async (req: GroupRequest, res: Response) => {
  try {
    const { id } = req.params;
    const { text } = req.body;

    if (!text?.trim()) {
      return res.status(400).json({ message: 'Message cannot be empty' });
    }

    if (req.user!.email === DEMO_EMAIL && demoRateLimitExceeded()) {
      return res.status(429).json({ message: 'Demo chat is rate-limited — try again later.' });
    }

    const group = req.group!;

    const message = await Message.create({
      groupId: id as any,
      userId: req.user!._id,
      text: text.trim().slice(0, 500),
    });

    const populated = await Message.findById(message._id).populate(
      'userId',
      'name profileImage'
    );

    // Broadcast to everyone in the group room
    io.to(id).emit('new_message', populated);

    // Also notify each member's personal room so they can show a badge
    group.members.forEach((memberId) => {
      io.to(`user_${memberId}`).emit('new_group_message', {
        groupId: id,
        groupName: group.name,
      });
    });

    res.status(201).json(populated);
  } catch (error: any) {
    res.status(500).json({ message: error.message });
  }
};
