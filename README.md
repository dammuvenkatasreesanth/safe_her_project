# SafeHer Admin Dashboard

The web admin dashboard for **SafeHer**, the women's-safety mobile app
(repo: `safe_her_project`, branch `complete-integration`).

It is a separate **Flutter Web** app that reads the **same Firebase project**
(`safeher-206b6`) the mobile app writes to. Every SOS alert, incident report,
automatic safety event and live-tracking session created on a user's phone
appears here in real time, across all users.

```
Mobile app (SOS / report / live tracking)  ──writes──►  Cloud Firestore (safeher-206b6)
                                                                │
                                            Admin dashboard ◄───┘  reads (admins only)
```

The dashboard stores nothing itself. If it is not connected to Firebase it
shows nothing and will not start. Connecting it is step 1 of the setup below.

---

## Table of contents

1. [Features](#features)
2. [Architecture and security model](#architecture-and-security-model)
3. [One-time setup](#one-time-setup)
4. [Running locally](#running-locally)
5. [Building and deploying](#building-and-deploying)
6. [Firestore data it reads](#firestore-data-it-reads)
7. [Project structure](#project-structure)
8. [Troubleshooting](#troubleshooting)
9. [Known limitations and scope](#known-limitations-and-scope)

---

## Features

### 1. Sign-in and admin gate
- Email/password sign-in using the same Firebase Auth accounts as the mobile app.
- After signing in, the app checks that a document exists at `admins/{your uid}`.
  Signed in but not an admin means an "access denied" screen with a sign-out button.
- The check re-runs on every page reload, so a persisted browser session is
  re-validated rather than trusted.
- The real enforcement is in Firestore security rules (see the
  [security model](#architecture-and-security-model)). The client-side check
  only provides a clear message.

### 2. Overview
A live snapshot across all users:
- Stat cards: registered users, total incidents, SOS alerts in the last 24 hours,
  open/emergency incidents, active live-tracking sessions.
- Bar chart: incidents per day over the last 14 days.
- Pie chart: breakdown by type (SOS / automatic safety events / reports).

### 3. Reports and SOS Activity
One table for every record in the `incidents` collection, newest first.
- Filter chips: **All / SOS / Safety events / Reports**.
- Free-text search across title, description, reporter UID and location label.
- Columns: time, type badge, title, reporter UID, location, status badge
  (Emergency / Resolved / Cancelled).
- "Safety events" are automatic events the mobile app logs without the user
  pressing anything (for example "Left Safe Zone" from geofencing, or "Arrived
  Home Safely"). They share `type: sos` in Firestore and are told apart by
  their title.

### 4. Users
- Searchable table of every registered account: name, email, blood group,
  profile-complete flag, join date, UID.

### 5. Live Tracking
- Card per user currently sharing a live journey (`status == 'active'`): who,
  destination, vehicle number, how many contacts are watching.
- Each card shows when the location last updated and turns amber if it is more
  than 15 minutes stale (the phone may have lost signal or the app was closed).

All screens update live through Firestore streams, with no refresh button.

---

## Architecture and security model

**No backend.** The dashboard is a plain Firestore client, exactly like the
mobile app, that happens to read across all users. There is no server, service
account or Cloud Function. This matches the project's zero-cost constraint,
because Cloud Functions require the paid Firebase Blaze plan.

**Access control lives in Firestore Security Rules**, not in app code. The
rules in the mobile repo (`firestore.rules`) define:

```
function isAdmin() {
  return request.auth != null &&
    exists(/databases/$(database)/documents/admins/$(request.auth.uid));
}
```

A user is an admin if and only if a document exists at `admins/{their uid}`.
That document is created by hand in the Firebase Console. The rules forbid any
client from writing to `admins`, so nobody can promote themselves.

| Collection | Normal user | Admin |
|---|---|---|
| `incidents` | only their own | all |
| `users` | only their own profile | all |
| `live_sessions` | own and shared-with | all |
| `users/{uid}/contacts` | own only | **no access** |
| `admins/{uid}` | read own doc only | read own doc only |

Trusted contacts (phone numbers) are deliberately not admin-readable. That is
the user's private data and the dashboard does not need it.

---

## One-time setup

Complete these three steps once, in order. Prerequisites: Flutter SDK
(stable), Chrome, and access to the Firebase project `safeher-206b6`.

### Step 1: Register a Web app on the Firebase project

The project currently has Android and iOS apps only, so
`lib/firebase_options.dart` contains placeholders.

1. Firebase Console → project `safeher-206b6` → ⚙ **Project settings** → **General**.
2. Under **Your apps**, click **Add app** and choose the **Web** icon (`</>`).
3. Give it a nickname such as "SafeHer Admin" and click **Register app**
   (skip the Hosting checkbox).
4. Copy the `firebaseConfig` values shown.
5. In `lib/firebase_options.dart`, replace `REPLACE_WITH_WEB_API_KEY` with your
   `apiKey` and `REPLACE_WITH_WEB_APP_ID` with your `appId`. The other fields
   (`projectId`, `authDomain`, `messagingSenderId`, `storageBucket`) are already
   correct for `safeher-206b6`.

Alternative: run `firebase login` and then `flutterfire configure` in this
directory to generate the file automatically.

### Step 2: Publish the Firestore rules

Without the `isAdmin()` rules, sign-in works but every query fails with
`permission-denied`.

- **Console (no CLI needed):** Firestore Database → **Rules** tab → paste the
  full contents of `firestore.rules` from the mobile repo → **Publish**.
- **CLI:** from the mobile app project, run
  `firebase deploy --only firestore:rules`.

### Step 3: Make yourself an admin

1. Get your user UID. Create an account in the mobile app, or use Firebase
   Console → **Authentication** → **Users** → add a user, then copy the
   **User UID**.
2. Firebase Console → **Firestore Database** → **Data** → **Start collection**.
3. Collection ID: `admins`. Document ID: your UID. Add any field, for example
   `role` = `admin`. Save.

To add more admins later, repeat step 3 with their UIDs.

---

## Running locally

```bash
git clone https://github.com/dammuvenkatasreesanth/safe_her_project.git
cd safe_her_project
git checkout admin-dashboard        # this branch holds the admin project

flutter pub get
flutter run -d chrome
```

Sign in with the email and password of the account you made an admin in step 3.

The dashboard only shows data that already exists. A fresh database shows
zeros. To see it work, use the mobile app (pointed at the same
`safeher-206b6` project) to press SOS, file a report, or start a live journey.
The dashboard updates immediately.

Run the tests and static analysis with:

```bash
flutter analyze
flutter test
```

---

## Building and deploying

```bash
flutter build web
```

The output is a static site in `build/web/`. Host it anywhere static files are
served. Firebase Hosting's free tier works without the Blaze plan:

```bash
firebase init hosting     # public directory: build/web, single-page app: yes
firebase deploy --only hosting
```

Netlify and Vercel free tiers also work.

**After deploying**, add the site's domain in Firebase Console →
Authentication → Settings → **Authorized domains**, or sign-in will fail on the
deployed site. `localhost` is already authorized for local runs.

---

## Firestore data it reads

**`incidents/{id}`**: written by the mobile app for reports, SOS alerts and
safety events.
`reporterId`, `type` (`sos` | `report`), `status` (`emergency` | `resolved` |
`cancelled`), `title`, `subtitle`, `createdAt`, and optionally `reportCategory`,
`description`, `locationLabel`, `locationLatLng {lat, lng}`, `hasPhoto`.

**`users/{uid}`**: profile.
`uid`, `email`, `fullName`, `bloodGroup`, `profileComplete`, `createdAt`.

**`live_sessions/{id}`**: active/ended journeys.
`ownerId`, `ownerName`, `status` (`active` | `ended`), `destinationLabel`,
`vehicleNumber`, `startTime`, `sharedWithUserIds[]`,
`lastLocation {lat, lng, updatedAt}`.

**`admins/{uid}`**: the allowlist. Presence of the document is what matters.

Photos and audio/video evidence are **not** available to the admin. Evidence
is stored encrypted on each user's own device and never uploaded, by design.
The `hasPhoto` flag on a report only says that one was attached.

---

## Project structure

```
lib/
├── main.dart                      Firebase init + auth/admin gate
├── firebase_options.dart          Web config (placeholder until step 1)
├── theme.dart                     Brand colours and Material theme
├── models/
│   ├── incident.dart              incidents/{id}
│   ├── app_user.dart              users/{uid}
│   └── live_session.dart          live_sessions/{id}
├── services/
│   ├── admin_auth_service.dart    Sign-in and admins/{uid} check
│   └── admin_data_service.dart    Firestore streams (read-only)
└── screens/
    ├── login_screen.dart
    ├── dashboard_shell.dart       Sidebar navigation
    ├── overview_screen.dart       Stats and charts
    ├── incidents_screen.dart      Reports and SOS table
    ├── users_screen.dart
    └── live_sessions_screen.dart
```

Dependencies: `firebase_core`, `firebase_auth`, `cloud_firestore`,
`fl_chart` (charts), `intl` (date formatting), `provider`.

---

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| Blank page, console error about Firebase / `REPLACE_WITH...` | Step 1 not done. Fill in `apiKey` and `appId`. |
| "This account is not an admin" | Step 3 not done, or the `admins` document ID doesn't exactly match the UID. |
| Signed in, but screens show "permission-denied" | Step 2 not done. Publish the updated Firestore rules. |
| Everything loads but all counts are 0 | Correct, the database is empty. Create data from the mobile app, and confirm both apps use project `safeher-206b6`. |
| `invalid-credential` on sign-in | Wrong email or password. Accounts are shared with the mobile app. |
| Works locally, fails after deploying | Add the deployed domain under Authentication → Settings → Authorized domains. |
| Users or incidents seem missing | Lists are capped (200 newest incidents, 500 newest users) to keep reads cheap. |

---

## Known limitations and scope

Not built here, with reasons:

- **Crime-hotspot visualization.** This needs a real crime-data source, which
  this project has never had access to. The mobile app's safe-route scoring uses
  a live police-station and street-lamp density heuristic instead.
- **Application health monitoring.** Uptime and error monitoring for a
  Firestore-only backend is already provided by the Firebase Console.
- **Resolving or editing incidents from the dashboard.** The dashboard is
  read-only by design, and the security rules do not allow incident updates.
  Adding a status workflow would need a rules change plus a write path.
- **Viewing user evidence or contacts.** Intentionally out of scope for privacy.
- **Not yet verified against live Firebase.** The code passes `flutter analyze`
  and its tests, but it has not been run against the live project because the
  Web app registration (step 1) hasn't been done. Expect to fix small
  integration issues on first connection.
