import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../state/app_state.dart';

/// خدمة التنبيهات: إشعار يومي مجدول بمواعيد انتهاء الصلاحية.
///
/// ملاحظة: نحسب الموعد المطلق الصحيح بدون الحاجة لمعرفة اسم المنطقة الزمنية
/// عبر تحويل الوقت المحلي إلى لحظة UTC، لأن `matchDateTimeComponents`
/// يعيد الجدولة حسب التوقيت المحلي لعنصر TZDateTime نفسه.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const int _expiryAlertId = 1001;
  static const String _channelId = 'expiry_alerts';
  static const String _channelName = 'تنبيهات الصلاحية';

  Future<void> _ensureReady() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(initSettings);
    _ready = true;
  }

  /// طلب إذن الإشعارات (مطلوب على أندرويد 13+).
  Future<void> requestPermission() async {
    await _ensureReady();
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// إعادة جدولة التنبيه اليومي حسب إعدادات المستخدم وحالة المخزون.
  /// يُستدعى عند فتح التطبيق وعند تغيير الإعدادات.
  Future<void> rescheduleFrom(AppState state) async {
    await _ensureReady();
    await _plugin.cancel(_expiryAlertId);
    if (!state.notifyEnabled) return;

    final expired = state.expiredBatches.length;
    final expiring = state.expiringSoonBatches.length;

    String message;
    if (expired == 0 && expiring == 0) {
      message = 'لا توجد دفعات منتهية أو قاربت على الانتهاء حالياً ✓';
    } else {
      message = expired > 0
          ? '$expired دفعة منتهية الصلاحية و $expiring دفعة تنتهي خلال 30 يوماً'
          : '$expiring دفعة تنتهي خلال 30 يوماً';
      message += ' — افتح دكاني للمراجعة';
    }

    // الموعد القادم بالوقت المحلي
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, state.notifyHour,
        state.notifyMinute);
    if (!target.isAfter(now)) {
      target = target.add(const Duration(days: 1));
    }

    // تحويل إلى لحظة UTC صحيحة ثم تمثيلها في UTC
    final tzTarget = tz.TZDateTime.from(target.toUtc(), tz.UTC);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'تنبيه يومي بالدفعات المنتهية والقريبة من الانتهاء',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _plugin.zonedSchedule(
      _expiryAlertId,
      'دكاني — تواريخ الصلاحية',
      message,
      tzTarget,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelAll() async {
    await _ensureReady();
    await _plugin.cancelAll();
  }

  /// إشعار فوري عند انخفاض مخزون منتج أو نفاذه (بعد حركة خروج).
  /// معرّف فريد لكل منتج حتى لا تتكدس الإشعارات.
  Future<void> showLowStockAlert({
    required int productId,
    required String productName,
    required double quantity,
    required String unit,
    required bool outOfStock,
  }) async {
    await _ensureReady();
    final details = const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'تنبيهات المخزون والصلاحية',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(
      2000 + productId,
      outOfStock ? 'نفد المخزون: $productName' : 'مخزون منخفض: $productName',
      outOfStock
          ? 'المنتج نفد بالكامل — أعد الطلب من المورد'
          : 'الكمية المتبقية: ${_fmt(quantity)} $unit — أعد الطلب من المورد',
      details,
    );
  }

  String _fmt(double v) {
    return v == v.roundToDouble()
        ? v.toInt().toString()
        : v.toStringAsFixed(2);
  }
}
