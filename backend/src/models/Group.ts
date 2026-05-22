import mongoose, { Document, Schema } from 'mongoose';

export interface IGroup extends Document {
  name: string;
  inviteCode: string;
  adminId: mongoose.Types.ObjectId;
  members: mongoose.Types.ObjectId[];
  createdAt: Date;
  updatedAt: Date;
}

const groupSchema = new Schema<IGroup>({
  name: { type: String, required: true },
  inviteCode: { type: String, required: true, unique: true },
  adminId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
  members: [{ type: Schema.Types.ObjectId, ref: 'User' }],
}, {
  timestamps: true
});

export const Group = mongoose.model<IGroup>('Group', groupSchema);
