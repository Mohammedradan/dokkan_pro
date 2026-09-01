class Product {
  final int? id;
  final String name;
  final String barcode;
  final int? categoryId;
  final int? supplierId;
  final String unit;
  final double costPrice;
  final double sellPrice;
  final double minStock;
  final double quantity;
  final String notes;
  final int createdAt;
  final int updatedAt;

  const Product({
    this.id,
    required this.name,
    this.barcode = '',
    this.categoryId,
    this.supplierId,
    this.unit = 'قطعة',
    this.costPrice = 0,
    this.sellPrice = 0,
    this.minStock = 0,
    this.quantity = 0,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  Product copyWith({
    int? id,
    String? name,
    String? barcode,
    int? categoryId,
    int? supplierId,
    String? unit,
    double? costPrice,
    double? sellPrice,
    double? minStock,
    double? quantity,
    String? notes,
    int? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      categoryId: categoryId ?? this.categoryId,
      supplierId: supplierId ?? this.supplierId,
      unit: unit ?? this.unit,
      costPrice: costPrice ?? this.costPrice,
      sellPrice: sellPrice ?? this.sellPrice,
      minStock: minStock ?? this.minStock,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'category_id': categoryId,
      'supplier_id': supplierId,
      'unit': unit,
      'cost_price': costPrice,
      'sell_price': sellPrice,
      'min_stock': minStock,
      'quantity': quantity,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Product.fromMap(Map<String, Object?> map) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String,
      barcode: (map['barcode'] as String?) ?? '',
      categoryId: map['category_id'] as int?,
      supplierId: map['supplier_id'] as int?,
      unit: (map['unit'] as String?) ?? 'قطعة',
      costPrice: (map['cost_price'] as num?)?.toDouble() ?? 0,
      sellPrice: (map['sell_price'] as num?)?.toDouble() ?? 0,
      minStock: (map['min_stock'] as num?)?.toDouble() ?? 0,
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      notes: (map['notes'] as String?) ?? '',
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
    );
  }

  /// حالة المخزون: نفذ / منخفض / متوفر
  String stockStatus() {
    if (quantity <= 0) return 'نفذ';
    if (minStock > 0 && quantity <= minStock) return 'منخفض';
    return 'متوفر';
  }

  bool get isOutOfStock => quantity <= 0;
  bool get isLowStock => !isOutOfStock && minStock > 0 && quantity <= minStock;
}
