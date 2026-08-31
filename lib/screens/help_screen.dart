import 'package:flutter/material.dart';

/// صفحة التعليمات ودليل الاستخدام داخل التطبيق.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المساعدة ودليل الاستخدام')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: const [
          _HelpSection(
            icon: Icons.rocket_launch_outlined,
            title: 'البدء السريع (أول مرة)',
            color: Colors.teal,
            steps: [
              '1. من «الإعدادات» أضف فئات منتجاتك (خضار، ألبان، مشروبات...).',
              '2. أضف مورديك من «الإعدادات ← الموردون».',
              '3. من «المنتجات» اضغط + لإضافة أول منتج وحدد فئته ومورده.',
              '4. سجّل أول استلام من زر «استلام» العائم.',
              '5. جرّب «تحميل بيانات تجريبية» من الإعدادات لاستكشاف النظام.',
            ],
          ),
          _HelpSection(
            icon: Icons.qr_code_scanner,
            title: 'مسح الباركود',
            color: Colors.indigo,
            steps: [
              '1. من شاشة «المنتجات» اضغط أيقونة الماسح أعلى الشاشة.',
              '2. وجّه الكاميرا نحو الباركود وسيُفتح المنتج مباشرة إن كان مسجلاً.',
              '3. إن كان المنتج جديداً سيُفتح نموذج الإضافة مع تعبئة الباركود تلقائياً.',
              '4. يمكنك أيضاً المسح من داخل نموذج المنتج عبر أيقونة الماسح في حقل الباركود.',
            ],
          ),
          _HelpSection(
            icon: Icons.move_to_inbox_outlined,
            title: 'حركات المخزون',
            color: Colors.green,
            steps: [
              'استلام: إضافة كمية من مورد مع سعر التكلفة وتاريخ الصلاحية (اختياري).',
              'تسوية زيادة / نقص: تصحيح كمية بعد جرد فعلي.',
              'هالك: إتلاف كمية تالفة (يُسجل في التقارير كخسارة).',
              'مرتجع للمورد: إرجاع كمية للمورد.',
              'أي حركة خروج تخصم تلقائياً من الدفعات الأقدم أولاً (FIFO).',
            ],
          ),
          _HelpSection(
            icon: Icons.event_outlined,
            title: 'تواريخ الصلاحية',
            color: Colors.orange,
            steps: [
              'كل استلام ينشئ «دفعة» جديدة قد تحمل تاريخ صلاحية.',
              'تبويب «الصلاحية» يعرض: المنتهي، ما ينتهي خلال 30 يوماً، والباقي.',
              'يمكنك إتلاف دفعة منتهية بضغطة واحدة (تُسجل كحركة هالك).',
              'فعّل «التنبيه اليومي» من الإعدادات ليصلك إشعار يومي بالدفعات القاربة على الانتهاء.',
            ],
          ),
          _HelpSection(
            icon: Icons.bar_chart_outlined,
            title: 'التقارير',
            color: Colors.blue,
            steps: [
              'قيمة المخزون الكلية وتوزيعها حسب الفئة.',
              'إجمالي تكلفة الاستلامات وقيمة الهالك (لقياس الفاقد).',
              'عدد الحركات في آخر 30 يوم وأعلى 5 منتجات قيمة بالمخزون.',
            ],
          ),
          _HelpSection(
            icon: Icons.backup_outlined,
            title: 'نسخ احتياطي وتصدير',
            color: Colors.purple,
            steps: [
              'أنشئ نسخة احتياطية دورياً من «الإعدادات» واحتفظ بها في أمان.',
              'عند تغيير الجهاز أو إعادة التثبيت استعد النسخة لاسترجاع كل بياناتك.',
              'صدّر قائمة المنتجات CSV لمشاركتها أو فتحها في Excel.',
              'جميع البيانات محفوظة محلياً على جهازك — لا تحتاج إنترنت.',
            ],
          ),
          _HelpSection(
            icon: Icons.tips_and_updates_outlined,
            title: 'نصائح',
            color: Colors.amber,
            steps: [
              'حدد «حد الطلب الأدنى» لكل منتج ليظهر تنبيه عند اقتراب النفاد.',
              'سجّل سعر التكلفة عند الاستلام ليُحسب هامش الربح وقيمة المخزون بدقة.',
              'بعد كل جرد فعلي، استخدم «تسوية نقص/زيادة» بدل تعديل الكمية يدوياً.',
            ],
          ),
        ],
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final List<String> steps;

  const _HelpSection({
    required this.icon,
    required this.title,
    required this.color,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final step in steps)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  step,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
