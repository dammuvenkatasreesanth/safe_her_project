import 'dart:async';
import '../models/contact.dart';
import '../repositories/contacts_repository.dart';
import 'auth_service.dart';

/// App-wide synchronous cache of the signed-in user's emergency contacts,
/// kept live via a Firestore stream.
///
/// IMPORTANT — this class's public API (`contacts`, `addContact`,
/// `getInAppContacts`) is unchanged from the original in-memory version on
/// purpose: Module 3 (SOS), Module 4 (Live Tracking), and the Share Sheet
/// all read `ContactsService.contacts` synchronously and are not part of
/// this module, so they must keep working without any edits on their end.
///
/// [init] is called once from `main()` (see the note there) so the cache
/// is already warm by the time any screen first reads `.contacts`. The
/// real CRUD screen (`ContactsScreen`) talks to [ContactsRepository]
/// through `ContactProvider` for its rich add/edit/delete/primary flows;
/// this class only mirrors the resulting Firestore state for everyone
/// else to read.
class ContactsService {
  ContactsService._();

  static final _repository = ContactsRepository();
  static List<Contact> _contacts = [];
  static StreamSubscription<List<Contact>>? _subscription;
  static bool _initialized = false;

  /// Starts syncing from Firestore. Safe to call multiple times — only
  /// the first call does anything. Call this once at app startup.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final uid = await AuthService.ensureSignedIn();
      // Seed synchronously-readable state immediately so early screens
      // (e.g. SOS, if opened right after launch) don't see an empty list
      // any longer than necessary.
      _contacts = await _repository.fetchOnce(uid);
      _subscription = _repository.streamContacts(uid).listen((contacts) {
        _contacts = contacts;
      });
    } catch (_) {
      // No connection / auth failed at startup — keep whatever was cached
      // (empty on first-ever launch). ContactProvider surfaces a retry UI
      // for the user; other modules simply see an empty list until then.
    }
  }

  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _initialized = false;
  }

  /// Current cached contacts, primary first. Synchronous by design — see
  /// the class doc for why this can't become a Future without touching
  /// three other modules' screens.
  static List<Contact> get contacts => List.unmodifiable(_contacts);

  /// Legacy convenience method, kept for compatibility. New code adding a
  /// contact from the real Contacts screen should go through
  /// `ContactProvider.addContact` instead, which validates and reports
  /// errors properly; this only writes the two required fields.
  static Future<void> addContact(String name, String phone) async {
    final uid = await AuthService.ensureSignedIn();
    await _repository.addContact(uid: uid, name: name, phone: phone);
  }

  /// Contacts that have a linked SafeHer user ID (used by Live Tracking
  /// to know who can receive an in-app live-location share).
  static List<Contact> getInAppContacts() {
    return _contacts.where((c) => c.userId != null).toList();
  }
}
