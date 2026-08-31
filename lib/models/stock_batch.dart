/// دفعة مخزون: كمية استُلمت بتاريخ معيّن ولها تاريخ صلاحية اختياري.
class StockBatch {
  final int? id;
  final int productId;
  double quantity;
  final int? expiryDate; // millisecondsSinceEpoch أو null
  final int receivedAt;

  StockBatch({
    this.id,
    required this.productId,
    required this.quantity,
    this.expiryDate,
    required this.receivedAt,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'quantity': quantity,
      'expiry_date': expiryDate,
      'received_at': receivedAt,
    };
  }

  factory StockBatch.fromMap(Map<String, Object?> map) {
    return StockBatch(
      id: map['id'] as int?,
      productId: map['product_id'] as int,
      quantity: (map['quantity'] as num).toDouble(),
      expiryDate: map['expiry_date'] as int?,
      receivedAt: map['received_at'] as int,
    );
  }
}
