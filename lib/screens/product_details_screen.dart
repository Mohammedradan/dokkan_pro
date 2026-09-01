import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/stock_batch.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/movement_tile.dart';
import 'movement_form_screen.dart';
import 'product_form_screen.dart';

class ProductDetailsScreen extends StatelessWidget {
  final Product product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final current = state.productById(product.id!);
    final p = current ?? product;

    if (current == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('المنتج')),
        body: const EmptyState(
          icon: Icons.delete_outline,
          title: 'هذا المنتج لم يعد موجوداً',
        ),
      );
    }

    final category = state.categoryById(p.categoryId);
    final supplier = state.supplierById(p.supplierId);
    final batches = state.batchesOf(p.id!);
    final productMovements = state.movements
        .where((m) => m.productId == p.id)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'تعديل',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                    builder: (_) => ProductFormScreen(product: p)),
              );
              if (changed == true && context.mounted) {
                // التحديث يتم عبر الـ Provider تلقائياً
              }
            },
          ),
          IconButton(
            tooltip: 'حذف',
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _delete(context, state, p),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          // بطاقة معلومات
          Card(
            margin: const EdgeInsets.all(16),
            elevation: 0,
            color: scheme.surfaceContainerLow,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      StatusBadge(status: p.stockStatus()),
                      const Spacer(),
                      Text(
                        '${formatQty(p.quantity)} ${p.unit}',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _infoRow(Icons.category_outlined, 'الفئة',
                      category?.name ?? 'بدون فئة'),
                  _infoRow(Icons.local_shipping_outlined, 'المورد',
                      supplier?.name ?? 'بدون مورد'),
                  _infoRow(Icons.qr_code_2, 'الباركود',
                      p.barcode.isEmpty ? '—' : p.barcode),
                  _infoRow(
                      Icons.payments_outlined,
                      'سعر التكلفة',
                      moneyWithCurrency(p.costPrice, state.currency)),
                  _infoRow(
                      Icons.sell_outlined,
                      'سعر البيع',
                      moneyWithCurrency(p.sellPrice, state.currency)),
                  _infoRow(
                      Icons.trending_up,
                      'هامش الربح',
                      _marginText(state, p, scheme)),
                  _infoRow(Icons.trending_down, 'حد الطلب الأدنى',
                      '${formatQty(p.minStock)} ${p.unit}'),
                  if (p.notes.isNotEmpty)
                    _infoRow(Icons.notes, 'ملاحظات', p.notes),
                ],
              ),
            ),
          ),

          // أزرار سريعة
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _openMovement(context, p, 'receive'),
                        icon: const Icon(Icons.move_to_inbox_rounded, size: 18),
                        label: const Text('استلام'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openMovement(context, p, 'adjust_out'),
                        icon:
                            const Icon(Icons.remove_circle_outline, size: 18),
                        label: const Text('تسوية نقص'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openMovement(context, p, 'waste'),
                        icon:
                            const Icon(Icons.delete_forever_outlined, size: 18),
                        label: const Text('هالك'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _openMovement(context, p, 'return_supplier'),
                        icon:
                            const Icon(Icons.assignment_return_outlined, size: 18),
                        label: const Text('مرتجع للمورد'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // الدفعات
          if (batches.isNotEmpty)
            SectionCard(
              title: 'الدفعات (${batches.length})',
              child: Column(
                children: [
                  for (final b in batches) _batchRow(context, state, p, b),
                ],
              ),
            ),

          // حركات المنتج
          SectionCard(
            title: 'سجل الحركات (${productMovements.length})',
            child: productMovements.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('لا توجد حركات لهذا المنتج'),
                  )
                : Column(
                    children: [
                      for (final m in productMovements.take(30))
                        MovementTile(movement: m, productName: p.name),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String _marginText(AppState state, Product p, ColorScheme scheme) {
    final margin = state.profitMargin(p);
    final percent = state.profitMarginPercent(p);
    final base = moneyWithCurrency(margin, state.currency);
    if (percent == null) {
      return '$base (حدد سعر التكلفة)';
    }
    return '$base (${percent.toStringAsFixed(0)}%)';
  }

  Widget _infoRow(IconData icon, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: scheme.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 95,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13, color: scheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _batchRow(BuildContext context, AppState state, Product p, StockBatch b) {
    final scheme = Theme.of(context).colorScheme;
    final expiry = b.expiryDate;
    String expiryText = 'بدون تاريخ صلاحية';
    Color? expiryColor = scheme.onSurfaceVariant;
    if (expiry != null) {
      final days = daysUntil(expiry);
      if (days < 0) {
        expiryText = 'منتهي منذ ${-days} يوم';
        expiryColor = Colors.red;
      } else if (days == 0) {
        expiryText = 'ينتهي اليوم';
        expiryColor = Colors.orange;
      } else if (days <= 30) {
        expiryText = 'ينتهي خلال $days يوم';
        expiryColor = Colors.orange;
      } else {
        expiryText = 'ينتهي ${formatDate(expiry)}';
      }
    }

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.layers_outlined, color: scheme.primary),
      title: Text(
        '${formatQty(b.quantity)} ${p.unit}',
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        expiryText,
        style: TextStyle(fontSize: 12, color: expiryColor),
      ),
      trailing: expiry != null
          ? TextButton(
              onPressed: () => _wasteBatch(context, state, p, b),
              child: const Text('إتلاف',
                  style: TextStyle(color: Colors.red, fontSize: 12.5)),
            )
          : null,
    );
  }

  Future<void> _wasteBatch(
      BuildContext context, AppState state, Product p, StockBatch b) async {
    final ok = await confirmDialog(
      context,
      title: 'إتلاف الدفعة',
      message: 'سيتم إتلاف ${formatQty(b.quantity)} ${p.unit} من «${p.name}»',
      confirmText: 'إتلاف',
      destructive: true,
    );
    if (!ok) return;
    await state.wasteBatch(p, b);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إتلاف الدفعة')),
    );
  }

  Future<void> _delete(
      BuildContext context, AppState state, Product p) async {
    final ok = await confirmDialog(
      context,
      title: 'حذف المنتج',
      message: 'سيتم حذف «${p.name}» مع كل دفعاته وحركاته. لا يمكن التراجع.',
      confirmText: 'حذف',
      destructive: true,
    );
    if (!ok) return;
    await state.removeProduct(p);
    if (!context.mounted) return;
    Navigator.pop(context);
  }

  void _openMovement(BuildContext context, Product p, String type) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MovementFormScreen(product: p, initialType: type),
      ),
    );
  }
}
