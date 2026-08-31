import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/common.dart';
import 'categories_screen.dart';
import 'suppliers_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _editStore(BuildContext context) async {
    final state = context.read<AppState>();
    final nameController = TextEditingController(text: state.storeName);
    final currencyController = TextEditingController(text: state.currency);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('بيانات المتجر'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'اسم المتجر',
                prefixIcon: Icon(Icons.storefront_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: currencyController,
              decoration: const InputDecoration(
                labelText: 'رمز العملة',
                prefixIcon: Icon(Icons.payments_outlined),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              state.updateStoreInfo(
                name: nameController.text,
                currencySymbol: currencyController.text,
              );
              Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    nameController.dispose();
    currencyController.dispose();
  }

  Future<void> _loadDemoData(BuildContext context) async {
    final state = context.read<AppState>();
    final ok = await confirmDialog(
      context,
      title: 'بيانات تجريبية',
      message:
          'سيتم إضافة فئات وموردين ومنتجات تجريبية مع تواريخ صلاحية متنوعة. هل تريد المتابعة؟',
      confirmText: 'إضافة',
    );
    if (!ok) return;
    await state.loadDemoData();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تمت إضافة البيانات التجريبية')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _section(context, 'المتجر', [
            ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: const Text('بيانات المتجر'),
              subtitle: Text(
                  '${state.storeName} • العملة: ${state.currency}'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => _editStore(context),
            ),
          ]),
          _section(context, 'البيانات الأساسية', [
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('الفئات'),
              subtitle: Text('${state.categories.length} فئة'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const CategoriesScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.local_shipping_outlined),
              title: const Text('الموردون'),
              subtitle: Text('${state.suppliers.length} مورد'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const SuppliersScreen()),
              ),
            ),
          ]),
          _section(context, 'أدوات', [
            ListTile(
              leading: const Icon(Icons.science_outlined),
              title: const Text('تحميل بيانات تجريبية'),
              subtitle: const Text('فئات ومنتجات ودفعات جاهزة للتجربة'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => _loadDemoData(context),
            ),
          ]),
          _section(context, 'حول', [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('دكاني — إدارة البقالة'),
              subtitle: const Text('الإصدار 1.0.0 • يعمل بدون إنترنت'),
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'دكاني',
                applicationVersion: '1.0.0',
                applicationIcon: Icon(Icons.storefront,
                    size: 40, color: scheme.primary),
                children: const [
                  Text(
                    'نظام إدارة بقالة متكامل: منتجات، مخزون، موردون، '
                    'وتواريخ صلاحية.\n\n'
                    'بياناتك محفوظة محلياً على جهازك.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> tiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          child: Column(children: tiles),
        ),
      ],
    );
  }
}
