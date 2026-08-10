/// A trusted emergency contact.
///
/// Backward compatible with the original shape (`id`, `name`, `phone`,
/// `userId`) that Module 3 (SOS), Module 4 (Live Tracking) and the Share
/// Sheet already read directly — those files are untouched by this module
/// and keep working unchanged. `relation`, `isPrimary`, and `createdAt` are
/// additive fields for the real Contacts CRUD.
class Contact {
  Contact({
    required this.id,
    required this.name,
    required this.phone,
    this.userId,
    this.relation = '',
    this.isPrimary = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String name;
  final String phone;

  /// If the contact is a SafeHer user, their real Firebase UID.
  final String? userId;

  /// Free-text relation label, e.g. "Mother", "Friend", "Neighbour".
  final String relation;

  /// The first contact alerted when SOS is triggered. Exactly one contact
  /// can be primary at a time — enforced by [ContactsRepository.setPrimary].
  final bool isPrimary;

  final DateTime createdAt;

  Contact copyWith({
    String? name,
    String? phone,
    String? userId,
    String? relation,
    bool? isPrimary,
  }) {
    return Contact(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      userId: userId ?? this.userId,
      relation: relation ?? this.relation,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt,
    );
  }

  /// Digits-only phone, used for duplicate detection so "+91 98765 43210"
  /// and "9876543210" are recognized as the same number.
  String get normalizedPhone => phone.replaceAll(RegExp(r'[^\d]'), '');

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'phone': phone,
    'userId': userId,
    'relation': relation,
    'isPrimary': isPrimary,
    'createdAt': createdAt.toIso8601String(),
  };

  /// Firestore document -> [Contact]. Tolerant of missing fields so old
  /// documents (or the in-memory mock seed) still parse correctly.
  factory Contact.fromMap(Map<String, dynamic> map) => Contact(
    id: map['id'] ?? '',
    name: map['name'] ?? '',
    phone: map['phone'] ?? '',
    userId: map['userId'],
    relation: map['relation'] ?? '',
    isPrimary: map['isPrimary'] ?? false,
    createdAt: map['createdAt'] != null
        ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
        : DateTime.now(),
  );

  /// Firestore document snapshot -> [Contact] (id comes from the doc id,
  /// not a field, since Firestore generates it).
  factory Contact.fromFirestore(String docId, Map<String, dynamic> data) =>
      Contact(
        id: docId,
        name: data['name'] ?? '',
        phone: data['phone'] ?? '',
        userId: data['userId'],
        relation: data['relation'] ?? '',
        isPrimary: data['isPrimary'] ?? false,
        createdAt: data['createdAt'] is DateTime
            ? data['createdAt'] as DateTime
            : (data['createdAt']?.toDate() ?? DateTime.now()),
      );
}
