import { randomBytes } from 'crypto';
import { User, IUser } from '../models/User';
import { Group, IGroup } from '../models/Group';
import { Goal, IGoal } from '../models/Goal';
import { CheckIn } from '../models/CheckIn';
import { Message } from '../models/Message';

// Fixed identity for the shared demo account. Every demo-owned document is
// reachable by walking Group.find({ adminId: demoUser._id }) — createGroup
// always sets adminId to the creator's own id and nothing ever transfers it,
// so this scoping is safe and needs no extra "isDemo" flag.
export const DEMO_EMAIL = 'demo@ritual.app';
const DEMO_USER_NAME = 'Alex Demo';
const DEMO_USER_CONSISTENCY = 0.8;

const HISTORY_DAYS = 90;
const CHAT_WINDOW_DAYS = 18;

interface PersonaSpec {
  email: string;
  name: string;
  consistency: number; // used only to shape generated data, never stored
}

const PERSONAS: PersonaSpec[] = [
  { email: 'demo.priya@ritual.app', name: 'Priya Sharma', consistency: 0.85 },
  { email: 'demo.rohan@ritual.app', name: 'Rohan Mehta', consistency: 0.55 },
  { email: 'demo.sara@ritual.app', name: 'Sara Khan', consistency: 0.75 },
  { email: 'demo.dev@ritual.app', name: 'Dev Patel', consistency: 0.9 },
  { email: 'demo.meera@ritual.app', name: 'Meera Iyer', consistency: 0.6 },
];

interface GroupSpec {
  name: string;
  memberEmails: string[]; // personas, in addition to the demo user (always admin)
  goals: { name: string; icon: string; weeklyMinimum: number }[];
}

const GROUP_SPECS: GroupSpec[] = [
  {
    name: 'Gym Buddies',
    memberEmails: ['demo.rohan@ritual.app'],
    goals: [
      { name: 'Gym', icon: '🏋️', weeklyMinimum: 4 },
      { name: 'Eat Clean', icon: '🥗', weeklyMinimum: 5 },
    ],
  },
  {
    name: 'Weekend Warriors',
    memberEmails: [
      'demo.priya@ritual.app',
      'demo.sara@ritual.app',
      'demo.dev@ritual.app',
      'demo.meera@ritual.app',
    ],
    goals: [
      { name: 'Run', icon: '🏃', weeklyMinimum: 3 },
      { name: 'Hydrate', icon: '💧', weeklyMinimum: 7 },
      { name: 'Meditate', icon: '🧘', weeklyMinimum: 4 },
    ],
  },
  {
    name: 'My Rituals',
    memberEmails: [],
    goals: [
      { name: 'Journal', icon: '📓', weeklyMinimum: 5 },
      { name: 'Sleep by 11', icon: '🌙', weeklyMinimum: 6 },
    ],
  },
];

const NOTES = [
  'Felt great today 💪',
  'Tough one but done',
  'Back on track!',
  'Small win, still counts',
  "Almost skipped this but glad I didn't",
  'Easy one today',
  'Pushed through, feeling good',
];

const REACTION_EMOJIS = ['🔥', '👏', '💪', '❤️', '💯'];

const CHAT_LINES: Record<string, string[]> = {
  'Gym Buddies': [
    'Hitting the gym at 6, you in?',
    'Ugh missed leg day, tomorrow for sure',
    "Let's not skip this week 🙏",
    'That was brutal but worth it',
    'New PR today!',
    'Struggling to keep up ngl',
    "You've got this, one day at a time",
    'Meal prepped for the week, feeling good',
  ],
  'Weekend Warriors': [
    'Morning run was 🔥 today',
    "Who's up for a group run this weekend?",
    'Meditation app recommendations?',
    'Water bottle count: 6/8 so far',
    'Great job everyone this week!',
    'Feeling behind, need to catch up',
    "Loving this streak we've got going",
    'Rest day for me, back at it tomorrow',
    'Anyone else struggling with the hydration goal 😅',
    "Let's keep the momentum going!",
  ],
};

interface Member {
  user: IUser;
  consistency: number;
}

interface GroupBundle {
  spec: GroupSpec;
  group: IGroup;
  goals: IGoal[];
  members: Member[];
}

function pick<T>(arr: T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}

