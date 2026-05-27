import mongoose, { Document, Schema } from 'mongoose';

export interface IReaction {
  userId: mongoose.Types.ObjectId;
  emoji: string;
}

export interface ICheckIn extends Document {
  userId: mongoose.Types.ObjectId;
  goalId: mongoose.Types.ObjectId;
  date: Date;
  completed: boolean;
  note: string;
  reactions: IReaction[];
  createdAt: Date;
  updatedAt: Date;
}

const checkInSchema = new Schema<ICheckIn>({
  userId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
  goalId: { type: Schema.Types.ObjectId, ref: 'Goal', required: true },
  date: { type: Date, required: true }, // The day of the check-in (normalized to midnight)
  completed: { type: Boolean, required: true, default: false },
  note: { type: String, default: '' },
  reactions: [{
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    emoji: { type: String, required: true },
  }],
}, {
  timestamps: true
});

// Ensure a user can only have one check-in per goal per day
checkInSchema.index({ userId: 1, goalId: 1, date: 1 }, { unique: true });

export const CheckIn = mongoose.model<ICheckIn>('CheckIn', checkInSchema);
