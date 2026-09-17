import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../models/incident.dart';
import '../models/live_session.dart';

/// Read-only queries against the SafeHer mobile app's Firestore
/// collections. Every call here only succeeds if firestore.rules'
/// `isAdmin()` check passes for the signed-in user — this class has no
/// elevated access of its own, it's a plain client SDK like the mobile app
/// uses, just reading across all users instead of one.
class AdminDataService {
  AdminDataService._();

  static final _db = FirebaseFirestore.instance;

  /// All incidents (SOS alerts, reports, and automatic safety events)
  /// across every user, newest first. Capped at [limit] — the dashboard
  /// paginates by asking for more via [cursor] rather than streaming the
  /// whole collection at once as it grows.
  static Stream<List<Incident>> streamRecentIncidents({int limit = 200}) {
    return _db
        .collection('incidents')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(Incident.fromFirestore).toList());
  }

  static Stream<List<AppUser>> streamUsers({int limit = 500}) {
    return _db
        .collection('users')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(AppUser.fromFirestore).toList());
  }

  static Stream<List<LiveSession>> streamActiveLiveSessions() {
    return _db
        .collection('live_sessions')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snap) => snap.docs.map(LiveSession.fromFirestore).toList());
  }
}
