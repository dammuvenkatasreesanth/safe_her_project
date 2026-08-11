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

  static Future<bool> requestPermission() => FlutterContacts.requestPermission();

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
