import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/supplier.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// حساب المورد: الرصيد المستحق، سجل الاستلامات، وسجل المدفوعات.
class SupplierAccountScreen extends StatelessWidget {
  final Supplier supplier;

  const SupplierAccountScreen({super.key, required this.supplier});

  Future<void> _addPayment(BuildContext context) async {
    final state = context.read<AppState>();
    final amount = TextEditingController();
    final note = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل دفعة للمورد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amount,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [_amountFormatter],
              decoration: const InputDecoration(
                labelText: 'المبلغ *',
                prefixIcon: Icon(Icons.payments_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              decoration: const InputDecoration(
                labelText: 'ملاحظة (اختياري)',
                prefixIcon: Icon(Icons.notes),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    final value = double.tryParse(amount.text.trim());
    amount.dispose();
    note.dispose();
    if (ok != true || value == null || value <= 0) return;

    try {
      await state.addSupplierPayment(
        supplierId: supplier.id!,
        amount: value,
        note: note.text.trim(),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل الدفعة')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _deletePayment(BuildContext context, int paymentId) async {
    final state = context.read<AppState>();
    final ok = await confirmDialog(
      context,
      title: 'حذف الدفعة',
      message: 'هل تريد حذف هذه الدفعة نهائياً؟',
      confirmText: 'حذف',
      destructive: true,
    );
    if (!ok) return;
    await state.removeSupplierPayment(paymentId);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;

    final balance = state.supplierBalance(supplier.id!);
    final receives = state.movements.where((m) =>
        m.type == 'receive' && m.supplierId == supplier.id);
    final payments = state.paymentsOf(supplier.id!);
    var totalReceived = 0.0;
    for (final m in receives) {
      totalReceived += m.quantity * (m.unitCost ?? 0);
    }
    var totalPaid = 0.0;
    for (final p in payments) {
      totalPaid += (p['amount'] as num).toDouble();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(supplier.name,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'تسجيل دفعة',
            icon: const Icon(Icons.payments_outlined),
            onPressed: () => _addPayment(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // بطاقة الرصيد
          Card(
            elevation: 0,
            margin: const EdgeInsets.all(16),
            color: scheme.surfaceContainerLow,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    moneyWithCurrency(balance, state.currency),
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: balance > 0.001
                          ? Colors.red.shade700
                          : Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    balance > 0.001 ? 'رصيد مستحق للمورد' : 'لا يوجد رصيد مستحق',
                    style: TextStyle(
                        fontSize: 13, color: scheme.onSurfaceVariant),
                  ),
                  const Divider(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: _miniStat(
                          'إجمالي الاستلامات',
                          moneyWithCurrency(totalReceived, state.currency),
                          scheme,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _miniStat(
                          'إجمالي المدفوعات',
                          moneyWithCurrency(totalPaid, state.currency),
                          scheme,
                        ),
                      ),
                    ],
                  ),
                  if (supplier.phone.isNotEmpty || supplier.address.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        [
                          if (supplier.phone.isNotEmpty) supplier.phone,
                          if (supplier.address.isNotEmpty) supplier.address,
                        ].join(' • '),
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // الاستلامات
          SectionCard(
            title: 'استلامات البضاعة (${receives.length})',
            child: receives.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('لا توجد استلامات مسجلة لهذا المورد'),
                  )
                : Column(
                    children: [
                      for (final m in receives.take(50))
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.move_to_inbox_rounded,
                              size: 20, color: Colors.green),
                          title: Text(
                            state.productById(m.productId)?.name ?? 'منتج محذوف',
                            style: const TextStyle(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${formatDateTime(m.createdAt)} • ${formatQty(m.quantity)}',
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          trailing: Text(
                            moneyWithCurrency(
                                m.quantity * (m.unitCost ?? 0), state.currency),
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
          ),

          // المدفوعات
          SectionCard(
            title: 'المدفوعات (${payments.length})',
            child: payments.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('لم تُسجل أي دفعات بعد'),
                  )
                : Column(
                    children: [
                      for (final p in payments)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.payments_outlined,
                              size: 20, color: Colors.indigo),
                          title: Text(
                            (p['note'] as String).isEmpty
                                ? 'دفعة'
                                : p['note'] as String,
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: Text(
                            formatDateTime(p['created_at'] as int),
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '- ${moneyWithCurrency((p['amount'] as num).toDouble(), state.currency)}',
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red),
                              ),
                              IconButton(
                                tooltip: 'حذف',
                                icon: const Icon(Icons.delete_outline,
                                    size: 18, color: Colors.red),
                                onPressed: () => _deletePayment(
                                    context, p['id'] as int),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

final _amountFormatter = FilteringTextInputFormatter.allow(
  RegExp(r'^\d*\.?\d{0,2}'),
);
