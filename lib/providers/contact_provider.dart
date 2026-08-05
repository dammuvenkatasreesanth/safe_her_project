import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/contact.dart';
import '../repositories/contacts_repository.dart';
import '../services/auth_service.dart';

/// Drives the Contacts screen: loading state, validation, CRUD, and
/// human-readable error messages. Talks to [ContactsRepository] directly;
/// `ContactsService`'s static cache picks up the same Firestore changes
/// independently via its own stream, so other modules stay in sync too.
class ContactProvider extends ChangeNotifier {
  ContactProvider({ContactsRepository? repository})
    : _repository = repository ?? ContactsRepository();

  final ContactsRepository _repository;
  StreamSubscription<List<Contact>>? _subscription;

  List<Contact> _contacts = [];
  bool _isLoading = true;
  bool _isMutating = false;
  String? _error;
  String? _uid;

  List<Contact> get contacts => List.unmodifiable(_contacts);
  bool get isLoading => _isLoading;
  bool get isMutating => _isMutating;
  String? get error => _error;
  bool get hasReachedLimit => _contacts.length >= ContactsRepository.maxContacts;
  int get remainingSlots => ContactsRepository.maxContacts - _contacts.length;

  List<Contact> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return contacts;
    return _contacts
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.phone.contains(q) ||
              c.relation.toLowerCase().contains(q),
        )
        .toList();
  }

  /// Begins loading + live-syncing this user's contacts. Call once from
  /// the screen's `initState`.
  Future<void> init() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _uid = await AuthService.ensureSignedIn();
      _contacts = await _repository.fetchOnce(_uid!);
      _isLoading = false;
      notifyListeners();

      _subscription?.cancel();
      _subscription = _repository.streamContacts(_uid!).listen(
        (contacts) {
          _contacts = contacts;
          _error = null;
          notifyListeners();
        },
        onError: (e) {
          _error = e is ContactsException
              ? e.message
              : 'Lost connection to your contacts.';
          notifyListeners();
        },
      );
    } catch (e) {
      _isLoading = false;
      _error = e is AuthException
          ? e.message
          : 'Could not load your contacts. Please try again.';
      notifyListeners();
    }
  }

  /// Retries the initial load after a failure (e.g. no internet on
  /// first launch).
  Future<void> retry() => init();

  /// Validates a phone number: must contain 7–15 digits, optionally with
  /// a leading '+', spaces, or dashes. Returns an error string, or null
  /// if valid.
  String? validatePhone(String phone) {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return 'Phone number is required.';
    if (!RegExp(r'^\+?[\d\s-]+$').hasMatch(trimmed)) {
      return 'Enter a valid phone number.';
    }
    final digits = trimmed.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < 7 || digits.length > 15) {
      return 'Enter a valid phone number.';
    }
    return null;
  }

  String? validateName(String name) {
    if (name.trim().isEmpty) return 'Name is required.';
    if (name.trim().length < 2) return 'Name is too short.';
    return null;
  }

  /// Returns an error message on failure, or null on success. The caller
  /// (bottom sheet) shows the message inline rather than this class
  /// throwing, so the sheet can stay open and let the user fix the input.
  Future<String?> addContact({
    required String name,
    required String phone,
    String relation = '',
    bool isPrimary = false,
  }) async {
    final nameError = validateName(name);
    if (nameError != null) return nameError;
    final phoneError = validatePhone(phone);
    if (phoneError != null) return phoneError;
    if (hasReachedLimit) {
      return 'You can save up to ${ContactsRepository.maxContacts} emergency contacts.';
    }

    _isMutating = true;
    notifyListeners();
    try {
      final uid = _uid ?? await AuthService.ensureSignedIn();
      await _repository.addContact(
        uid: uid,
        name: name.trim(),
        phone: phone.trim(),
        relation: relation.trim(),
        isPrimary: isPrimary,
      );
      return null;
    } catch (e) {
      return e is ContactsException ? e.message : 'Could not save contact.';
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  Future<String?> updateContact({
    required String contactId,
    required String name,
    required String phone,
    String relation = '',
  }) async {
    final nameError = validateName(name);
    if (nameError != null) return nameError;
    final phoneError = validatePhone(phone);
    if (phoneError != null) return phoneError;

    _isMutating = true;
    notifyListeners();
    try {
      final uid = _uid ?? await AuthService.ensureSignedIn();
      await _repository.updateContact(
        uid: uid,
        contactId: contactId,
        name: name.trim(),
        phone: phone.trim(),
        relation: relation.trim(),
      );
      return null;
    } catch (e) {
      return e is ContactsException ? e.message : 'Could not update contact.';
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  Future<String?> deleteContact(String contactId) async {
    _isMutating = true;
    notifyListeners();
    try {
      final uid = _uid ?? await AuthService.ensureSignedIn();
      await _repository.deleteContact(uid: uid, contactId: contactId);
      return null;
    } catch (e) {
      return e is ContactsException ? e.message : 'Could not delete contact.';
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  Future<String?> setPrimary(String contactId) async {
    _isMutating = true;
    notifyListeners();
    try {
      final uid = _uid ?? await AuthService.ensureSignedIn();
      await _repository.setPrimary(uid: uid, contactId: contactId);
      return null;
    } catch (e) {
      return e is ContactsException
          ? e.message
          : 'Could not update primary contact.';
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
