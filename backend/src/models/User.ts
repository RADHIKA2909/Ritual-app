import mongoose, { Document, Schema } from 'mongoose';

export interface IUser extends Document {
  name: string;
  email: string;
  profileImage?: string;
  googleId?: string;
  // 'YYYY-MM-DD' (UTC) — set only on the demo account, to track when its
  // groups/check-ins were last regenerated. See services/demoSeedService.ts.
  demoSeedDate?: string;
  createdAt: Date;
  updatedAt: Date;
}

const userSchema = new Schema<IUser>({
  name: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  profileImage: { type: String },
  googleId: { type: String, unique: true, sparse: true },
  demoSeedDate: { type: String },
}, {
  timestamps: true
});

export const User = mongoose.model<IUser>('User', userSchema);
