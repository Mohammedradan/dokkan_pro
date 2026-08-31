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
