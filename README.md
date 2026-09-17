# SafeHer Admin

The web Admin Dashboard for [SafeHer](../SafeHerApp/safe_her) — a separate
Flutter **Web** app, as the original project plan always scoped it, reading
the *same* Firestore project (`safeher-206b6`) the mobile app writes to.
There is no backend of its own: no Cloud Functions, no server, no service
account. Every screen is a plain Firestore client query, exactly like the
mobile app, just reading across all users instead of one — access control
is enforced entirely by Firestore Security Rules (see below), consistent
with this whole project's zero-cost constraint (Cloud Functions need the
paid Blaze plan, same reason evidence storage stayed on-device).

## What's here

| Screen | Reads | Covers from the original requirement doc |
|---|---|---|
| Overview | `incidents`, `users`, `live_sessions` | "Incident analytics", summary stats, a 14-day incident chart, by-type breakdown |
| Reports & SOS Activity | `incidents` | "Reports", "SOS activities" — same collection, filterable by type (SOS / automatic safety event / report) and free-text search |
| Users | `users` | "User management" |
| Live Tracking | `live_sessions` (active only) | "Response monitoring" — who's currently sharing a live journey, with a staleness indicator if their location hasn't updated in 15+ minutes |

"Crime hotspot visualization" and "Application health monitoring" from the
original doc aren't built here: the former needs a real crime-data source
this project has never had access to (see the mobile app's
`PROJECT_REPORT.md`, Module 5), and the latter — uptime/error monitoring —
is already covered natively by the Firebase Console itself for a
Firestore-only backend; rebuilding it here would just duplicate that.

## One-time setup

Three things need doing before this app will actually run, in order:

### 1. Register a Web app on the Firebase project

`safeher-206b6` currently only has Android and iOS apps registered — no
Web app exists yet, so `lib/firebase_options.dart` is a **placeholder**.
Either:

- Firebase Console → `safeher-206b6` → Project settings → **Add app** →
  Web → copy the generated config values into
  `lib/firebase_options.dart`'s `web` block, or
- if whoever has Firebase CLI access runs `firebase login` then
  `flutterfire configure` from this directory, which does the same thing
  automatically.

### 2. Deploy the updated Firestore rules

`firestore.rules` in the mobile app's repo (`SafeHerApp/safe_her/`) now
has an `isAdmin()` check gating broader reads on `incidents`,
`users`, and `live_sessions` for anyone listed in a new `admins`
collection. Deploy it from that project:

```bash
cd ../SafeHerApp/safe_her
firebase deploy --only firestore:rules
```

### 3. Add yourself as the first admin

There's deliberately no in-app "become an admin" flow — `admins/{uid}`
can only be written by hand in the Firebase Console, never by a client
(see the rule's comment). To bootstrap the first admin:

1. Sign in once on the **mobile app** (or this app, once step 1 is done)
   with the account that should be an admin, and copy its UID from
   Firebase Console → Authentication → Users.
2. Firebase Console → Firestore Database → Data → **Start collection** →
   collection ID `admins` → document ID = that UID → add any field (e.g.
   `role: "admin"`) → Save.
3. From then on, any existing admin can add more admins the same way —
   or you can extend this app with an admin-management screen later,
   since an admin can already read the `admins/{their own uid}` doc (see
   the rule) and the pattern is straightforward to extend to writes if
   the team wants a UI for it.

## Running it

```bash
flutter pub get
flutter run -d chrome
```

## Deploying it

Firebase Hosting's free tier doesn't require the Blaze plan (unlike
Storage/Functions), so it's a safe, genuinely free place to put this:

```bash
flutter build web
firebase deploy --only hosting
```

(Needs a `firebase.json` hosting target pointing at `build/web` — set that
up with `firebase init hosting` from this directory if it isn't there
yet, or host it on any other static host, e.g. Netlify/Vercel's free
tiers, which work just as well for a static Flutter Web build.)
