import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/movement_tile.dart';
import 'expiry_screen.dart';
import 'movements_screen.dart';
import 'product_details_screen.dart';
import 'products_screen.dart';
import 'reorder_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE d MMMM y', 'ar').format(now);

    final expired = state.expiredBatches.length;
    final expiring = state.expiringSoonBatches.length;
    final alerts = state.alertProducts.length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(state.storeName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              dateStr,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().reloadAll(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            // الإحصائيات
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.9,
                children: [
                  StatCard(
                    icon: Icons.inventory_2_outlined,
                    label: 'منتج في المخزون',
                    value: '${state.products.length}',
                    color: scheme.primary,
                    onTap: () => _go(context, const ProductsScreen()),
                  ),
                  StatCard(
                    icon: Icons.payments_outlined,
                    label: 'قيمة المخزون (تكلفة)',
                    value: moneyWithCurrency(state.stockValue, state.currency),
                    color: Colors.indigo,
                  ),
                  StatCard(
                    icon: Icons.category_outlined,
                    label: 'فئات',
                    value: '${state.categories.length}',
                    color: Colors.teal,
                  ),
                  StatCard(
                    icon: Icons.local_shipping_outlined,
                    label: 'موردون',
                    value: '${state.suppliers.length}',
                    color: Colors.brown,
                  ),
                ],
              ),
            ),

            // تنبيهات المخزون
            if (alerts > 0)
              SectionCard(
                title: 'تنبيهات المخزون ($alerts)',
                trailing: Icon(Icons.warning_amber_rounded,
                    size: 20, color: Colors.orange),
                child: Column(
                  children: [
                    for (final p in state.alertProducts.take(5))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: StatusBadge(status: p.stockStatus()),
                        title: Text(p.name,
                            style: const TextStyle(fontSize: 13.5)),
                        trailing: Text(
                          qtyWithUnit(p.quantity, p.unit),
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => ProductDetailsScreen(product: p)),
                        ),
                      ),
                    if (alerts > 5)
                      TextButton(
                        onPressed: () => _go(context, const ProductsScreen()),
                        child: Text('عرض كل المنتجات'),
                      ),
                  ],
                ),
              ),

            // قائمة الطلب المقترحة
            if (state.reorderProducts.isNotEmpty)
              SectionCard(
                title: 'قائمة الطلب المقترحة',
                trailing: Icon(Icons.shopping_cart_outlined,
                    size: 20, color: scheme.primary),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final p in state.reorderProducts.take(4))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: StatusBadge(status: p.stockStatus()),
                        title: Text(p.name,
                            style: const TextStyle(fontSize: 13)),
                        trailing: Text(
                          'اطلب: ${formatQty(state.suggestedOrderQty(p))} ${p.unit}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () =>
                            _go(context, const ReorderScreen()),
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: Text(
                            'عرض الكل (${state.reorderProducts.length})'),
                      ),
                    ),
                  ],
                ),
              ),

            // الصلاحية
            SectionCard(
              title: 'تواريخ الصلاحية',
              trailing: Icon(Icons.event_available_outlined,
                  size: 20, color: scheme.primary),
              child: Row(
                children: [
                  _ExpiryChip(
                    label: 'منتهي',
                    count: expired,
                    color: Colors.red,
                    onTap: () => _go(context, const ExpiryScreen(initialTab: 0)),
                  ),
                  const SizedBox(width: 10),
                  _ExpiryChip(
                    label: 'ينتهي خلال 30 يوم',
                    count: expiring,
                    color: Colors.orange,
                    onTap: () => _go(context, const ExpiryScreen(initialTab: 1)),
                  ),
                ],
              ),
            ),

            // أحدث الحركات
            SectionCard(
              title: 'أحدث الحركات',
              trailing: TextButton(
                onPressed: () => _go(context, const MovementsScreen()),
                child: const Text('الكل'),
              ),
              child: state.movements.isEmpty
                  ? const EmptyState(
                      icon: Icons.history,
                      title: 'لا توجد حركات بعد',
                    )
                  : Column(
                      children: [
                        for (final m in state.movements.take(6))
                          MovementTile(movement: m),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, Widget screen) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _ExpiryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;

  const _ExpiryChip({
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