function dayNDaysAgo(base: Date, daysAgo: number): Date {
  const d = new Date(base);
  d.setUTCDate(d.getUTCDate() - daysAgo);
  d.setUTCHours(0, 0, 0, 0);
  return d;
}

function randomTimeOnDay(dayStart: Date): Date {
  const d = new Date(dayStart);
  d.setUTCHours(
    6 + Math.floor(Math.random() * 16),
    Math.floor(Math.random() * 60),
    Math.floor(Math.random() * 60),
    Math.floor(Math.random() * 1000)
  );
  return d;
}

async function findOrCreatePersonaUser(email: string, name: string): Promise<IUser> {
  let user = await User.findOne({ email });
  if (!user) {
    user = await User.create({
      name,
      email,
      profileImage: `https://api.dicebear.com/7.x/avataaars/png?seed=${encodeURIComponent(name)}`,
    });
  }
  return user;
}

async function findOrCreateGroup(name: string, adminId: any, memberIds: any[]): Promise<IGroup> {
  let group = await Group.findOne({ adminId, name });
  if (!group) {
    group = await Group.create({
      name,
      inviteCode: randomBytes(3).toString('hex').toUpperCase(),
      adminId,
      members: memberIds,
    });
  } else {
    const existing = new Set(group.members.map((m: any) => m.toString()));
    const wanted = new Set(memberIds.map((m: any) => m.toString()));
    const same = existing.size === wanted.size && [...wanted].every((id) => existing.has(id));
    if (!same) {
      group.members = memberIds;
      await group.save();
    }
  }
  return group;
}

async function findOrCreateGoal(
  groupId: any,
  spec: { name: string; icon: string; weeklyMinimum: number }
): Promise<IGoal> {
  let goal = await Goal.findOne({ groupId, name: spec.name });
  if (!goal) {
    goal = await Goal.create({
      groupId,
      name: spec.name,
      icon: spec.icon,
      weeklyMinimum: spec.weeklyMinimum,
    });
  }
  return goal;
}

// Hand-scripted outcome for "today" (daysAgo=0) and "yesterday" (daysAgo=1),
// so the very first thing a viewer sees is a legible, interesting state
// rather than whatever pure randomness happened to land on — some done,
// some pending, at least one visible "waiting on" moment.
function scriptedOutcome(
  groupName: string,
  goalName: string,
  member: Member,
  daysAgo: number,
  isDemo: boolean
): boolean {
  if (groupName === 'Gym Buddies') {
    if (daysAgo === 0) {
      // Demo user has done Gym but not Eat Clean; Rohan hasn't done either —
      // a live "waiting on" state, and demonstrates the at-risk weak link.
      return isDemo && goalName === 'Gym';
    }
    // Yesterday: both did Gym; only the demo user also did Eat Clean.
    if (goalName === 'Gym') return true;
    return isDemo;
  }

  if (groupName === 'Weekend Warriors') {
    if (daysAgo === 0) {
      if (isDemo) return goalName !== 'Meditate';
      return member.consistency >= 0.75 ? goalName !== 'Hydrate' : goalName === 'Hydrate';
    }
    if (isDemo) return true;
    return member.consistency >= 0.6;
  }

  // My Rituals (solo) — mostly on track; Sleep slightly behind pace today.
  if (daysAgo === 0) return goalName === 'Journal';
  return true;
}

async function regenerateCheckIns(
  groupDocs: GroupBundle[],
  demoUserId: string,
  todayUTC: Date
) {
  const docs: any[] = [];
  const seen = new Set<string>();

  for (const { spec, goals, members } of groupDocs) {
    for (const goal of goals) {
      for (const member of members) {
        for (let i = HISTORY_DAYS - 1; i >= 0; i--) {
          const dayStart = dayNDaysAgo(todayUTC, i);
          const isDemo = member.user._id.toString() === demoUserId;

          const completed =
            i <= 1
              ? scriptedOutcome(spec.name, goal.name, member, i, isDemo)
              : Math.random() < member.consistency;

          if (!completed) continue;

          const key = `${member.user._id}|${goal._id}|${dayStart.toISOString()}`;
          if (seen.has(key)) continue;
          seen.add(key);

          const doc: any = {
            userId: member.user._id,
            goalId: goal._id,
            date: dayStart,
            completed: true,
            note: '',
            reactions: [],
            createdAt: randomTimeOnDay(dayStart),
          };

          if (Math.random() < 0.12) {
            doc.note = pick(NOTES);
          }
          const others = members.filter(
            (m) => m.user._id.toString() !== member.user._id.toString()
          );
          if (others.length > 0 && Math.random() < 0.2) {
            doc.reactions = [{ userId: pick(others).user._id, emoji: pick(REACTION_EMOJIS) }];
          }

          docs.push(doc);
        }
      }
    }
  }

  if (docs.length === 0) return;
  try {
    await CheckIn.insertMany(docs, { ordered: false });
  } catch (err: any) {
    // Any duplicate-key error here can only be an intra-batch self-collision —
    // this scope was fully deleted right before generation started.
    console.warn('demoSeedService: insertMany reported non-fatal errors:', err.message);
  }
}

