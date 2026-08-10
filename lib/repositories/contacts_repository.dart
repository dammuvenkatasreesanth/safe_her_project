import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/contact.dart';

/// Thrown by [ContactsRepository] with a message safe to show to users.
class ContactsException implements Exception {
  const ContactsException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Firestore-backed persistence for a user's emergency contacts.
///
/// Schema:
/// ```
/// users/{userId}/contacts/{contactId}
///     name       : string
///     phone      : string
///     relation   : string
///     userId     : string?   (linked SafeHer account, if any)
///     isPrimary  : bool
///     createdAt  : timestamp
/// ```
///
/// A note on atomicity: Firestore transactions can only `get()` documents
/// by a *known reference* — they cannot run collection queries. So the
/// cap check (max 5) and duplicate-phone check below read the collection
/// with a plain (non-transactional) query first; under truly simultaneous
/// writes from two devices for the same user, in principle both could
/// pass that check before either commits. The primary-contact swap —
/// where getting it wrong would leave two contacts marked primary, or
/// none — *is* done inside a real transaction using `txn.get()` on the
/// specific document reference, since by that point we know exactly
/// which document we're touching. For a single-user personal-contacts
/// list this is the right trade-off: the swap is the part that would
/// actually corrupt state if it raced, the count/duplicate checks are
/// soft guards.
class ContactsRepository {
  ContactsRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const maxContacts = 5;

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      _db.collection('users').doc(uid).collection('contacts');

  /// Live stream of a user's contacts, primary first then newest first.
  Stream<List<Contact>> streamContacts(String uid) {
    return _collection(uid).snapshots().map((snapshot) {
      final contacts = snapshot.docs
          .map((doc) => Contact.fromFirestore(doc.id, doc.data()))
          .toList();
      contacts.sort((a, b) {
        if (a.isPrimary != b.isPrimary) return a.isPrimary ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });
      return contacts;
    }).handleError((error) {
      throw ContactsException(_messageFor(error));
    });
  }

  /// One-off fetch, e.g. for a fast synchronous seed before the stream
  /// delivers its first snapshot.
  Future<List<Contact>> fetchOnce(String uid) async {
    try {
      final snapshot = await _collection(uid).get();
      final contacts = snapshot.docs
          .map((doc) => Contact.fromFirestore(doc.id, doc.data()))
          .toList();
      contacts.sort((a, b) {
        if (a.isPrimary != b.isPrimary) return a.isPrimary ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });
      return contacts;
    } catch (e) {
      throw ContactsException(_messageFor(e));
    }
  }

