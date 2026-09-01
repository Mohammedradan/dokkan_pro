/// حركة مخزون. الأنواع:
/// receive = استلام من مورد
/// adjust_in = تسوية زيادة
/// adjust_out = تسوية نقص
/// waste = هالك / تالف
/// return_supplier = مرتجع للمورد
class StockMovement {
  final int? id;
  final int productId;
  final String type;
  final double quantity;
  final double? unitCost;
  final int? supplierId;
  final int? batchId;
  final String note;
  final int createdAt;

  const StockMovement({
    this.id,
    required this.productId,
    required this.type,
    required this.quantity,
    this.unitCost,
    this.supplierId,
    this.batchId,
    this.note = '',
    required this.createdAt,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'type': type,
      'quantity': quantity,
      'unit_cost': unitCost,
      'supplier_id': supplierId,
      'batch_id': batchId,
      'note': note,
      'created_at': createdAt,
    };
  }

  factory StockMovement.fromMap(Map<String, Object?> map) {
    return StockMovement(
      id: map['id'] as int?,
      productId: map['product_id'] as int,
      type: map['type'] as String,
      quantity: (map['quantity'] as num).toDouble(),
      unitCost: (map['unit_cost'] as num?)?.toDouble(),
      supplierId: map['supplier_id'] as int?,
      batchId: map['batch_id'] as int?,
      note: (map['note'] as String?) ?? '',
      createdAt: map['created_at'] as int,
    );
  }

  bool get isIncoming =>
      type == 'receive' || type == 'adjust_in';
  bool get isOutgoing => !isIncoming;
}

const Map<String, String> movementTypeLabels = {
  'receive': 'استلام',
  'adjust_in': 'تسوية زيادة',
  'adjust_out': 'تسوية نقص',
  'waste': 'هالك / تالف',
  'return_supplier': 'مرتجع للمورد',
};

String movementTypeLabel(String type) =>
    movementTypeLabels[type] ?? type;
