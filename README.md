# SafeHer

**SafeHer** is an AI-enabled women's safety mobile app — one-tap SOS alerts,
live location sharing, a fake-call escape tool, a safety chatbot, nearby
police/hospital/NGO lookup, and more. Built with Flutter so a single
codebase targets Android, iOS, and web.

This repo currently contains the **complete frontend** — every screen in the
app is built, styled to the project's Figma design, and fully navigable.
There is **no backend yet**: data is local/mock for now, and a few features
(maps, geocoding, nearby-places search) already call free public APIs
directly from the client. Each of the 9 feature modules below has a working
UI shell ready for its owner to wire up real logic, storage, and backend
calls — that's the next phase of this project.

Team: 9 members, one module each (see the ownership table below).

## How to use this repo (for teammates)

### 1. Prerequisites

- Install the Flutter SDK (3.44+, which includes Dart 3.12+): https://docs.flutter.dev/get-started/install
- Run `flutter doctor` and resolve anything it flags before continuing
- An editor with Flutter support — VS Code (with the Flutter extension) or Android Studio both work
- To run on a phone/emulator: Android Studio (for an Android emulator) and/or Xcode on a Mac (for iOS Simulator). To just preview in a browser, none of that is required — see below.

### 2. Get the code running

```bash
git clone <this-repo-url>
cd safe_her
flutter pub get      # installs all dependencies
flutter devices      # see what you can run on
flutter run          # launches on whatever device/emulator is connected
```

Fastest way to preview with no emulator setup at all:

```bash
flutter run -d chrome
```

No API keys, `.env` file, or backend setup are needed to run the app as-is
— everything it currently talks to (map tiles, geocoding, nearby-places
search) is a free, keyless public API. See "Free services already wired up"
below before you add a paid one.

### 3. Find your module

Check the **module ownership map** below for the folder(s) with your name
on it (by module number), open that screen, and start replacing the mock
data / adding the real logic. Shared building blocks (buttons, text fields,
the map widget, colors) already exist — reuse them instead of styling from
scratch, see "Design system" below.

### 4. Before you commit

```bash
dart format lib/
flutter analyze     # must report "No issues found!"
```

Keep commits scoped to your module where possible, and open a PR against
`main` rather than pushing straight to it once there's more than one of us
committing. Mention which module # your PR is for in the description.

## Project structure

```
lib/
  main.dart                  # App entry point, theme
  theme/app_theme.dart       # Colors, text styles, radii — the design system
  widgets/                   # Shared components (buttons, nav bar, map, text field...)
  services/                  # Free API clients (location, geocoding)
  screens/
    splash_screen.dart
    onboarding/               Module 1 (partial)
    auth/                     Module 1
    home/                     shell + dashboard
    tracking/                 Module 4
    sos/                      Module 3
    contacts/, nearby_help/   Module 2
    safe_route/               Module 5
    behavior/                 Module 6
    evidence/                 Module 7
    fake_call/, chatbot/      Module 8
    report/, history/         Module 9 (mobile half)
    profile/, settings/       cross-cutting settings
```

## Module ownership map

Use this to find where your module's screens live and what's already there
vs. what you need to build.

