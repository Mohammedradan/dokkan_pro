import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/supplier.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'supplier_form_screen.dart';

class SuppliersScreen extends StatelessWidget {
  const SuppliersScreen({super.key});

  Future<void> _delete(BuildContext context, Supplier supplier) async {
    final state = context.read<AppState>();
    final ok = await confirmDialog(
      context,
      title: 'حذف المورد',
      message:
          'سيتم حذف «${supplier.name}». ستبقى المنتجات المرتبطة به بدون مورد.',
      confirmText: 'حذف',
      destructive: true,
    );
    if (!ok) return;
    await state.removeSupplier(supplier);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('تم حذف المورد')));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الموردون'),
        actions: [
          IconButton(
            tooltip: 'مورد جديد',
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const SupplierFormScreen()),
            ),
          ),
        ],
      ),
      body: state.suppliers.isEmpty
          ? const EmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'لا توجد موردون',
              subtitle: 'أضف مورديك لتسجيل الاستلامات عليهم',
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: state.suppliers.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, i) {
                final s = state.suppliers[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(Icons.local_shipping_outlined,
                        color: scheme.onPrimaryContainer),
                  ),
                  title: Text(s.name),
                  subtitle: Text(
                    [
                      if (s.phone.isNotEmpty) s.phone,
                      if (s.address.isNotEmpty) s.address,
                    ].join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'تعديل',
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => SupplierFormScreen(supplier: s)),
                        ),
                      ),
                      IconButton(
                        tooltip: 'حذف',
                        icon: const Icon(Icons.delete_outline,
                            size: 20, color: Colors.red),
                        onPressed: () => _delete(context, s),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