  /// Adds a contact. Throws [ContactsException] if the 5-contact cap is
  /// reached or the phone number is already saved (checked against
  /// [Contact.normalizedPhone] so formatting differences don't slip
  /// through). If [isPrimary] is true (or this is the first contact),
  /// any existing primary is demoted transactionally so exactly one
  /// contact is ever primary.
  Future<void> addContact({
    required String uid,
    required String name,
    required String phone,
    String relation = '',
    bool isPrimary = false,
  }) async {
    try {
      // Soft pre-checks (see class doc for why these aren't transactional).
      final existing = await _collection(uid).get();

      if (existing.docs.length >= maxContacts) {
        throw const ContactsException(
          'You can save up to $maxContacts emergency contacts.',
        );
      }

      final normalizedNew = phone.replaceAll(RegExp(r'[^\d]'), '');
      final duplicate = existing.docs.any((doc) {
        final existingPhone = (doc.data()['phone'] as String? ?? '')
            .replaceAll(RegExp(r'[^\d]'), '');
        return existingPhone == normalizedNew;
      });
      if (duplicate) {
        throw const ContactsException(
          'This phone number is already saved as a contact.',
        );
      }

      final shouldBePrimary = isPrimary || existing.docs.isEmpty;
      final currentPrimaryMatches = existing.docs
          .where((doc) => doc.data()['isPrimary'] == true)
          .toList();
      final currentPrimary =
          currentPrimaryMatches.isEmpty ? null : currentPrimaryMatches.first;
      final newDoc = _collection(uid).doc();

      // The actual write: real transaction, only known doc references.
      await _db.runTransaction((txn) async {
        if (shouldBePrimary && currentPrimary != null) {
          // Re-read transactionally so we act on current state, not the
          // possibly-stale snapshot from the pre-check above.
          final freshPrimary = await txn.get(currentPrimary.reference);
          if (freshPrimary.exists && freshPrimary.data()?['isPrimary'] == true) {
            txn.update(currentPrimary.reference, {'isPrimary': false});
          }
        }
        txn.set(newDoc, {
          'name': name,
          'phone': phone,
          'relation': relation,
          'userId': null,
          'isPrimary': shouldBePrimary,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } on ContactsException {
      rethrow;
    } catch (e) {
      throw ContactsException(_messageFor(e));
    }
  }

  /// Updates name/phone/relation. Re-checks the duplicate-phone rule
  /// against every *other* contact (excluding itself).
  Future<void> updateContact({
    required String uid,
    required String contactId,
    required String name,
    required String phone,
    String relation = '',
  }) async {
    try {
      final existing = await _collection(uid).get();
      final normalizedNew = phone.replaceAll(RegExp(r'[^\d]'), '');
      final duplicate = existing.docs.any((doc) {
        if (doc.id == contactId) return false;
        final existingPhone = (doc.data()['phone'] as String? ?? '')
            .replaceAll(RegExp(r'[^\d]'), '');
        return existingPhone == normalizedNew;
      });
      if (duplicate) {
        throw const ContactsException(
          'This phone number is already saved as a contact.',
        );
      }

      await _collection(uid).doc(contactId).update({
        'name': name,
        'phone': phone,
        'relation': relation,
      });
    } on ContactsException {
      rethrow;
    } catch (e) {
      throw ContactsException(_messageFor(e));
    }
  }

  /// Deletes a contact. If it was primary and other contacts remain, the
  /// most recently added remaining contact becomes primary — done as a
  /// real transaction over the two known document references involved.
  Future<void> deleteContact({
    required String uid,
    required String contactId,
  }) async {
    try {
      final docRef = _collection(uid).doc(contactId);

      final remainingSnapshot = await _collection(uid).get();
      final others = remainingSnapshot.docs
          .where((d) => d.id != contactId)
          .toList()
        ..sort(
          (a, b) => (b.data()['createdAt'] as Timestamp?)?.compareTo(
                (a.data()['createdAt'] as Timestamp?) ?? Timestamp(0, 0),
              ) ??
              0,
        );
      final promoteCandidate = others.isNotEmpty ? others.first : null;

      await _db.runTransaction((txn) async {
        final current = await txn.get(docRef);
        final wasPrimary = current.data()?['isPrimary'] == true;

        txn.delete(docRef);

        if (wasPrimary && promoteCandidate != null) {
          final freshCandidate = await txn.get(promoteCandidate.reference);
          if (freshCandidate.exists) {
            txn.update(promoteCandidate.reference, {'isPrimary': true});
          }
        }
      });
    } catch (e) {
      throw ContactsException(_messageFor(e));
    }
  }

  /// Makes [contactId] the sole primary contact, demoting whichever
  /// contact currently holds that flag. Fully transactional — both
  /// document references are known before the transaction starts.
  Future<void> setPrimary({
    required String uid,
    required String contactId,
  }) async {
    try {
      final existing = await _collection(uid).get();
      final currentPrimaryMatches = existing.docs
          .where((doc) => doc.id != contactId && doc.data()['isPrimary'] == true)
          .toList();
      final currentPrimary =
          currentPrimaryMatches.isEmpty ? null : currentPrimaryMatches.first;
      final newPrimaryRef = _collection(uid).doc(contactId);

      await _db.runTransaction((txn) async {
        final newPrimarySnapshot = await txn.get(newPrimaryRef);
        if (!newPrimarySnapshot.exists) {
          throw const ContactsException('That contact no longer exists.');
        }
        if (currentPrimary != null) {
          final freshOld = await txn.get(currentPrimary.reference);
          if (freshOld.exists && freshOld.data()?['isPrimary'] == true) {
            txn.update(currentPrimary.reference, {'isPrimary': false});
          }
        }
        txn.update(newPrimaryRef, {'isPrimary': true});
      });
    } on ContactsException {
      rethrow;
    } catch (e) {
      throw ContactsException(_messageFor(e));
    }
  }

  String _messageFor(Object error) {
    if (error is ContactsException) return error.message;
    final message = error.toString();
    if (message.contains('permission-denied')) {
      return "You don't have permission to do that.";
    }
    if (message.contains('unavailable') || message.contains('network')) {
      return 'No internet connection. Changes will sync once you\'re back online.';
    }
    return 'Something went wrong. Please try again.';
  }
}
