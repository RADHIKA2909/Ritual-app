import mongoose, { Document, Schema } from 'mongoose';

export interface IGoal extends Document {
  groupId: mongoose.Types.ObjectId;
  name: string; // e.g. "Gym", "No Junk"
  icon: string; // Emoji e.g. "💪", "🍔"
  weeklyMinimum: number; // e.g. 3 days/week
  createdAt: Date;
  updatedAt: Date;
}

const goalSchema = new Schema<IGoal>({
  groupId: { type: Schema.Types.ObjectId, ref: 'Group', required: true },
  name: { type: String, required: true },
  icon: { type: String, required: true, default: '🎯' },
  // NOTE: streaks are derived on read in services/progressService.ts, never
  // stored. A streakCount field used to be declared here but was never written.
  weeklyMinimum: { type: Number, required: true, min: 1, max: 7 },
}, {
  timestamps: true
});

export const Goal = mongoose.model<IGoal>('Goal', goalSchema);
