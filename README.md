# SafeHer

An AI-enabled women's safety app. This repo currently contains the **complete
Flutter frontend** — every screen in the app is built and navigable. There is
**no backend yet**: all data is local/mock, and a few features (maps,
geocoding) call free public APIs directly from the client. Each of the 9
feature modules below has a working UI shell ready for its owner to wire up
real logic, storage, and backend calls.

## Getting started

```bash
flutter pub get
flutter run                       # pick a connected device/emulator
flutter run -d chrome             # or run in a browser
```

Requires Flutter 3.44+ (Dart 3.12+). No API keys are needed for anything
currently in the app (see "Free services already wired up" below).

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
| 1 | **Auth & Profile** | `auth/phone_entry_screen.dart`, `auth/otp_screen.dart`, `auth/profile_setup_screen.dart`, `profile/edit_profile_screen.dart`, `profile/profile_tab.dart` | UI done, mock OTP/save. Needs Firebase Auth + Firestore user doc. |
| 2 | **Contacts & Nearby Services** | `contacts/contacts_screen.dart`, `nearby_help/nearby_help_screen.dart` | UI done. Contacts are in-memory (no persistence yet). Nearby Help already calls the free Overpass API for real police/hospital/NGO pins, with a static fallback list. |
| 3 | **SOS Trigger & Alerts** | `sos/sos_screen.dart` | UI + shake-to-trigger (`sensors_plus`) + hold-to-arm gesture done. SMS/call/push on trigger are **not wired** — `_startCountdown`/sent state is where to hook those in. |
| 4 | **Live GPS Tracking** | `tracking/live_tracking_tab.dart`, `tracking/start_journey_sheet.dart`, `tracking/pick_location_screen.dart` | UI done with **real GPS** (`geolocator`) and **real destination search/pin** (`Nominatim`). Route is a straight line — swap in OSRM for real routing. Geofence toggle is UI-only. |
| 5 | **Safe Route & Risk Zones** | `safe_route/safe_route_screen.dart` | UI shell only — risk zones are mock `CircleMarker`s. Replace `_mockZones` with a real scoring service. |
| 6 | **AI Behavior Detection** | `behavior/behavior_monitor_screen.dart` | UI shell only — toggle + mock activity log. Feed real accelerometer data (`sensors_plus`, already a dependency) into a TFLite classifier here. |
| 7 | **Evidence Recording & Storage** | `evidence/evidence_screen.dart` | UI shell only — list is mock data. Wire `camera`/`record` plugins + cloud upload (Firebase Storage / S3); the SOS screen's REC badge (`sos_screen.dart`) already has a hook to auto-start recording. |
| 8 | **Fake Call & AI Chatbot** | `fake_call/fake_call_screen.dart`, `fake_call/incoming_call_screen.dart`, `chatbot/chatbot_screen.dart` | Both fully functional as local features (no backend needed). Chatbot is rule-based (`_knowledgeBase` in `chatbot_screen.dart`) — extend the keyword map or swap in a real NLP service. |
| 9 | **Incident Reporting, Timeline & Admin Dashboard** | `report/report_screen.dart`, `history/history_tab.dart` | Report form UI done (no submission backend). History is mock data — replace `_entries` with a real Firestore query. **Admin web dashboard is not part of this Flutter app** — per the original plan it's a separate web project (Flutter Web/React) reading the same Firestore `incidents` collection; start that as its own app. |

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
