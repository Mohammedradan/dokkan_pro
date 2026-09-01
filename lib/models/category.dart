class Category {
  final int? id;
  final String name;
  final int createdAt;

  const Category({
    this.id,
    required this.name,
    required this.createdAt,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt,
    };
  }

  factory Category.fromMap(Map<String, Object?> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      createdAt: map['created_at'] as int,
    );
  }

  Category copyWith({int? id, String? name}) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt,
    );
  }
}
