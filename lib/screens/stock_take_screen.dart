import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// شاشة الجرد الفعلي: تدوين الكمية الموجودة فعلياً لكل منتج،
/// ثم تطبيق الفروقات تلقائياً كحركات تسوية (زيادة/نقص).
class StockTakeScreen extends StatefulWidget {
  const StockTakeScreen({super.key});

  @override
  State<StockTakeScreen> createState() => _StockTakeScreenState();
}

class _StockTakeScreenState extends State<StockTakeScreen> {
  final TextEditingController _search = TextEditingController();
  final Map<int, TextEditingController> _counted = {};
  String _query = '';
  bool _applying = false;

  @override
  void dispose() {
    _search.dispose();
    for (final c in _counted.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(Product p) {
    return _counted.putIfAbsent(p.id!, () => TextEditingController());
  }

  /// الفروقات: منتجات تختلف الكمية المدخلة فيها عن الفعلية.
  List<(Product, double)> _diffs(AppState state) {
    final result = <(Product, double)>[];
    for (final p in state.products) {
      final c = _counted[p.id];
      if (c == null) continue;
      final counted = double.tryParse(c.text.trim());
      if (counted == null) continue;
      final diff = counted - p.quantity;
      if (diff.abs() > 0.0001) result.add((p, diff));
    }
    return result;
  }

  Future<void> _apply(AppState state) async {
    final diffs = _diffs(state);
    if (diffs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد فروقات — أدخل الكميات الفعلية أولاً')),
      );
      return;
    }

    // ملخص قبل التطبيق
    final ok = await confirmDialog(
      context,
      title: 'تطبيق الجرد',
      message: 'سيتم تسجيل ${diffs.length} حركة تسوية:\n\n${diffs.map((e) => '• ${e.$1.name}: ${e.$2 > 0 ? '+' : ''}${formatQty(e.$2)} ${e.$1.unit}').join('\n')}\n\nهل تريد المتابعة؟',
      confirmText: 'تطبيق',
    );
    if (!ok) return;

    setState(() => _applying = true);
    try {
      await state.applyStockTake(diffs);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تطبيق الجرد: ${diffs.length} تسوية')),
      );
      // تصفير الحقول بعد النجاح
      for (final c in _counted.values) {
        c.clear();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تطبيق الجرد: $e')),
      );
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final query = _query.trim().toLowerCase();
    final items = state.products.where((p) {
      if (query.isEmpty) return true;
      return p.name.toLowerCase().contains(query);
    }).toList();
    final diffs = _diffs(state);

    return Scaffold(
      appBar: AppBar(
        title: const Text('جرد المخزون'),
        actions: [
          if (diffs.isNotEmpty)
            TextButton(
              onPressed: _applying ? null : () => _apply(state),
              child: _applying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('تطبيق (${diffs.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'بحث بالاسم...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: scheme.outline),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'أدخل الكمية الفعلية الموجودة، وسيُسجل الفرق تلقائياً كتسوية',
                    style: TextStyle(fontSize: 12, color: scheme.outline),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'لا توجد منتجات',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 72),
                    itemBuilder: (context, i) {
                      final p = items[i];
                      final controller = _controllerFor(p);
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 2),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: scheme.primaryContainer,
                          child: Text(
                            p.name.isEmpty ? '؟' : p.name.characters.first,
                            style: TextStyle(
                              fontSize: 14,
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          p.name,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'المسجل: ${formatQty(p.quantity)} ${p.unit}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: SizedBox(
                          width: 100,
                          child: TextField(
                            controller: controller,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [_qtyFormatter],
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'الفعلي',
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              suffixText: p.unit,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

final _qtyFormatter = FilteringTextInputFormatter.allow(
  RegExp(r'^\d*\.?\d{0,2}'),
);
