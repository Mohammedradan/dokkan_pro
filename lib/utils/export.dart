import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../state/app_state.dart';

/// تصدير قائمة المنتجات إلى ملف CSV ومشاركته عبر نظام المشاركة في أندرويد.
/// يعيد مسار الملف عند النجاح.
Future<String?> exportProductsCsv(AppState state) async {
  final csv = state.buildProductsCsv();
  final docs = await getApplicationDocumentsDirectory();
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final file = File('${docs.path}/dokkan_products_$stamp.csv');
  await file.writeAsString(csv, flush: true);
  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'text/csv')],
    text: 'قائمة منتجات دكاني',
  );
  return file.path;
}

/// تصدير سجل الحركات إلى CSV ومشاركته.
Future<String?> exportMovementsCsv(AppState state) async {
  final csv = state.buildMovementsCsv();
  final docs = await getApplicationDocumentsDirectory();
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final file = File('${docs.path}/dokkan_movements_$stamp.csv');
  await file.writeAsString(csv, flush: true);
  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'text/csv')],
    text: 'سجل حركات دكاني',
  );
  return file.path;
}

/// تصدير تقرير الصلاحية إلى CSV ومشاركته.
Future<String?> exportExpiryCsv(AppState state) async {
  final csv = state.buildExpiryCsv();
  final docs = await getApplicationDocumentsDirectory();
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final file = File('${docs.path}/dokkan_expiry_$stamp.csv');
  await file.writeAsString(csv, flush: true);
  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'text/csv')],
    text: 'تقرير الصلاحية — دكاني',
  );
  return file.path;
}
