import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/stock_movement.dart';
import '../state/app_state.dart';
import '../utils/format.dart';

Color movementColor(String type) {
  switch (type) {
    case 'receive':
      return Colors.green;
    case 'adjust_in':
      return Colors.teal;
    case 'adjust_out':
      return Colors.blueGrey;
    case 'waste':
      return Colors.red;
    case 'return_supplier':
      return Colors.orange;
    default:
      return Colors.blueGrey;
  }
}

IconData movementIcon(String type) {
  switch (type) {
    case 'receive':
      return Icons.move_to_inbox_rounded;
    case 'adjust_in':
      return Icons.add_circle_outline;
    case 'adjust_out':
      return Icons.remove_circle_outline;
    case 'waste':
      return Icons.delete_forever_outlined;
    case 'return_supplier':
      return Icons.assignment_return_outlined;
    default:
      return Icons.swap_horiz;
  }
}

class MovementTile extends StatelessWidget {
  final StockMovement movement;
  final String? productName; // إن كانت الحركة لصفحة منتج محدد

  const MovementTile({
    super.key,
    required this.movement,
    this.productName,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = movementColor(movement.type);
    final state = context.watch<AppState>();
    final name = productName ?? state.productById(movement.productId)?.name ?? 'منتج محذوف';
    final supplier = movement.supplierId != null
        ? state.supplierById(movement.supplierId)?.name
        : null;
    final sign = movement.isIncoming ? '+' : '-';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.12),
        child: Icon(movementIcon(movement.type), color: color, size: 20),
      ),
      title: Text(
        name,
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        [
          movementTypeLabel(movement.type),
          if (supplier != null) supplier,
          if (movement.note.isNotEmpty) movement.note,
        ].join(' • '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$sign${formatQty(movement.quantity)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: movement.isIncoming ? Colors.green.shade700 : Colors.red.shade700,
            ),
          ),
          Text(
            formatDateTime(movement.createdAt),
            style: TextStyle(fontSize: 10.5, color: scheme.outline),
          ),
        ],
      ),
    );
  }
}
