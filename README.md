# Santra

**A Flutter and Firebase application for amateur-football teams and players.**

Santra brings team profiles, player listings, match challenges, and notifications into one application. This repository presents my work on the mobile interface and its Firebase backend.

## Application flows

- Account registration, sign-in, email verification, and profile editing.
- Team creation, player profiles, team invitations, and player or team listings.
- Match challenges, match details, score confirmation, and score disputes.
- Notifications for challenges, accepted matches, and score-related events.
- Administrative views for users and listing approval.

## Technology

**Flutter / Dart · Firebase Authentication · Cloud Firestore · Cloud Functions · Firebase Cloud Messaging · Firebase Storage**

Cloud Functions handle operations such as match cancellation, notifications, score confirmation, team statistics, and account administration.

## Code map

| Path | Responsibility |
|---|---|
| `lib/screens/` | Authentication, teams, players, matches, notifications, and admin screens |
| `lib/services/` | Connectivity, email verification, and notification services |
| `functions/index.js` | Firebase backend functions |
| `firestore.rules` | Firestore access rules |
| `firestore.indexes.json` | Firestore query indexes |

## Run locally

Install a Flutter SDK compatible with the repository's dependencies; `pubspec.yaml` declares Dart >=3.4 and <4. The Functions backend targets Node.js 22. Install the Firebase CLI and FlutterFire CLI, then:

```sh
git clone https://github.com/DogacErguvenc/Santra-App.git
cd Santra-App
flutter pub get
flutterfire configure --project YOUR_FIREBASE_PROJECT_ID
cd functions
npm ci
cd ..
```

Use **your own Firebase project** for development:

1. Enable email/password authentication and configure Firestore, Storage, Cloud Messaging, and Android App Check.
2. Generate Flutter and Android client configuration for your project and application identifier using FlutterFire.
3. In `functions/index.js`, replace the `projectId` constant with your own Firebase project ID. The existing backend initialization explicitly uses that constant.
4. Review Firestore access rules, indexes, and service configuration for your environment. Configure App Check debug tokens in your own project for development.

Deploy the backend and Firestore configuration only to your own project:

```sh
firebase deploy --project YOUR_FIREBASE_PROJECT_ID --only functions,firestore
flutter run
```

Android debug builds do not require the private release-signing file. Release signing uses your own `android/key.properties` and keystore; without them, no release signing configuration is applied. Keep signing files outside version control. Release packaging requires a separate review of signing and ProGuard configuration.

The checked-in Firebase client configuration identifies the original project; it is not a server administrator credential. Regenerate configuration and update the backend project ID before running your own copy.

## Project notes

This repository contains application source and backend configuration. It does not establish production readiness or current app-store availability. The existing widget test is a starter example, so it should not be treated as coverage of the application flows. Firebase deployments, Android builds, and device behavior need validation in your own environment.

## About the developer

**Haluk Doğaç Ergüvenç** — Computer Engineering graduate, focused on Python backend, AI applications, and full-stack software development.

[LinkedIn](https://www.linkedin.com/in/haluk-dogac-erguvenc) · [GitHub](https://github.com/DogacErguvenc)
