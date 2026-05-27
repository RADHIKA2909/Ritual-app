import { Response } from 'express';
import { AuthRequest } from '../middlewares/authMiddleware';
import { Message } from '../models/Message';
import { Group } from '../models/Group';
import { io } from '../index';

// @route GET /api/groups/:id/messages
// @desc  Get last 100 messages for a group (members only)
export const getMessages = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;

    const group = await Group.findById(id);
    if (!group) return res.status(404).json({ message: 'Group not found' });
    if (!group.members.some((m) => m.equals(req.user!._id as any))) {
      return res.status(403).json({ message: 'Not a member of this group' });
    }

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
export const sendMessage = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const { text } = req.body;

    if (!text?.trim()) {
      return res.status(400).json({ message: 'Message cannot be empty' });
    }

    const group = await Group.findById(id);
    if (!group) return res.status(404).json({ message: 'Group not found' });
    if (!group.members.some((m) => m.equals(req.user!._id as any))) {
      return res.status(403).json({ message: 'Not a member of this group' });
    }

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
