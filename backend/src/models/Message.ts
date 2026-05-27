import mongoose, { Schema, Document } from 'mongoose';

export interface IMessage extends Document {
  groupId: mongoose.Types.ObjectId;
  userId: mongoose.Types.ObjectId;
  text: string;
  createdAt: Date;
}

const MessageSchema = new Schema<IMessage>(
  {
    groupId: { type: Schema.Types.ObjectId, ref: 'Group', required: true },
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    text: { type: String, required: true, maxlength: 500 },
  },
  { timestamps: true }
);

// Index for fast group message queries
MessageSchema.index({ groupId: 1, createdAt: -1 });

export const Message = mongoose.model<IMessage>('Message', MessageSchema);
