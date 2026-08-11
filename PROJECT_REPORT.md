# SafeHer — Project Report

## Abstract

SafeHer is a women's safety mobile application built in Flutter, designed
around a simple premise: help should be one tap — or one shake, or one
spoken phrase — away. The app is organized into nine functional modules
covering identity and trusted contacts, an SOS alert system, live location
sharing, safety-aware route guidance, on-device anomaly detection, encrypted
evidence capture, a disguised "fake call" escape tool with a rule-based
safety chatbot, and incident reporting with a shared history timeline.

The project was built by a nine-person student team under a hard
constraint: **zero ongoing cost**. Every backend and data source had to run
on free tiers with no billing account attached, which shaped almost every
technical decision documented below — from choosing OpenStreetMap over
Google Maps, to moving off Firebase Storage and phone-OTP authentication
partway through development when both turned out to require a paid Firebase
plan. Rather than treat that as a blocker, each affected module was rebuilt
around an equally real, equally functional free alternative: email/password
authentication instead of SMS OTP, AES-encrypted on-device evidence storage
instead of cloud storage, and live OpenStreetMap/Overpass data instead of
the Google Places API.

Seven of the nine modules (Auth, Contacts & Nearby Help, SOS, Live Tracking,
Safe Routing, Behavior Detection, and Evidence) are backed by real device
sensors, real free APIs, and real Firestore persistence — not UI mockups.
Fake Call and the Safety Chatbot are fully functional local features by
design (no backend needed). Incident Reporting and History are fully real
and Firestore-backed; the one piece explicitly out of scope for this
Flutter codebase is the web Admin Dashboard, which the original project
plan always scoped as a separate web application reading the same Firestore
data — not an oversight, a deliberate split.

What remains unfinished falls into four honest categories, detailed
module-by-module below: capabilities that need a paid service the project
deliberately avoids (cloud evidence backup, verified crime-data feeds, SMS
gateways); capabilities that need real training data nobody on the team has
(a trained ML fall-detection model, in place of the current real-time
threshold-based classifier); capabilities that need Android/iOS background-
service and Play Store policy work beyond what's practical mid-development
(background SOS trigger, silent SMS sending); and the web Admin Dashboard,
which is simply a different project that hasn't been started yet.

---

## How to read this report

For each module: **What it's supposed to do** (the original requirement),
**Technologies used and why**, **What's actually done**, and **What's
missing and why** — the real, specific reason, not a vague "ran out of
time."

---

## Module 1 — Authentication & Profile

**What it's supposed to do:** Let a user create an account, sign in on
future visits, and set up a basic safety profile (name, blood group, at
least one emergency contact) before reaching the rest of the app.

**Technologies used and why:**
- **Firebase Authentication (Email/Password)** — originally built as phone
  number + SMS OTP, which is the more "expected" flow for a safety app.
  Phone auth kept failing in production with `CONFIGURATION_NOT_FOUND`
  errors traced to the Play Integrity/reCAPTCHA verification step, which
  in turn needs every developer's SHA-1/SHA-256 signing fingerprint
  registered against the shared Firebase project and the Play Integrity
  API enabled — a fragile setup to keep in sync across nine people's
  machines, and one that still didn't fully resolve. Email/password needs
  none of that: no per-device fingerprint registration, no SMS quota, no
  Play Integrity dependency, and it works identically for every teammate
  the moment the Firebase console has the provider switched on.
- **Cloud Firestore** (`users/{uid}` document) — the profile store. Chosen
  because it's already the backend for every other module (contacts,
  incidents, live sessions), so there's one database, one security-rules
  file, and one mental model for the whole team instead of mixing in a
  second database just for profiles.
- **flutter_contacts** — reads the phone's own address book so a new user
  can pick emergency contacts by tapping names they already recognize,
  instead of typing phone numbers by hand during signup.
