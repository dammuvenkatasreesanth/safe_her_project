class Contact {
  Contact({
    required this.id,
    required this.name,
    required this.phone,
    this.userId,
  });

  final String id;
  final String name;
  final String phone;
  /// If the contact is a SafeHer user, their real Firebase UID
  final String? userId;

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'phone': phone,
    'userId': userId,
  };

  factory Contact.fromMap(Map<String, dynamic> map) => Contact(
    id: map['id'] ?? '',
    name: map['name'] ?? '',
    phone: map['phone'] ?? '',
    userId: map['userId'],
  );
}