| # | Module | Screens (path under `lib/screens/`) | Status |
|---|---|---|---|
| 1 | **Auth & Profile** | `auth/signup_screen.dart`, `auth/login_screen.dart`, `auth/profile_setup_screen.dart`, `profile/edit_profile_screen.dart`, `profile/profile_tab.dart` | Real Firebase Auth (email/password) + Firestore `users/{uid}` doc, wired end to end including Profile tab/Edit Profile. Setup's "Add from Contacts" imports real device contacts (`flutter_contacts`) as emergency contacts. |
| 2 | **Contacts & Nearby Services** | `contacts/contacts_screen.dart`, `contacts/contact_picker_screen.dart`, `nearby_help/nearby_help_screen.dart` | Contacts are Firestore-persisted (`users/{uid}/contacts`) with a 5-contact cap, plus "Import from Contacts" to pull from the device address book. Nearby Help calls the free Overpass API for real police/hospital/NGO pins (with a cached/static fallback), and its Call buttons open the dialer. |
| 3 | **SOS Trigger & Alerts** | `sos/sos_screen.dart` | Shake-to-trigger + hold-to-arm, real contact alerting (WhatsApp deep link, SMS fallback, and direct phone calls), real Police/Ambulance call buttons, and auto-recorded encrypted audio evidence on trigger (see Module 7). |
| 4 | **Live GPS Tracking** | `tracking/live_tracking_tab.dart`, `tracking/start_journey_sheet.dart`, `tracking/pick_location_screen.dart` | Real GPS (`geolocator`), real destination search/pin (`Nominatim`) and real road routing (OSRM). Geofence "left the safe zone" and Auto Safe Arrival are both real, one-shot-per-session distance checks (`services/geofence_service.dart`). |
| 5 | **Safe Route & Risk Zones** | `safe_route/safe_route_screen.dart`, `tracking/select_route_screen.dart` | Real scoring (`services/safety_score_service.dart`) — live OSM police-station + street-lamp density near each zone/route, discounted at night. Zone *positions* are still a fixed offset pattern around the user (no free source for real neighborhood boundaries exists). |
| 6 | **AI Behavior Detection** | `behavior/behavior_monitor_screen.dart` | Real accelerometer-based classification (`services/motion_classifier.dart`) — running, sudden-stop, and free-fall-then-impact (possible fall) patterns from live sensor data, unit-tested. No cloud/ML model, just magnitude thresholds. |
| 7 | **Evidence Recording & Storage** | `evidence/evidence_screen.dart`, `evidence/evidence_viewer_screen.dart` | Real audio/photo/video capture, AES-256-GCM encrypted at rest (`services/encryption_service.dart`, key in the OS keystore) — plaintext never touches disk outside a transient view session. Viewing any entry requires the device's biometric/PIN lock (`services/biometric_service.dart`). Local-only by design — no Firebase Storage (would require the paid Blaze plan). |
| 8 | **Fake Call & AI Chatbot** | `fake_call/fake_call_screen.dart`, `fake_call/incoming_call_screen.dart`, `chatbot/chatbot_screen.dart` | Both fully functional as local features (no backend needed). Chatbot is rule-based (`_knowledgeBase` in `chatbot_screen.dart`) — extend the keyword map or swap in a real NLP service. |
| 9 | **Incident Reporting, Timeline & Admin Dashboard** | `report/report_screen.dart`, `history/history_tab.dart` | Both real and Firestore-backed via `services/incident_service.dart` (reports, SOS alerts, and geofence/arrival safety events all land in the same `incidents` collection History reads from). **Admin web dashboard is not part of this Flutter app** — per the original plan it's a separate web project (Flutter Web/React) reading the same Firestore `incidents` collection; start that as its own app. |

## Free services already wired up

No paid API keys are used anywhere in the app:

- **Maps** — OpenStreetMap tiles via `flutter_map` (`lib/widgets/app_map.dart`)
- **Device location** — `geolocator` (`lib/services/location_service.dart`), falls back to a Dhanmondi, Dhaka coordinate if permission is denied
- **Destination search / reverse geocoding** — OSM Nominatim, no key (`lib/services/geocoding_service.dart`) — please respect Nominatim's 1 req/sec usage policy; don't hammer it in a loop
- **Nearby police/hospital/NGO data** — OSM Overpass API (`lib/screens/nearby_help/nearby_help_screen.dart`)

If a module needs its own backend (Firebase, a custom API, etc.), add it as
its own service in `lib/services/` and keep the free-tier/local-mock path as
a fallback where practical, matching the pattern above.

## Suggested shared backend schema

Per the original planning doc, agree on this Firestore structure **before**
wiring real persistence, so modules don't collide:

- `users` — profile, medical info (Module 1)
- `contacts` — subcollection under `users` (Module 2)
- `incidents` — SOS alerts + reports, used by History and the future Admin Dashboard (Modules 3, 9)
- `recordings` — evidence metadata (Module 7)

## Design system

`lib/theme/app_theme.dart` holds every color, radius, and text style used in
the app (`AppColors`, `AppRadius`, `AppTextStyles`). Reuse these instead of
hardcoding — it keeps new screens visually consistent with the rest of the
app. Shared building blocks live in `lib/widgets/`:  `PrimaryButton`,
`AppTextField`, `ActionCard`, `AppMap`, `BottomNavBar`, `ScreenHeader`.

## Known gaps / good first tasks

- No backend/persistence anywhere yet — everything resets on app restart
- Contacts, History, and Evidence lists are all in-memory mock data
- SOS trigger doesn't actually send SMS or place a call
- Live Tracking route is a straight line, not a real road route
- Android and iOS location/internet permissions are already declared
  (`android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`)

## Questions

Ping the team lead (repo owner) if you're blocked on which module owns a
piece of shared code, or want to change something in `lib/widgets/` or
`lib/theme/` that other modules depend on — those are shared, so changes
there affect everyone's screens.
