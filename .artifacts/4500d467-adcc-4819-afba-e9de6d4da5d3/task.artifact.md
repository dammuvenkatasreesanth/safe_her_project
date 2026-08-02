# Task: Module 4 - Live GPS Tracking Implementation

- `[x]` **Phase 1: Firebase & Dependencies**
    - `[x]` Update `pubspec.yaml` with Firebase and sharing dependencies
    - `[x]` Initialize Firebase in `main.dart`
- `[x]` **Phase 2: Core Models & Services**
    - `[x]` Create `Contact` and `LiveSession` models
    - `[x]` Implement `ContactsService` (centralized in-memory storage)
    - `[x]` Implement `TrackingService` (Firestore interaction & streaming)
    - `[x]` Refactor `ContactsScreen` to use `ContactsService`
- `[x]` **Phase 3: UI Enhancements**
    - `[x]` Update `StartJourneySheet` with Vehicle No. and ETA fields
    - `[x]` Update `LiveTrackingTab` to wire up journey lifecycle with Firestore
- `[x]` **Phase 4: Sharing & Messaging**
    - `[x]` Implement "Share Trip" selection UI and logic
    - `[x]` Add `share_plus` integration for external links
- `[x]` **Phase 5: Recipient Viewer**
    - `[x]` Create `TrackingViewerScreen` (Live map + Session details)
    - `[x]` Setup FCM entry point logic for notification taps
