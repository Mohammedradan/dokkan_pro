import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../utils/export.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'categories_screen.dart';
import 'help_screen.dart';
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
          _section(context, 'التنبيهات', [
            SwitchListTile(
              secondary: const Icon(Icons.notifications_active_outlined),
              title: const Text('تنبيه يومي لانتهاء الصلاحية'),
              subtitle: Text(state.notifyEnabled
                  ? 'كل يوم عند ${state.notifyTimeLabel}'
                  : 'مغلق'),
              value: state.notifyEnabled,
              onChanged: (v) => _toggleAlert(context, v),
            ),
            ListTile(
              enabled: state.notifyEnabled,
              leading: const Icon(Icons.schedule),
              title: const Text('وقت التنبيه اليومي'),
              subtitle: Text(state.notifyTimeLabel),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => _pickAlertTime(context),
            ),
          ]),
          _section(context, 'البيانات والنسخ الاحتياطي', [
            ListTile(
              leading: const Icon(Icons.ios_share_outlined),
              title: const Text('تصدير قائمة المنتجات (CSV)'),
              subtitle: const Text('مشاركة ملف Excel/CSV بالمنتجات'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => _exportCsv(context),
            ),
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('إنشاء نسخة احتياطية'),
              subtitle: const Text('حفظ نسخة من كل البيانات'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => _createBackup(context),
            ),
            ListTile(
              leading: const Icon(Icons.restore_outlined),
              title: const Text('النسخ الاحتياطية'),
              subtitle: const Text('استعادة أو حذف نسخة محفوظة'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => _showBackups(context),
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
          _section(context, 'مساعدة', [
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('المساعدة ودليل الاستخدام'),
              subtitle: const Text('شرح كامل لجميع أقسام التطبيق'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HelpScreen()),
              ),
            ),
          ]),
          _section(context, 'حول', [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('دكاني — إدارة البقالة'),
              subtitle: const Text('الإصدار 1.2.0 • يعمل بدون إنترنت'),
              onTap: () => showAboutDialog(
                context: context,
                applicationName: 'دكاني',
                applicationVersion: '1.2.0',
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

  Future<void> _toggleAlert(BuildContext context, bool enable) async {
    final state = context.read<AppState>();
    try {
      if (enable) {
        await NotificationService.instance.requestPermission();
      }
      await state.setDailyAlert(enable);
      await NotificationService.instance.rescheduleFrom(state);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(enable
              ? 'تم تفعيل التنبيه اليومي'
              : 'تم إيقاف التنبيه اليومي'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تعديل التنبيه: $e')),
      );
    }
  }

  Future<void> _pickAlertTime(BuildContext context) async {
    final state = context.read<AppState>();
    final now = DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: state.notifyHour, minute: state.notifyMinute),
      helpText: 'اختر وقت التنبيه اليومي',
    );
    if (picked == null) return;
    await state.setDailyAlert(true, hour: picked.hour, minute: picked.minute);
    await NotificationService.instance.rescheduleFrom(state);
  }

  Future<void> _exportCsv(BuildContext context) async {
    final state = context.read<AppState>();
    if (state.products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد منتجات للتصدير')),
      );
      return;
    }
    try {
      final path = await exportProductsCsv(state);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم التصدير: $path')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل التصدير: $e')),
      );
    }
  }

  Future<void> _createBackup(BuildContext context) async {
    final state = context.read<AppState>();
    try {
      final name = await state.createBackup();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم إنشاء النسخة الاحتياطية: $name')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل إنشاء النسخة: $e')),
      );
    }
  }

  Future<void> _showBackups(BuildContext context) async {
    final state = context.read<AppState>();
    final backups = await state.listBackups();
    if (!context.mounted) return;
    if (backups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد نسخ احتياطية بعد')),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('النسخ الاحتياطية'),
        contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final b in backups)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.storage_outlined),
                  title: Text(
                    (b['name'] as String).replaceFirst('backup_', ''),
                    style: const TextStyle(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${formatDateTime(b['modified'] as int)} • ${_size(b['size'] as int)}',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'استعادة',
                        icon: const Icon(Icons.restore,
                            size: 20, color: Colors.green),
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          await _restoreBackup(context, state,
                              b['path'] as String);
                        },
                      ),
                      IconButton(
                        tooltip: 'حذف',
                        icon: const Icon(Icons.delete_outline,
                            size: 20, color: Colors.red),
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          final ok = await confirmDialog(
                            context,
                            title: 'حذف النسخة',
                            message: 'حذف النسخة الاحتياطية نهائياً؟',
                            confirmText: 'حذف',
                            destructive: true,
                          );
                          if (!ok) return;
                          await state.deleteBackup(b['path'] as String);
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreBackup(
      BuildContext context, AppState state, String path) async {
    final ok = await confirmDialog(
      context,
      title: 'استعادة النسخة الاحتياطية',
      message: 'سيتم استبدال جميع البيانات الحالية بالنسخة المختارة. هل تريد المتابعة؟',
      confirmText: 'استعادة',
      destructive: true,
    );
    if (!ok) return;
    try {
      await state.restoreBackup(path);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت الاستعادة بنجاح')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشلت الاستعادة: $e')),
      );
    }
  }

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