- **Anonymous-session linking** — Module 2 (Contacts) signs every fresh
  install into an anonymous Firebase session immediately so contacts can be
  added before signup finishes; when the user does sign up, that anonymous
  UID is *linked* to the new email/password credential rather than
  discarded, so nothing entered before finishing signup is lost.

**What's done:** Signup and login screens, password reset by email,
Firestore profile document with name/blood group/completion flag, the
anonymous-to-real-account credential linking described above, and a working
"Add from Contacts" flow (this button existed in the UI for a long time
but had no `onTap` handler at all — it's now wired to a real permission-
gated device-contacts picker that saves selections straight to Firestore).

**What's missing and why:**
- **Profile photo upload** — needs a file storage backend. Firebase
  Storage now requires the paid Blaze plan even to stay within its free
  usage limits, which the team isn't taking on (see Module 7 for the full
  reasoning, which applies identically here).
- **Phone number as a second factor** — deprioritized once phone auth was
  dropped as the *primary* method; re-adding it purely as an optional
  second factor was judged not worth reintroducing the Play
  Integrity/SHA-fingerprint fragility for a "nice to have."
- **Branded password-reset emails** — currently uses Firebase's default,
  unbranded email template; a custom domain/branding setup needs a
  verified sending domain, which is a later polish item, not a blocker.

---

## Module 2 — Trusted Contacts & Nearby Help

**What it's supposed to do:** Let a user maintain a short list of trusted
emergency contacts, and show real nearby police stations, hospitals, and
NGOs on a map with one-tap calling and directions.

