class Supplier {
  final int? id;
  final String name;
  final String phone;
  final String address;
  final String notes;
  final int createdAt;

  const Supplier({
    this.id,
    required this.name,
    this.phone = '',
    this.address = '',
    this.notes = '',
    required this.createdAt,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  factory Supplier.fromMap(Map<String, Object?> map) {
    return Supplier(
      id: map['id'] as int?,
      name: map['name'] as String,
      phone: (map['phone'] as String?) ?? '',
      address: (map['address'] as String?) ?? '',
      notes: (map['notes'] as String?) ?? '',
      createdAt: map['created_at'] as int,
    );
  }
}
