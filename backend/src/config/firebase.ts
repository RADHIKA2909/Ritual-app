import admin from 'firebase-admin';

// ──────────────────────────────────────────────────────────────────────────────
// Firebase Admin SDK — initialized from environment variables so you NEVER
// commit credentials to git.
//
// HOW TO SET UP:
//   1. Go to https://console.firebase.google.com → your project
//   2. Settings (gear icon) → Service Accounts → Generate new private key
//   3. A JSON file downloads. Open it and copy the values into your .env file:
//
//      FIREBASE_PROJECT_ID=your-project-id
//      FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nABC...\n-----END PRIVATE KEY-----\n"
//      FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@your-project-id.iam.gserviceaccount.com
//
//   4. Restart the backend: npm run dev
// ──────────────────────────────────────────────────────────────────────────────

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
    }),
  });
}

export default admin;
