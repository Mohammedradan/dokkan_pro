import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/stock_movement.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// شاشة التقارير: ملخصات مالية، قيمة المخزون حسب الفئة،
/// حركات آخر 30 يوم، وأعلى المنتجات قيمة.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;

    // ====== ملخصات الحركات ======
    var receiveCount = 0;
    var totalReceivedCost = 0.0;
    var wasteCount = 0;
    var wasteValue = 0.0;
    for (final m in state.movements) {
      if (m.type == 'receive') {
        receiveCount += 1;
        totalReceivedCost += m.quantity * (m.unitCost ?? 0);
      } else if (m.type == 'waste') {
        wasteCount += 1;
        final p = state.productById(m.productId);
        wasteValue += m.quantity * (p?.costPrice ?? 0);
      }
    }

    // ====== قيمة المخزون حسب الفئة ======
    final byCategory = <String, double>{};
    for (final p in state.products) {
      final name = state.categoryById(p.categoryId)?.name ?? 'بدون فئة';
      byCategory[name] = (byCategory[name] ?? 0) + p.quantity * p.costPrice;
    }
    final categoryEntries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // ====== حركات آخر 30 يوم ======
    final cutoff = DateTime.now()
        .subtract(const Duration(days: 30))
        .millisecondsSinceEpoch;
    final recent = state.movements.where((m) => m.createdAt >= cutoff).toList();
    final typeCounts = <String, int>{};
    for (final m in recent) {
      typeCounts[m.type] = (typeCounts[m.type] ?? 0) + 1;
    }

    // ====== أعلى 5 منتجات قيمة بالمخزون ======
    final top = state.products.toList()
      ..sort((a, b) =>
          (b.quantity * b.costPrice).compareTo(a.quantity * a.costPrice));

    // ====== ملخص حركة المخزون آخر 6 أشهر ======
    final now = DateTime.now();
    final monthly = <String, ({double inQty, double outQty})>{};
    for (var m = 5; m >= 0; m--) {
      final d = DateTime(now.year, now.month - m, 1);
      monthly['${d.year}-${d.month}'] = (inQty: 0, outQty: 0);
    }
    for (final mv in state.movements) {
      final d = DateTime.fromMillisecondsSinceEpoch(mv.createdAt);
      final key = '${d.year}-${d.month}';
      if (!monthly.containsKey(key)) continue;
      if (mv.isIncoming) {
        monthly[key] = (
          inQty: monthly[key]!.inQty + mv.quantity,
          outQty: monthly[key]!.outQty,
        );
      } else {
        monthly[key] = (
          inQty: monthly[key]!.inQty,
          outQty: monthly[key]!.outQty + mv.quantity,
        );
      }
    }
    var maxMonthlyQty = 1.0;
    for (final v in monthly.values) {
      if (v.inQty > maxMonthlyQty) maxMonthlyQty = v.inQty;
      if (v.outQty > maxMonthlyQty) maxMonthlyQty = v.outQty;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('التقارير')),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppState>().reloadAll(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
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
                    icon: Icons.add_shopping_cart_outlined,
                    label: 'إجمالي الاستلامات',
                    value: moneyWithCurrency(totalReceivedCost, state.currency),
                    color: Colors.green,
                  ),
                  StatCard(
                    icon: Icons.delete_forever_outlined,
                    label: 'قيمة الهالك (تكلفة)',
                    value: moneyWithCurrency(wasteValue, state.currency),
                    color: Colors.red,
                  ),
                  StatCard(
                    icon: Icons.inventory_outlined,
                    label: 'قيمة المخزون',
                    value: moneyWithCurrency(state.stockValue, state.currency),
                    color: scheme.primary,
                  ),
                  StatCard(
                    icon: Icons.warning_amber_outlined,
                    label: 'تنبيهات حالية',
                    value: '${state.alertProducts.length}',
                    color: Colors.orange,
                  ),
                ],
              ),
            ),

            SectionCard(
              title: 'قيمة المخزون حسب الفئة',
              child: categoryEntries.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('لا توجد بيانات بعد'),
                    )
                  : Column(
                      children: [
                        for (final e in categoryEntries)
                          _CategoryBar(
                            name: e.key,
                            value: e.value,
                            total: state.stockValue,
                            currency: state.currency,
                          ),
                      ],
                    ),
            ),

            SectionCard(
              title: 'حركة المخزون — آخر 6 أشهر',
              child: Column(
                children: [
                  for (final entry in monthly.entries)
                    _MonthRow(
                      label: DateFormat('MMM yyyy', 'ar')
                          .format(DateTime.parse('${entry.key}-01')),
                      inQty: entry.value.inQty,
                      outQty: entry.value.outQty,
                      max: maxMonthlyQty,
                    ),
                ],
              ),
            ),

            SectionCard(
              title: 'حركات آخر 30 يوم',
              child: recent.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('لا توجد حركات في آخر 30 يوم'),
                    )
                  : Column(
                      children: [
                        for (final t in typeCounts.entries)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              _typeIcon(t.key),
                              color: _typeColor(t.key),
                              size: 20,
                            ),
                            title: Text(
                              movementTypeLabel(t.key),
                              style: const TextStyle(fontSize: 13.5),
                            ),
                            trailing: Text(
                              '${t.value} حركة',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
            ),

            SectionCard(
              title: 'أعلى 5 منتجات قيمة بالمخزون',
              child: Column(
                children: [
                  for (var i = 0; i < top.length && i < 5; i++)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: scheme.primaryContainer,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        top[i].name,
                        style: const TextStyle(fontSize: 13.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        moneyWithCurrency(
                            top[i].quantity * top[i].costPrice,
                            state.currency),
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  if (top.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('لا توجد منتجات بعد'),
                    ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'عدد الاستلامات: $receiveCount • عدد حركات الهالك: $wasteCount',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: scheme.outline),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _typeIcon(String type) {
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

  Color _typeColor(String type) {
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
}

class _MonthRow extends StatelessWidget {
  final String label;
  final double inQty;
  final double outQty;
  final double max;

  const _MonthRow({
    required this.label,
    required this.inQty,
    required this.outQty,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 62,
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (inQty / max).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: scheme.surfaceContainerHighest,
                    color: Colors.green,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 56,
                child: Text(
                  '+${formatQty(inQty)}',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                      fontSize: 11, color: Colors.green.shade700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              const SizedBox(width: 62),
              const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (outQty / max).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: scheme.surfaceContainerHighest,
                    color: Colors.red,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 56,
                child: Text(
                  '-${formatQty(outQty)}',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                      fontSize: 11, color: Colors.red.shade700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final String name;
  final double value;
  final double total;
  final String currency;

  const _CategoryBar({
    required this.name,
    required this.value,
    required this.total,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ratio =
        (total <= 0 ? 0.0 : (value / total).clamp(0.0, 1.0)).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name, style: const TextStyle(fontSize: 13)),
              ),
              Text(
                '${moneyWithCurrency(value, currency)} (${(ratio * 100).toStringAsFixed(0)}%)',
                style:
                    TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHighest,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
