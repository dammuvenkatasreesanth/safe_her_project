import '../models/contact.dart';

class ContactsService {
  ContactsService._();

  static final List<Contact> _contacts = [
    Contact(id: '1', name: 'Mom', phone: '+91 98765 43210', userId: 'user_mom'),
    Contact(id: '2', name: 'Dad', phone: '+91 98765 43211'),
    Contact(
      id: '3',
      name: 'Priya (Neighbour)',
      phone: '+91 98765 43212',
      userId: 'user_priya',
    ),
  ];

  static List<Contact> get contacts => List.unmodifiable(_contacts);

  static void addContact(String name, String phone) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    _contacts.add(Contact(id: id, name: name, phone: phone));
  }

  /// Returns only contacts that have a linked SafeHer user ID
  static List<Contact> getInAppContacts() {
    return _contacts.where((c) => c.userId != null).toList();
  }
}
