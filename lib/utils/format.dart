import 'package:intl/intl.dart';

final NumberFormat _numberFormat = NumberFormat('#,##0.##');
final DateFormat _dateFormat = DateFormat('yyyy/MM/dd');

/// تنسيق كمية: 12.5
String formatQty(double value) {
  if (value == value.roundToDouble()) {
    return NumberFormat('#,##0').format(value);
  }
  return _numberFormat.format(value);
}

/// تنسيق مبلغ: 1,250.75
String formatMoney(double value) {
  return _numberFormat.format(value);
}

String formatDate(int? millis) {
  if (millis == null) return '-';
  return _dateFormat.format(DateTime.fromMillisecondsSinceEpoch(millis));
}

String formatDateTime(int millis) {
  final d = DateTime.fromMillisecondsSinceEpoch(millis);
  final hm = DateFormat('HH:mm').format(d);
  return '${_dateFormat.format(d)} $hm';
}

/// عدد الأيام من اليوم حتى التاريخ المحدد (سالب = منتهي).
int daysUntil(int millis) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime.fromMillisecondsSinceEpoch(millis);
  final day = DateTime(target.year, target.month, target.day);
  return day.difference(today).inDays;
}

String qtyWithUnit(double qty, String unit) {
  return '${formatQty(qty)} $unit';
}

String moneyWithCurrency(double value, String currency) {
  if (currency.isEmpty) return formatMoney(value);
  return '${formatMoney(value)} $currency';
}
