import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../state/app_state.dart';
import '../utils/export.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'product_details_screen.dart';

/// قائمة الطلب المقترحة: المنتجات الأقل من حد الطلب مجمعة حسب المورد،
/// مع الكمية المقترحة للطلب وتصدير CSV.
class ReorderScreen extends StatelessWidget {
  const ReorderScreen({super.key});

  Future<void> _export(AppState state, BuildContext context) async {
    if (state.reorderProducts.isEmpty) return;
    try {
      await exportReorderCsv(state);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تصدير قائمة الطلب')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل التصدير: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final products = state.reorderProducts;

    // تجميع حسب المورد
    final bySupplier = <String, List<Product>>{};
    for (final p in products) {
      final name = state.supplierById(p.supplierId)?.name ?? 'بدون مورد';
      bySupplier.putIfAbsent(name, () => []).add(p);
    }
    final groups = bySupplier.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Scaffold(
      appBar: AppBar(
        title: const Text('قائمة الطلب المقترحة'),
        actions: [
          IconButton(
            tooltip: 'تصدير CSV',
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: () => _export(state, context),
          ),
        ],
      ),
      body: products.isEmpty
          ? const EmptyState(
              icon: Icons.task_alt,
              title: 'لا توجد منتجات تحتاج إعادة طلب',
              subtitle: 'ممتاز! كل المنتجات فوق حد الطلب',
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: scheme.outline),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'الكمية المقترحة = سد العجز حتى ضعف حد الطلب الأدنى',
                          style: TextStyle(fontSize: 12, color: scheme.outline),
                        ),
                      ),
                    ],
                  ),
                ),
                for (final group in groups) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                    child: Row(
                      children: [
                        Icon(Icons.local_shipping_outlined,
                            size: 18, color: scheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            group.key,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                        Text(
                          '${group.value.length} صنف',
                          style: TextStyle(
                              fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Card(
                    elevation: 0,
                    margin: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    color: scheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      children: [
                        for (final p in group.value)
                          ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12),
                            leading: StatusBadge(status: p.stockStatus()),
                            title: Text(
                              p.name,
                              style: const TextStyle(fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              'المتوفر: ${qtyWithUnit(p.quantity, p.unit)} • الحد: ${formatQty(p.minStock)} ${p.unit}',
                              style: const TextStyle(fontSize: 11.5),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'اطلب: ${formatQty(state.suggestedOrderQty(p))}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal,
                                  ),
                                ),
                                Text(
                                  p.unit,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProductDetailsScreen(product: p),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'إجمالي الأصناف المطلوبة: ${products.length}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: scheme.outline),
                  ),
                ),
              ],
            ),
    );
  }
}
