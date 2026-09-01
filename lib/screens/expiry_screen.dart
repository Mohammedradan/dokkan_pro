import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/stock_batch.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class ExpiryScreen extends StatefulWidget {
  final int initialTab;

  const ExpiryScreen({super.key, this.initialTab = 0});

  @override
  State<ExpiryScreen> createState() => _ExpiryScreenState();
}

class _ExpiryScreenState extends State<ExpiryScreen> {
  late int _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    final tabs = [
      ('منتهي', state.expiredBatches, Colors.red),
      ('ينتهي خلال 30 يوم', state.expiringSoonBatches, Colors.orange),
      ('بدون صلاحية قريبة', state.safeBatches, Colors.green),
    ];

    final (label, batches, color) = tabs[_tab];

    return Scaffold(
      appBar: AppBar(
        title: const Text('تواريخ الصلاحية'),
        actions: [
          if (state.expiredBatches.isNotEmpty && _tab == 0)
            TextButton.icon(
              onPressed: () => _wasteAll(context, state),
              icon: const Icon(Icons.delete_sweep_outlined, size: 18),
              label: Text('إتلاف المنتهي (${state.expiredBatches.length})'),
            ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      avatar: Text('${tabs[i].$2.length}',
                          style: const TextStyle(fontSize: 12)),
                      label: Text(tabs[i].$1),
                      selected: _tab == i,
                      onSelected: (_) => setState(() => _tab = i),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: batches.isEmpty
                ? EmptyState(
                    icon: Icons.event_available,
                    title: 'لا توجد دفعات $label',
                    subtitle: 'ممتاز! كل شيء تحت السيطرة',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: batches.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 72),
                    itemBuilder: (context, i) {
                      final b = batches[i];
                      final p = state.productById(b.productId);
                      return _ExpiryTile(
                        batch: b,
                        product: p,
                        color: color,
                        onWaste: (p != null && _tab != 2)
                            ? () => _waste(context, state, p, b)
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _wasteAll(BuildContext context, AppState state) async {
    final count = state.expiredBatches.length;
    if (count == 0) return;
    final ok = await confirmDialog(
      context,
      title: 'إتلاف كل الدفعات المنتهية',
      message:
          'سيتم إتلاف $count دفعة منتهية الصلاحية وتسجيلها كحركات هالك. هل تريد المتابعة؟',
      confirmText: 'إتلاف الكل',
      destructive: true,
    );
    if (!ok) return;
    final n = await state.wasteAllExpired();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم إتلاف $n دفعة منتهية')),
    );
  }

  Future<void> _waste(BuildContext context, AppState state, Product p,
      StockBatch b) async {
    final ok = await confirmDialog(
      context,
      title: 'إتلاف الدفعة',
      message:
          'سيتم إتلاف ${formatQty(b.quantity)} ${p.unit} من «${p.name}» وتسجيل حركة هالك.',
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
}

class _ExpiryTile extends StatelessWidget {
  final StockBatch batch;
  final Product? product;
  final Color color;
  final VoidCallback? onWaste;

  const _ExpiryTile({
    required this.batch,
    required this.product,
    required this.color,
    this.onWaste,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = product?.name ?? 'منتج محذوف';
    final unit = product?.unit ?? 'قطعة';
    final expiry = batch.expiryDate;
    final days = expiry != null ? daysUntil(expiry) : null;

    String statusText;
    if (expiry == null) {
      statusText = 'بدون تاريخ صلاحية';
    } else if (days! < 0) {
      statusText = 'منتهي منذ ${-days} يوم';
    } else if (days == 0) {
      statusText = 'ينتهي اليوم';
    } else {
      statusText = 'باقي $days يوم';
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.12),
        child: Icon(Icons.event_busy_outlined, color: color, size: 20),
      ),
      title: Text(name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '$statusText • ${formatQty(batch.quantity)} $unit',
        style: TextStyle(
          fontSize: 12.5,
          color: days != null && days < 0
              ? Colors.red
              : scheme.onSurfaceVariant,
          fontWeight: days != null && days < 0 ? FontWeight.bold : null,
        ),
      ),
      trailing: onWaste != null
          ? TextButton(
              onPressed: onWaste,
              child: const Text('إتلاف',
                  style: TextStyle(color: Colors.red, fontSize: 12.5)),
            )
          : null,
    );
  }
}