async function regenerateChat(groupDocs: GroupBundle[], todayUTC: Date) {
  const docs: any[] = [];

  for (const { spec, group, members } of groupDocs) {
    if (spec.memberEmails.length === 0) continue; // solo group — no one to chat with
    const lines = CHAT_LINES[spec.name];
    if (!lines || lines.length === 0) continue;

    const speakers = members.map((m) => m.user);
    const messageCount = 15 + Math.floor(Math.random() * 11); // 15-25

    const timestamps: Date[] = [];
    for (let m = 0; m < messageCount; m++) {
      const daysAgo = Math.floor(Math.random() * CHAT_WINDOW_DAYS);
      const t = randomTimeOnDay(dayNDaysAgo(todayUTC, daysAgo));
      timestamps.push(t);
    }
    timestamps.sort((a, b) => a.getTime() - b.getTime());

    for (const t of timestamps) {
      docs.push({
        groupId: group._id,
        userId: pick(speakers)._id,
        text: pick(lines),
        createdAt: t,
        updatedAt: t,
      });
    }
  }

  if (docs.length === 0) return;
  await Message.insertMany(docs, { ordered: false });
}

export async function ensureDemoData(): Promise<IUser> {
  const now = new Date();
  const todayUTC = new Date(now);
  todayUTC.setUTCHours(0, 0, 0, 0);
  const todayStr = todayUTC.toISOString().slice(0, 10);

  const demoUser = await findOrCreatePersonaUser(DEMO_EMAIL, DEMO_USER_NAME);
  const personaUsers: Record<string, IUser> = {};
  for (const p of PERSONAS) {
    personaUsers[p.email] = await findOrCreatePersonaUser(p.email, p.name);
  }

  const groupDocs: GroupBundle[] = [];
  for (const spec of GROUP_SPECS) {
    const members: Member[] = [
      { user: demoUser, consistency: DEMO_USER_CONSISTENCY },
      ...spec.memberEmails.map((e) => ({
        user: personaUsers[e],
        consistency: PERSONAS.find((p) => p.email === e)!.consistency,
      })),
    ];
    const memberIds = members.map((m) => m.user._id);
    const group = await findOrCreateGroup(spec.name, demoUser._id, memberIds);
    const goals: IGoal[] = [];
    for (const g of spec.goals) {
      goals.push(await findOrCreateGoal(group._id, g));
    }
    groupDocs.push({ spec, group, goals, members });
  }

  // Atomic freshness claim — the matched (pre-update) doc is returned only
  // when demoSeedDate was stale, so exactly one concurrent request "wins"
  // and does the expensive regeneration; the rest just return the user.
  const claimed = await User.findOneAndUpdate(
    { email: DEMO_EMAIL, demoSeedDate: { $ne: todayStr } },
    { $set: { demoSeedDate: todayStr } }
  );

  if (!claimed) {
    return demoUser;
  }

  const demoGroupIds = groupDocs.map((g) => g.group._id);
  const demoGoalIds = groupDocs.flatMap((g) => g.goals.map((goal) => goal._id));

  await CheckIn.deleteMany({ goalId: { $in: demoGoalIds } });
  await Message.deleteMany({ groupId: { $in: demoGroupIds } });

  await regenerateCheckIns(groupDocs, demoUser._id.toString(), todayUTC);
  await regenerateChat(groupDocs, todayUTC);

  return demoUser;
}
