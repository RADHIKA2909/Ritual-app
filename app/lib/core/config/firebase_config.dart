import 'package:firebase_core/firebase_core.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Firebase Web Configuration
//
// HOW TO FILL THIS IN:
//   1. Go to https://console.firebase.google.com → your project
//   2. Click the gear icon → Project Settings
//   3. Scroll down to "Your apps" → click the Web app (</> icon)
//      (If you haven't added a web app yet, click "Add app" → Web)
//   4. You'll see a firebaseConfig object — copy those values here.
//
// ⚠️ Do NOT commit real credentials to git. For production, use --dart-define.
// ──────────────────────────────────────────────────────────────────────────────

class FirebaseConfig {
  static const FirebaseOptions webOptions = FirebaseOptions(
    apiKey: "AIzaSyDk4lrcekso6lFaOL4RgJ9YaNdER8CT36Y",
    authDomain: "ritual-app-abcd.firebaseapp.com",
    projectId: "ritual-app-abcd",
    storageBucket: "ritual-app-abcd.firebasestorage.app",
    messagingSenderId: "255213242578",
    appId: "1:255213242578:web:b011f15c072752f684450b",
    measurementId: "G-KJF0YX6GQR",
  );
}
