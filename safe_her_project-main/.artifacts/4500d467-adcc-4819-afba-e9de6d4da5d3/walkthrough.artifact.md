# Walkthrough - Module 4: Live GPS Tracking

I have implemented the live GPS tracking module, enabling users to share their journey with trusted contacts in real-time.

## Changes Made

### Environment & Build Fixes
- **Gradle Stability**: Downgraded bleeding-edge Gradle 9.1/AGP 9.0 to stable versions (Gradle 8.10 / AGP 8.6.0) to fix plugin compatibility.
- **Path Resolution**: Reverted custom build directory logic that was causing cross-drive drive resolution errors on Windows.
- **Code Correction**: Resolved compilation errors in `ScreenHeader`, `ContactsScreen`, and `StartJourneySheet` caused by missing parameters and types.

### Firebase & Dependencies
- Added `firebase_core`, `cloud_firestore`, `firebase_auth`, `firebase_messaging`, `share_plus`, and `url_launcher` to `pubspec.yaml`.
- Initialized Firebase in `main.dart` and set up FCM listeners for notification-based navigation.

### Data Architecture
- **Models**: Created `Contact` and `LiveSession` models to handle data serialization between Flutter and Firestore.
- **Services**:
    - `TrackingService`: Manages Firestore sessions, location updates (every 50m/15s), and session streaming.
    - `ContactsService`: Centralized mock contact management to facilitate sharing with in-app recipients.

### Journey UI Enhancements
- Updated [start_journey_sheet.dart](file:///D:/Software_Workspace/SafeHER/safe_her_project/lib/screens/tracking/start_journey_sheet.dart) to include optional **Vehicle Number** and **ETA** fields.
- Refactored [live_tracking_tab.dart](file:///D:/Software_Workspace/SafeHER/safe_her_project/lib/screens/tracking/live_tracking_tab.dart) to handle the journey lifecycle (Start -> Stream -> Share -> End).

### Sharing & Recipient Experience
- **In-App Sharing**: Users can multi-select contacts to add them to the session's `sharedWithUserIds` list in Firestore.
- **External Sharing**: Generates a shareable link with trip details for WhatsApp/SMS using `share_plus`.
- **Recipient Viewer**: Created [tracking_viewer_screen.dart](file:///D:/Software_Workspace/SafeHER/safe_her_project/lib/screens/tracking/tracking_viewer_screen.dart), a dedicated view for contacts to watch the sender's location move on a map in real-time.

## How to Verify

> [!IMPORTANT]
> **Native Setup Required**: Before running, you must place your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) files in the correct native directories.

1. **Start a Journey**:
   - Go to the **Live Tracking** tab.
   - Tap **Start a Journey**.
   - Pick a destination, enter a vehicle number (e.g., "WB01-1234"), and an ETA.
   - Tap **Start Journey**.
2. **Verify Live Updates**:
   - As you move (or simulate movement), check your Firestore `live_sessions` collection. The `lastLocation` field should update.
3. **Share the Trip**:
   - Tap **Share This Trip** on the active tracking screen.
   - Select a contact (e.g., "Mom" or "Priya").
   - Alternatively, tap **Share via WhatsApp/SMS** to see the generated text link.
4. **Viewer Test**:
   - Tap the link or use the `sessionId` from Firestore to open the `TrackingViewerScreen` manually (or via an FCM notification simulation).
   - Verify the marker moves as the owner's location updates.
