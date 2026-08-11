import 'package:flutter_contacts/flutter_contacts.dart';

/// A flattened (name, phone) pair read from the device's address book —
/// one per phone number, so a contact with two numbers appears twice in
/// [DeviceContactsService.fetchContacts]. Deliberately not the same shape
/// as [Contact] (the app's own emergency-contact model); the caller turns
/// a selection of these into real emergency contacts via
/// ContactsRepository/ContactProvider.
class DeviceContact {
  const DeviceContact({required this.name, required this.phone});
  final String name;
  final String phone;
}

/// Reads contacts from the device's own address book (READ_CONTACTS on
/// Android) for the "Import from Contacts" flow — separate from
/// ContactsRepository, which stores the user's chosen emergency contacts
/// in Firestore.
class DeviceContactsService {
  DeviceContactsService._();

  // readonly: true — we only ever read the address book (never write back
  // to it), and matters concretely: flutter_contacts' default (readonly:
  // false) requests READ_CONTACTS *and* WRITE_CONTACTS, and only reports
  // success if both are granted. WRITE_CONTACTS isn't declared in the
  // Android manifest (we don't need it), so the OS auto-denies that half
  // of the request — meaning the default call here would report "denied"
  // even after the user taps Allow on the real permission dialog.
  static Future<bool> requestPermission() =>
      FlutterContacts.requestPermission(readonly: true);

  /// Device contacts with at least one phone number, sorted by name.
  static Future<List<DeviceContact>> fetchContacts() async {
    final contacts = await FlutterContacts.getContacts(withProperties: true);
    final result = <DeviceContact>[];
    for (final c in contacts) {
      final name = c.displayName.trim();
      if (name.isEmpty) continue;
      for (final phone in c.phones) {
        final number = phone.number.trim();
        if (number.isEmpty) continue;
        result.add(DeviceContact(name: name, phone: number));
      }
    }
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }
}
