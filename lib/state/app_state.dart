import 'package:flutter/foundation.dart';

import '../db/database.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/stock_batch.dart';
import '../models/stock_movement.dart';
import '../models/supplier.dart';

class AppState extends ChangeNotifier {
  final AppDatabase db;

  AppState(this.db);

  bool loaded = false;

  List<Category> categories = [];
  List<Supplier> suppliers = [];
  List<Product> products = [];
  List<StockMovement> movements = [];
  Map<int, List<StockBatch>> _batches = {};
  List<Map<String, Object?>> supplierPayments = [];

  String storeName = 'بقالتي';
  String currency = 'ج.م';

  // إعدادات التنبيه اليومي للصلاحية
  bool notifyEnabled = false;
  int notifyHour = 9;
  int notifyMinute = 0;

  // إعدادات التنبيه الفوري عند انخفاض المخزون
  bool lowStockAlertEnabled = false;

  // إعدادات المظهر
  String themeMode = 'system'; // system | light | dark

  // إعدادات قفل التطبيق برقم سري
  bool pinEnabled = false;
  String _pinCode = '';

  // ===================== التحميل =====================

  Future<void> init() async {
    storeName = (await db.getSetting('store_name')) ?? 'بقالتي';
    currency = (await db.getSetting('currency')) ?? 'ج.م';
    notifyEnabled = (await db.getSetting('daily_expiry_alert')) == '1';
    final timeStr = await db.getSetting('daily_expiry_alert_time');
    if (timeStr != null) {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        notifyHour = int.tryParse(parts[0]) ?? 9;
        notifyMinute = int.tryParse(parts[1]) ?? 0;
      }
    }
    lowStockAlertEnabled =
        (await db.getSetting('low_stock_alert')) == '1';
    themeMode = (await db.getSetting('theme_mode')) ?? 'system';
    pinEnabled = (await db.getSetting('pin_enabled')) == '1';
    _pinCode = (await db.getSetting('pin_code')) ?? '';
    await reloadAll();
  }

  Future<void> reloadAll() async {
    categories = await db.getCategories();
    suppliers = await db.getSuppliers();
    products = await db.getProducts();
    movements = await db.getMovements();
    supplierPayments = await db.getAllSupplierPayments();
    _batches = {};
    for (final p in products) {
      _batches[p.id!] = await db.getBatchesForProduct(p.id!);
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> reloadProductBatches(int productId) async {
    _batches[productId] = await db.getBatchesForProduct(productId);
  }

  List<StockBatch> batchesOf(int productId) => _batches[productId] ?? [];

  // ===================== الإعدادات =====================

  Future<void> updateStoreInfo({String? name, String? currencySymbol}) async {
    if (name != null && name.trim().isNotEmpty) {
      storeName = name.trim();
      await db.setSetting('store_name', storeName);
    }
    if (currencySymbol != null) {
      currency = currencySymbol.trim();
      await db.setSetting('currency', currency);
    }
    notifyListeners();
  }

  // ===================== الفئات =====================

  Future<void> addCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final exists = categories.any(
        (c) => c.name.toLowerCase() == trimmed.toLowerCase());
    if (exists) throw Exception('هذه الفئة موجودة بالفعل');
    await db.insertCategory(trimmed);
    await reloadAll();
  }

  Future<void> renameCategory(Category category, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    final exists = categories.any((c) =>
        c.id != category.id && c.name.toLowerCase() == trimmed.toLowerCase());
    if (exists) throw Exception('هذه الفئة موجودة بالفعل');
    await db.updateCategory(category.copyWith(name: trimmed));
    await reloadAll();
  }

  Future<void> removeCategory(Category category) async {
    final used = await db.countProductsInCategory(category.id!);
    if (used > 0) {
      throw Exception('لا يمكن حذف الفئة: يوجد $used منتج مرتبط بها');
    }
    await db.deleteCategory(category.id!);
    await reloadAll();
  }

  // ===================== الموردون =====================

  Future<void> addSupplier(Supplier supplier) async {
    await db.insertSupplier(supplier);
    await reloadAll();
  }

  Future<void> updateSupplier(Supplier supplier) async {
    await db.updateSupplier(supplier);
    await reloadAll();
  }

  Future<void> removeSupplier(Supplier supplier) async {
    await db.deleteSupplier(supplier.id!);
    await reloadAll();
  }

  // ===================== المنتجات =====================

  Future<void> addProduct(Product product) async {
    await db.insertProduct(product);
    await reloadAll();
  }

  Future<void> updateProduct(Product product) async {
    await db.updateProduct(product);
    await reloadAll();
  }

  Future<void> removeProduct(Product product) async {
    await db.deleteProduct(product.id!);
    await reloadAll();
  }

  /// إضافة حركة مخزون وتحديث الكمية والدفعات في معاملة واحدة.
  /// يعيد معلومات مفيدة للواجهة (هل انخفض المخزون عن الحد؟).
  Future<MovementResult> addMovement({
    required Product product,
    required String type,
    required double quantity,
    double? unitCost,
    int? supplierId,
    int? expiryDate,
    String note = '',
  }) async {
    final result = await _recordMovement(
      product: product,
      type: type,
      quantity: quantity,
      unitCost: unitCost,
      supplierId: supplierId,
      expiryDate: expiryDate,
      note: note,
    );
    await reloadAll();
    return result;
  }

  Future<MovementResult> _recordMovement({
    required Product product,
    required String type,
    required double quantity,
    double? unitCost,
    int? supplierId,
    int? expiryDate,
    String note = '',
  }) async {
    if (quantity <= 0) {
      throw Exception('الكمية يجب أن تكون أكبر من صفر');
    }
    final isIncoming = type == 'receive' || type == 'adjust_in';
    final isOutgoing = !isIncoming;

    // التحقق من توفر الكمية للحركات الخارجة
    if (isOutgoing && product.quantity < quantity) {
      throw Exception(
          'الكمية المتوفرة ${_fmt(product.quantity)} ${product.unit} فقط');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    int? batchId;

    if (type == 'receive') {
      batchId = await db.insertBatch(StockBatch(
        productId: product.id!,
        quantity: quantity,
        expiryDate: expiryDate,
        receivedAt: now,
      ));
    }

    await db.insertMovement(StockMovement(
      productId: product.id!,
      type: type,
      quantity: quantity,
      unitCost: unitCost,
      supplierId: supplierId,
      batchId: batchId,
      note: note,
      createdAt: now,
    ));

    final newQty = isIncoming
        ? product.quantity + quantity
        : product.quantity - quantity;
    await db.updateProductQuantity(product.id!, newQty);

    if (isOutgoing) {
      await db.deductFromBatches(product.id!, quantity);
    }

    return MovementResult(
      newQuantity: newQty,
      lowStock: !isIncoming &&
          newQty <= product.minStock &&
          (product.minStock > 0 || newQty <= 0),
      outOfStock: !isIncoming && newQty <= 0,
    );
  }

  /// تطبيق جرد فعلي: تسجيل فروقات الدفعة الواحدة كحركات تسوية دفعة واحدة.
  Future<void> applyStockTake(List<(Product, double)> diffs) async {
    for (final (product, diff) in diffs) {
      if (diff.abs() < 0.0001) continue;
      if (diff > 0) {
        await _recordMovement(
          product: product,
          type: 'adjust_in',
          quantity: diff,
          note: 'ضبط جرد',
        );
      } else {
        await _recordMovement(
          product: product,
          type: 'adjust_out',
          quantity: -diff,
          note: 'ضبط جرد',
        );
      }
    }
    await reloadAll();
  }

  /// إتلاف دفعة كاملة (منتهية الصلاحية مثلاً).
  Future<void> wasteBatch(Product product, StockBatch batch) async {
    await _recordWaste(product, batch);
    await reloadAll();
  }

  Future<void> _recordWaste(Product product, StockBatch batch) async {
    if (batch.quantity <= 0) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insertMovement(StockMovement(
      productId: product.id!,
      type: 'waste',
      quantity: batch.quantity,
      note: 'إتلاف دفعة${batch.expiryDate != null ? ' (منتهية الصلاحية)' : ''}',
      batchId: batch.id,
      createdAt: now,
    ));
    final newQty = product.quantity - batch.quantity;
    await db.updateProductQuantity(product.id!, newQty < 0 ? 0 : newQty);
    await db.deleteBatch(batch.id!);
  }

  /// إتلاف كل الدفعات المنتهية دفعة واحدة. يعيد عدد الدفعات المتلفة.
  Future<int> wasteAllExpired() async {
    final expired = expiredBatches;
    for (final b in expired) {
      final p = productById(b.productId);
      if (p == null) continue;
      await _recordWaste(p, b);
    }
    await reloadAll();
    return expired.length;
  }

  Future<void> loadDemoData() async {
    await db.loadDemoData();
    await reloadAll();
  }

  // ===================== التنبيهات =====================

  String get notifyTimeLabel =>
      '${notifyHour.toString().padLeft(2, '0')}:${notifyMinute.toString().padLeft(2, '0')}';

  Future<void> setDailyAlert(bool enabled, {int? hour, int? minute}) async {
    notifyEnabled = enabled;
    if (hour != null) notifyHour = hour;
    if (minute != null) notifyMinute = minute;
    await db.setSetting('daily_expiry_alert', enabled ? '1' : '0');
    await db.setSetting(
        'daily_expiry_alert_time', notifyTimeLabel);
    notifyListeners();
  }

  Future<void> setLowStockAlert(bool enabled) async {
    lowStockAlertEnabled = enabled;
    await db.setSetting('low_stock_alert', enabled ? '1' : '0');
    notifyListeners();
  }

  // ===================== حسابات الموردين =====================

  /// الرصيد المستحق للمورد: قيمة الاستلامات - المدفوعات.
  double supplierBalance(int supplierId) {
    var balance = 0.0;
    for (final m in movements) {
      if (m.type == 'receive' && m.supplierId == supplierId) {
        balance += m.quantity * (m.unitCost ?? 0);
      }
    }
    for (final p in supplierPayments) {
      if (p['supplier_id'] == supplierId) {
        balance -= (p['amount'] as num).toDouble();
      }
    }
    return balance;
  }

  List<Map<String, Object?>> paymentsOf(int supplierId) {
    return supplierPayments
        .where((p) => p['supplier_id'] == supplierId)
        .toList();
  }

  Future<void> addSupplierPayment({
    required int supplierId,
    required double amount,
    String note = '',
  }) async {
    if (amount <= 0) throw Exception('المبلغ يجب أن يكون أكبر من صفر');
    await db.insertSupplierPayment(
      supplierId: supplierId,
      amount: amount,
      note: note,
    );
    await reloadAll();
  }

  Future<void> removeSupplierPayment(int paymentId) async {
    await db.deleteSupplierPayment(paymentId);
    await reloadAll();
  }

  // ===================== قائمة الطلب المقترحة =====================

  /// منتجات تحتاج إعادة طلب (أقل من حد الطلب أو نافدة).
  List<Product> get reorderProducts {
    final list = [...lowStockProducts, ...outOfStockProducts];
    final seen = <int>{};
    return list.where((p) {
      final ok = seen.add(p.id!);
      return ok;
    }).toList();
  }

  /// الكمية المقترح طلبها = سد العجز حتى ضعف حد الطلب الأدنى.
  double suggestedOrderQty(Product p) {
    if (p.minStock <= 0) return 0;
    final target = p.minStock * 2;
    final needed = target - p.quantity;
    return needed < 0 ? 0 : needed;
  }

  /// بناء CSV لقائمة الطلب المقترحة.
  String buildReorderCsv() {
    final sb = StringBuffer();
    sb.write('\uFEFF');
    sb.writeln('المورد,المنتج,الكمية الحالية,الحد الأدنى,الكمية المطلوبة,الوحدة');
    final bySupplier = <int?, List<Product>>{};
    for (final p in reorderProducts) {
      bySupplier.putIfAbsent(p.supplierId, () => []).add(p);
    }
    for (final entry in bySupplier.entries) {
      final supName = supplierById(entry.key)?.name ?? 'بدون مورد';
      for (final p in entry.value) {
        final row = [
          supName,
          p.name,
          _fmt(p.quantity),
          _fmt(p.minStock),
          _fmt(suggestedOrderQty(p)),
          p.unit,
        ].map(_csvField).join(',');
        sb.writeln(row);
      }
    }
    return sb.toString();
  }

  // ===================== هامش الربح =====================

  double profitMargin(Product p) => p.sellPrice - p.costPrice;

  double? profitMarginPercent(Product p) {
    if (p.costPrice <= 0) return null;
    return ((p.sellPrice - p.costPrice) / p.costPrice) * 100;
  }

  /// هل يوجد منتج آخر بنفس الباركود (غير هذا المنتج)؟
  bool barcodeExists(String barcode, {int? excludeId}) {
    final b = barcode.trim().toLowerCase();
    if (b.isEmpty) return false;
    for (final p in products) {
      if (p.barcode.trim().toLowerCase() == b && p.id != excludeId) {
        return true;
      }
    }
    return false;
  }

  // ===================== المظهر =====================

  Future<void> setThemeMode(String mode) async {
    themeMode = mode;
    await db.setSetting('theme_mode', mode);
    notifyListeners();
  }

  // ===================== قفل التطبيق (PIN) =====================

  bool get hasPin => _pinCode.isNotEmpty;

  Future<void> setPin(String code) async {
    _pinCode = code;
    await db.setSetting('pin_code', code);
    notifyListeners();
  }

  Future<void> setPinEnabled(bool enabled) async {
    pinEnabled = enabled;
    await db.setSetting('pin_enabled', enabled ? '1' : '0');
    notifyListeners();
  }

  bool verifyPin(String input) =>
      _pinCode.isNotEmpty && input == _pinCode;

  // ===================== استيراد المنتجات من CSV =====================

  /// استيراد منتجات من ملف CSV (نفس تنسيق التصدير).
  /// الأعمدة: الاسم، الباركود، الفئة، المورد، الوحدة، سعر التكلفة،
  /// سعر البيع، الحد الأدنى، الكمية — مع أو بدون صف العناوين.
  Future<ImportResult> importProductsCsv(String content) async {
    final rows = _parseCsv(content);
    if (rows.isEmpty) {
      throw Exception('الملف فارغ أو غير صالح');
    }

    // كشف صف العناوين
    Map<String, int>? header;
    var start = 0;
    final first = rows.first.map((c) => c.trim()).toList();
    if (first.contains('الاسم') || first.contains('name')) {
      header = {};
      for (var i = 0; i < first.length; i++) {
        header[first[i]] = i;
      }
      start = 1;
    }

    var added = 0;
    var skipped = 0;
    final errors = <String>[];
    final now = DateTime.now().millisecondsSinceEpoch;

    for (var r = start; r < rows.length; r++) {
      final row = rows[r];
      if (row.every((c) => c.trim().isEmpty)) continue;

      String cell(int idx) =>
          (idx >= 0 && idx < row.length) ? row[idx].trim() : '';

      String named(String ar, String en) {
        final i = header?[ar] ?? header?[en];
        return cell(i ?? -1);
      }

      final name = header != null ? named('الاسم', 'name') : cell(0);
      if (name.isEmpty) {
        skipped++;
        continue;
      }
      final barcode =
          header != null ? named('الباركود', 'barcode') : cell(1);
      if (barcode.isNotEmpty && barcodeExists(barcode)) {
        skipped++;
        continue;
      }

      int? categoryId;
      final catName = header != null ? named('الفئة', 'category') : cell(2);
      if (catName.isNotEmpty) {
        categoryId = await _categoryIdByName(catName);
      }

      int? supplierId;
      final supName =
          header != null ? named('المورد', 'supplier') : cell(3);
      if (supName.isNotEmpty) {
        supplierId = await _supplierIdByName(supName);
      }

      var unit = header != null ? named('الوحدة', 'unit') : cell(4);
      if (unit.isEmpty) unit = 'قطعة';

      double num(String s) =>
          double.tryParse(s.replaceAll(',', '').trim()) ?? 0;
      final cost =
          num(header != null ? named('سعر التكلفة', 'cost_price') : cell(5));
      final sell =
          num(header != null ? named('سعر البيع', 'sell_price') : cell(6));
      final minStock =
          num(header != null ? named('الحد الأدنى', 'min_stock') : cell(7));
      final qty =
          num(header != null ? named('الكمية', 'quantity') : cell(8));

      try {
        await db.insertProduct(Product(
          name: name,
          barcode: barcode,
          categoryId: categoryId,
          supplierId: supplierId,
          unit: unit,
          costPrice: cost,
          sellPrice: sell,
          minStock: minStock,
          quantity: qty,
          notes: '',
          createdAt: now,
          updatedAt: now,
        ));
        added++;
      } catch (e) {
        errors.add('سطر ${r + 1} ($name): $e');
      }
    }

    await reloadAll();
    return ImportResult(added: added, skipped: skipped, errors: errors);
  }

  Future<int> _categoryIdByName(String name) async {
    final n = name.trim();
    for (final c in categories) {
      if (c.name == n) return c.id!;
    }
    final id = await db.insertCategory(n);
    categories = await db.getCategories();
    return id;
  }

  Future<int> _supplierIdByName(String name) async {
    final n = name.trim();
    for (final s in suppliers) {
      if (s.name == n) return s.id!;
    }
    final id = await db.insertSupplier(Supplier(
      name: n,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
    suppliers = await db.getSuppliers();
    return id;
  }

  /// محلل CSV بسيط يدعم الحقول المقتبسة والفاصلة داخلها.
  List<List<String>> _parseCsv(String text) {
    final rows = <List<String>>[];
    var row = <String>[];
    var field = StringBuffer();
    var inQuotes = false;
    final src = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceFirst('\uFEFF', '');
    for (var i = 0; i < src.length; i++) {
      final ch = src[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < src.length && src[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(ch);
        }
      } else {
        if (ch == '"') {
          inQuotes = true;
        } else if (ch == ',') {
          row.add(field.toString());
          field = StringBuffer();
        } else if (ch == '\n') {
          row.add(field.toString());
          if (row.isNotEmpty) rows.add(row);
          row = <String>[];
          field = StringBuffer();
        } else {
          field.write(ch);
        }
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      if (row.isNotEmpty) rows.add(row);
    }
    return rows;
  }

  // ===================== النسخ الاحتياطي والتصدير =====================

  Future<String> createBackup() => db.createBackup();

  Future<List<Map<String, Object?>>> listBackups() => db.listBackups();

  Future<void> restoreBackup(String backupPath) async {
    await db.restoreBackup(backupPath);
    await reloadAll();
  }

  Future<void> deleteBackup(String backupPath) => db.deleteBackup(backupPath);

  /// بناء ملف CSV لقائمة المنتجات (مع BOM لدعم العربية في Excel).
  String buildProductsCsv() {
    final sb = StringBuffer();
    sb.write('\uFEFF');
    sb.writeln(
        'الاسم,الباركود,الفئة,المورد,الوحدة,سعر التكلفة,سعر البيع,الحد الأدنى,الكمية,الحالة');
    for (final p in products) {
      final cat = categoryById(p.categoryId)?.name ?? '';
      final sup = supplierById(p.supplierId)?.name ?? '';
      final row = [
        p.name,
        p.barcode,
        cat,
        sup,
        p.unit,
        p.costPrice.toString(),
        p.sellPrice.toString(),
        p.minStock.toString(),
        p.quantity.toString(),
        p.stockStatus(),
      ].map(_csvField).join(',');
      sb.writeln(row);
    }
    return sb.toString();
  }

  /// بناء ملف CSV لسجل الحركات.
  String buildMovementsCsv() {
    final sb = StringBuffer();
    sb.write('\uFEFF');
    sb.writeln('التاريخ,المنتج,النوع,الكمية,سعر التكلفة,المورد,ملاحظة');
    for (final m in movements) {
      final p = productById(m.productId);
      final sup = supplierById(m.supplierId);
      final row = [
        formatDateTime(m.createdAt),
        p?.name ?? '',
        movementTypeLabel(m.type),
        '${m.isIncoming ? '+' : '-'}${_fmt(m.quantity)} ${p?.unit ?? ''}',
        m.unitCost?.toString() ?? '',
        sup?.name ?? '',
        m.note,
      ].map(_csvField).join(',');
      sb.writeln(row);
    }
    return sb.toString();
  }

  /// بناء ملف CSV لتقرير الصلاحية (كل الدفعات وحالتها).
  String buildExpiryCsv() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final sb = StringBuffer();
    sb.write('\uFEFF');
    sb.writeln('المنتج,الكمية,تاريخ الصلاحية,الحالة');
    for (final b in allBatches) {
      final p = productById(b.productId);
      final e = b.expiryDate;
      String status;
      if (e == null) {
        status = 'بدون تاريخ صلاحية';
      } else if (e < now) {
        status = 'منتهي';
      } else if (e <= now + const Duration(days: 30).inMilliseconds) {
        status = 'ينتهي خلال 30 يوم';
      } else {
        status = 'سليم';
      }
      final row = [
        p?.name ?? '',
        '${_fmt(b.quantity)} ${p?.unit ?? ''}',
        formatDate(e),
        status,
      ].map(_csvField).join(',');
      sb.writeln(row);
    }
    return sb.toString();
  }

  String _csvField(String v) => '"${v.replaceAll('"', '""')}"';

  // ===================== مشتقات =====================

  List<Product> get outOfStockProducts =>
      products.where((p) => p.isOutOfStock).toList();

  List<Product> get lowStockProducts => products
      .where((p) => p.isLowStock)
      .toList()
    ..sort((a, b) => a.quantity.compareTo(b.quantity));

  List<Product> get alertProducts {
    final list = [...lowStockProducts, ...outOfStockProducts];
    final seen = <int>{};
    return list.where((p) {
      final ok = seen.add(p.id!);
      return ok;
    }).toList();
  }

  List<StockBatch> get allBatches {
    final list = <StockBatch>[];
    for (final p in products) {
      list.addAll(batchesOf(p.id!));
    }
    return list;
  }

  List<StockBatch> get expiredBatches {
    final now = DateTime.now().millisecondsSinceEpoch;
    return allBatches.where((b) {
      final e = b.expiryDate;
      return e != null && e < now;
    }).toList();
  }

  List<StockBatch> get expiringSoonBatches {
    final now = DateTime.now().millisecondsSinceEpoch;
    final limit = now + const Duration(days: 30).inMilliseconds;
    return allBatches.where((b) {
      final e = b.expiryDate;
      return e != null && e >= now && e <= limit;
    }).toList();
  }

  /// دفعات ليست منتهية ولا تنتهي خلال 30 يوماً (أو بدون تاريخ صلاحية).
  List<StockBatch> get safeBatches {
    final now = DateTime.now().millisecondsSinceEpoch;
    final limit = now + const Duration(days: 30).inMilliseconds;
    return allBatches.where((b) {
      final e = b.expiryDate;
      return e == null || e > limit;
    }).toList();
  }

  double get stockValue {
    var total = 0.0;
    for (final p in products) {
      total += p.quantity * p.costPrice;
    }
    return total;
  }

  Product? productById(int id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  Category? categoryById(int? id) {
    if (id == null) return null;
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  Supplier? supplierById(int? id) {
    if (id == null) return null;
    for (final s in suppliers) {
      if (s.id == id) return s;
    }
    return null;
  }

  String _fmt(double v) {
    return v == v.roundToDouble()
        ? v.toInt().toString()
        : v.toStringAsFixed(2);
  }
}

/// نتيجة تسجيل حركة مخزون (لتنبيه الواجهة عند انخفاض المخزون).
class MovementResult {
  final double newQuantity;
  final bool lowStock;
  final bool outOfStock;

  const MovementResult({
    required this.newQuantity,
    required this.lowStock,
    required this.outOfStock,
  });
}

/// نتيجة استيراد منتجات من ملف CSV.
class ImportResult {
  final int added;
  final int skipped;
  final List<String> errors;

  const ImportResult({
    required this.added,
    required this.skipped,
    this.errors = const [],
  });
}