**Technologies used and why:**
- **Cloud Firestore** (`users/{uid}/contacts` subcollection) — real-time
  sync so a contact added on one screen (or imported from the device
  address book) is instantly visible everywhere else that reads contacts
  (SOS, Live Tracking's share sheet).
- **Overpass API (OpenStreetMap)** — free, keyless, and detailed enough to
  query `amenity=police`, `amenity=hospital`, `office=ngo`, and
  `amenity=social_facility` points within a radius. The realistic paid
  alternative, the Google Places API, requires a billing-enabled API key
  even for its free monthly quota — a non-starter under the project's
  no-cost constraint. Overpass's public instance is occasionally slow or
  rate-limited under load (confirmed directly while testing this module —
  a request timed out once and succeeded on retry), so the service tries a
  second public mirror before giving up and falling back to a cached/
  static list.
- **flutter_contacts** — the same device-contacts picker used in Module 1,
  reused here as "Import from Contacts" on the main Contacts screen.
- **url_launcher** (`tel:` scheme, Google Maps directions link) — placing
  calls and opening directions without needing any calling/mapping SDK of
  our own.

**What's done:** Full contact CRUD with a 5-contact cap and duplicate-phone
detection, a "primary contact" concept (alerted first during SOS), device-
contact import on both the signup screen and the main Contacts screen, a
real live map with real police/hospital/NGO pins, working Call and
Directions buttons per place, and working Call buttons on the emergency
helpline shortcuts (Police/Women's Helpline/Ambulance/Fire).

**What's missing and why:**
- **Contact consent/verification** — nothing currently confirms with the
  *contact* that they're okay being listed, or notifies them when they're
  added. Doing that properly needs a server-side notification path (Cloud
  Functions + push notification or SMS), which circles back to the same
  paid-SMS-gateway problem noted under Module 3.

---

## Module 3 — SOS Trigger & Alerts

**What it's supposed to do:** Let a user raise an alert fast — by holding a
button, shaking the phone, or saying a trigger phrase — that shares their
location and notifies contacts and emergency services.

**Technologies used and why:**
- **sensors_plus** (accelerometer) — shake-to-trigger detection runs
  entirely on-device, so it works even with no network connection at all,
  which matters for a safety trigger.
- **speech_to_text** — the Voice Command feature ("help me" / "emergency")
  listens on-device while the app is in the foreground.
- **Cloud Firestore** — every SOS alert is logged as an `incidents`
  document, the same collection Module 9's History reads from, so an SOS
  alert automatically shows up in the user's timeline.
- **url_launcher** — WhatsApp deep links (`wa.me`) for contact alerts
  avoid needing any SMS gateway account; the SMS Fallback option opens the
  native SMS composer (`sms:` scheme) pre-filled with the alert message,
  which needs no data connection at all — important since WhatsApp and
  Firestore both do need one. Direct phone calls (Police "100", Ambulance
  "108", and each contact) use the same `tel:` approach as Module 2.
- **record + AES-256-GCM encryption** — SOS auto-starts an encrypted audio
  recording the moment an alert goes out (see Module 7 for the encryption
  details).

**What's done:** Hold-to-arm and double-shake gestures, a 3-second
cancellable countdown, real GPS location with reverse-geocoded address,
real WhatsApp/SMS/call alerting to every saved contact, real Police/
Ambulance calling, auto-started encrypted evidence recording tied to the
alert, and voice-command triggering from anywhere in the app.

**What's missing and why:**
- **Background/killed-app triggering** — shake detection and voice
  command currently only run while the app is open in the foreground.
  Making them work with the app backgrounded or fully killed needs a
  persistent Android foreground service plus navigating each phone
  manufacturer's own battery-optimization exemption flow (Xiaomi, Samsung,
  and OnePlus in particular aggressively kill background services by
  default) — real, OEM-specific native work well beyond Flutter's
  cross-platform APIs, and out of scope for the time available.
- **Fully silent SMS sending** — the current SMS Fallback opens the native
  SMS app with the message pre-filled; the user still taps Send. Sending
  silently in the background needs the `SEND_SMS` runtime permission,
  which Google Play classifies as a "sensitive permission" requiring a
  declared use-case and review before the app can even be distributed with
  it — not practical to pursue before the app has a real Play Console
  listing.

---

## Module 4 — Live GPS Tracking

**What it's supposed to do:** Let a user share their live location with
trusted contacts during a journey, following a real route with a
destination, and detect if they leave a designated safe zone or arrive
home safely.

**Technologies used and why:**
- **geolocator** — real device GPS with distance-filtered position
  streaming (updates every ~40–50 meters moved, not on a fixed timer, to
  balance accuracy against battery drain).
- **OSRM's public demo server** — free, keyless road routing. Early
  versions of this module drew a straight line between two points; it now
  requests a real road-following route with distance/duration.
  Google's Directions API was the paid alternative avoided here.
- **Nominatim (OpenStreetMap)** — free reverse-geocoding and destination
  search, same reasoning as choosing Overpass over Google Places.
- **flutter_map + OpenStreetMap tiles** — the map rendering itself, again
  chosen specifically because it needs no billing-enabled API key, unlike
  the Google Maps Flutter SDK.
- **Cloud Firestore** (`live_sessions` collection) — the live-sharing
  backend; a session document updates in real time as the user moves, and
  contacts with the SafeHer app can watch it.

**What's done:** Real GPS-driven tracking and speed display, real
destination search and map-tap pinning, real road routing with a route
picker (fastest vs. alternates, each now tagged with a live safety score —
see Module 5), real Firestore-backed live-location sharing, working
geofence "left the safe zone" detection (anchored to a fixed center at
session start, one-shot per session — an earlier version re-centered the
zone every frame, which meant it could never actually be left; that's
fixed), and Auto Safe Arrival (detects arrival near a saved home location
and auto-ends the session with a safety log entry).

**What's missing and why:**
- **The actual web tracking viewer** — the live-share link currently sent
  to contacts points to a placeholder ("Web viewer coming soon, please
  open in SafeHer app"). Building a real web viewer was scoped from the
  start of the project as its *own* separate web app (Flutter Web or
  React) reading the same Firestore `live_sessions` collection — nobody
  has started that repository yet, so it doesn't exist, rather than being
  broken.
- **Turn-by-turn voice navigation** and **background location updates**
  when the app isn't in the foreground — the same background-service
  limitation described under Module 3.

---

## Module 5 — Safe Route & Risk Zone Prediction

**What it's supposed to do:** Flag safer vs. riskier areas and routes so a
user can choose a path that avoids poorly-lit or isolated stretches.

**Technologies used and why:**
- **Overpass API** — the only free, live, keyless data source available
  for this. There is no free source of verified, real-time crime
  statistics for Indian cities comparable to some U.S. cities' open crime
  data portals, so the module uses the closest honest, obtainable proxy
  signal instead: live density of police stations and street lamps near a
  point, discounted after dark (a route through better-lit, closer-to-help
  terrain scores safer; the same route at night scores lower). This is
  documented in the code and the UI copy as exactly what it is — "based on
  live police-station and street-lamp density, adjusted for time of
  day" — not dressed up as verified crime data.

**What's done:** Real live scoring for both standalone risk zones on the
map and for each candidate route in Live Tracking's route picker, a
graceful multi-mirror fallback if Overpass is unreachable (falls back to a
"moderate" reading rather than a false "unsafe" one), and unit tests
covering the scoring bucket logic including the night-time discount and the
fallback case specifically.

**What's missing and why:**
- **Verified crime-incident data** — would need a paid data provider or
  direct government/police API access, neither of which is available to a
  student project.
- **Real neighborhood boundaries** — risk zones are still drawn as a fixed
  radius around a handful of sampled points around the user rather than
  true polygon boundaries of actual named areas, because no free dataset
  provides that granularity of boundary data for arbitrary locations.

---

## Module 6 — AI Behavior / Anomaly Detection

**What it's supposed to do:** Notice unusual physical activity — a fall, a
sudden stop, running — that might indicate the user is in danger, without
them having to press anything.

**Technologies used and why:**
- **sensors_plus** (accelerometer) — the only sensor data source used;
  there's no gyroscope fusion.
- **A hand-tuned threshold classifier, not a trained ML model** — this
  is a real, honest engineering trade-off, not a shortcut. A genuine
  fall-detection ML model needs a labeled dataset of real fall/non-fall
  motion recordings and a training pipeline; nobody on the team has access
  to either, and there's no free public dataset that matches this app's
  exact sensor sampling characteristics closely enough to transfer
  reliably. Threshold-based classification (a brief near-weightless dip
  followed by a hard impact spike, within a defined time window, for a
  "possible fall"; a sharp deceleration from sustained high magnitude for
  a "sudden stop"; sustained elevated magnitude for "running") is the same
  general approach several commercial fall-detection wearables use as
  their baseline, and it's documented plainly in the code as exactly that
  — magnitude thresholds, not "AI" dressed up.

**What's done:** Real-time classification of running, sudden stops, and
possible falls from live accelerometer data, a live status indicator and
activity log with sensible de-duplication (repeated detections of the same
event within a short window collapse into one log entry rather than
spamming the list), and the classification logic itself is pulled out into
a standalone, unit-tested class (`MotionClassifier`) covering the fall
pattern, the running streak, the sudden-stop delta, and the reset behavior
against synthetic accelerometer sequences — since there's no way to
physically drop a test device from this development environment.

**What's missing and why:**
- **A real trained model** — would meaningfully cut false positives (e.g.
  distinguishing a real fall from just dropping the phone on a table),
  but needs labeled training data the team doesn't have. This is an
  explicit, documented scope boundary, not an oversight.
- **Gyroscope fusion** for orientation-aware detection — same "needs more
  sensor data and tuning than the team could validate without real
  hardware testing time" reasoning.

---

## Module 7 — Audio/Video Evidence Recording & Storage

**What it's supposed to do:** Automatically (or manually) capture audio,
photo, or video evidence during an incident, store it securely, and let
the user review it later without exposing it to anyone who picks up their
phone.

**Technologies used and why:**
- **record** (audio) and **image_picker** (photo/video via the native
  camera app) — capture. `image_picker` was chosen over building a custom
  in-app camera preview with the `camera` package specifically because it
  delegates to the phone's own camera app, which is far more reliable
  across the wide range of Android camera hardware/OEM camera apps a
  student team's phones represent, and needed no custom preview UI to get
  right without live device access during development.
- **No Firebase Storage** — this is the single biggest technology decision
  in the whole project, and it was forced, not chosen. Firebase changed
  its policy so that Cloud Storage now requires the **paid Blaze plan**
  to use *at all*, even to stay within what used to be free-tier limits.
  The team explicitly decided not to attach a billing account/credit card
  to a student project's Firebase account. So evidence storage was
  rebuilt from the ground up as **local-only**: files never leave the
  device.
- **AES-256-GCM encryption (`encrypt` package) + flutter_secure_storage**
  — because "local-only" on its own isn't the same as "secure." Every
  captured file is encrypted immediately after capture (the plaintext
  original is deleted the moment encryption succeeds), with the AES key
  generated once and stored in the OS's own hardware-backed keystore
  (Android Keystore / iOS Keychain) — the key itself never touches
  Firestore, a backup, or any file the app writes. GCM mode was chosen
  specifically over plain CBC because it authenticates the ciphertext: a
  tampered or corrupted encrypted file fails to decrypt loudly instead of
  silently producing garbage that looks like it might be valid evidence.
- **local_auth (biometric/PIN gate)** — viewing any evidence entry
  requires the device's own fingerprint/face unlock (or PIN/pattern
  fallback if biometrics aren't enrolled) before it's decrypted, satisfying
  "the user must use their phone lock to see the evidence" directly.
- **video_player** — plays back decrypted video/audio in-app; the
  decrypted copy is written to a temporary file only for the duration of
  viewing and deleted the moment the viewer screen closes, so plaintext
  evidence never persists on disk outside that narrow window.

**What's done:** Real audio/photo/video capture, AES-256-GCM encryption at
rest for every file, biometric/PIN-gated viewing with automatic cleanup of
the transient decrypted copy, and SOS-triggered automatic audio recording.
The encrypt/decrypt round trip itself (including wrong-key and
tampered-ciphertext failure cases) is unit-tested, since the actual
camera/biometric prompts can't be exercised without a physical device.

**What's missing and why:**
- **Cloud backup/cross-device sync of evidence** — the direct consequence
  of the no-Blaze-plan decision above. A free alternative (e.g. Cloudinary's
  free tier) was evaluated as a possible path but not implemented this
  round in favor of shipping the encryption + biometric-gate work, which
  was judged the higher-value, more clearly in-scope requirement.
- **Tamper-proof chain-of-custody / trusted timestamping** — proving to a
  third party (e.g. police, a court) exactly when a file was captured and
  that it hasn't been altered since would need a trusted timestamping
  authority or a blockchain-anchoring service — real infrastructure with
  its own cost, and out of scope for what a personal safety app's local
  encryption is trying to guarantee (protecting the user's own data at
  rest, not producing forensic-grade legal evidence).
- **Background recording continuation** when the app is killed — same
  background-service limitation as Modules 3 and 4.

---

## Module 8 — Fake Call & AI Safety Chatbot

**What it's supposed to do:** Give the user a believable fake incoming
call to fake their way out of an uncomfortable situation, and a
conversational assistant offering safety guidance.

**Technologies used and why:**
- **Pure Flutter UI/timers** for the fake call — rebuilt to visually match
  a real Android incoming-call screen after an early version looked
  obviously fake; no backend, no telephony API, just believable UI and
  vibration/ringtone timing.
- **A local, rule-based keyword-matching chatbot, not a real LLM** — a
  genuine LLM-backed assistant needs an API key and, for any capable
  model, a billing account — the same no-cost constraint that shaped
  Modules 1 and 7. A keyword→response knowledge base runs entirely
  offline, with zero network dependency, which is arguably the *right*
  property for a safety assistant regardless of cost (it can't fail
  because of a bad connection at the worst possible moment).

**What's done:** Both are fully functional as built — there is no
"UI-only, needs a backend" gap in this module. The fake call setup screen
and the realistic incoming-call screen work end to end; the chatbot answers
from its keyword knowledge base.

**What's missing and why:** Nothing is broken or unimplemented against the
original scope. The chatbot's keyword coverage could be extended, or a
free/open LLM could be integrated later if the team wants more natural
responses — an enhancement, not a gap.

---

## Module 9 — Incident Reporting, History & Admin Dashboard

**What it's supposed to do:** Let a user file an incident report, see a
timeline of everything that's happened (reports, SOS alerts, automatic
safety events), and give administrators a dashboard to review incidents
across all users.

**Technologies used and why:**
- **Cloud Firestore** (`incidents` collection, one shared schema) —
  reports, SOS alerts (Module 3), and automatic safety events like a
  geofence exit or a safe arrival (Module 4) all write to the *same*
  collection with a shared shape, so History's timeline is a single
  Firestore query rather than three separate data sources stitched
  together in the UI.
- **Firestore composite indexes** — added specifically to keep the
  History and Evidence list queries (filtered + sorted) fast as the
  collection grows, rather than relying on Firestore's default indexing,
  which doesn't cover compound filter+sort queries.

**What's done:** Real report submission, a real History timeline with
search, status filtering, and a monthly summary — all backed by live
Firestore data, not a mock list — and every SOS alert and automatic safety
event from Modules 3 and 4 lands in the same timeline automatically.

**What's missing and why:**
- **The web Admin Dashboard** — this was never meant to be part of this
  Flutter mobile app. The original project plan scoped it from day one as
  a **separate web application** (Flutter Web or React) reading the same
  Firestore `incidents` collection through a service account, specifically
  so a browser-based admin tool doesn't have to be bundled into and
  shipped with the end-user mobile app. That separate project simply
  hasn't been started yet by anyone on the team — it's a "not started,"
  not a "broken" or "incomplete" item within this codebase.
- **Photo attachment upload for reports** — the Report screen has a
  "has photo" flag in its data model but no actual upload path, for the
  identical Blaze-plan Storage reasoning as Module 7. If the team wants
  this, the local-encrypted-evidence pattern built for Module 7 could
  plausibly be extended to cover report photos too, rather than needing a
  new cloud-storage decision.

---

## Summary: why the project isn't 100% complete

Every gap documented above traces back to one of four real, specific
causes — not a lack of time or effort:

1. **The zero-cost constraint was deliberate, not accidental**, and it
   ruled out Firebase Storage/Blaze, the Google Maps/Places/Directions
   APIs, any commercial SMS gateway, any paid crime-data provider, and any
   billed LLM API. Every one of those was replaced with a genuinely
   functional free alternative rather than left as a mock — email/password
   auth, OpenStreetMap + Overpass + OSRM + Nominatim, on-device AES
   encryption instead of cloud storage, and a rule-based chatbot.
2. **No physical device access during a large part of this development
   process** meant every sensor-, camera-, and biometric-dependent feature
   (shake detection, fall detection, camera capture, biometric unlock) was
   built and verified as thoroughly as static analysis and unit testing of
   the underlying decision logic allow, but final on-device UX polish
   still needs the team's own phones.
3. **Background-service and Play Store policy work** (background SOS
   triggering, silent SMS sending) needs native, OEM-specific engineering
   and a real Play Console app listing to pursue properly — both
   legitimately out of scope for where the project is today.
4. **The web Admin Dashboard is a separate, not-yet-started project** by
   original design, not a missing feature of this repository.

None of these are silent gaps — each one is called out explicitly in the
module breakdown above, in code comments at the relevant integration
point, or in this document, so the next person picking up any of them
knows exactly what's blocking it and why.
