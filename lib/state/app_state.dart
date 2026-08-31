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

  String storeName = 'بقالتي';
  String currency = 'ج.م';

  // ===================== التحميل =====================

  Future<void> init() async {
    storeName = (await db.getSetting('store_name')) ?? 'بقالتي';
    currency = (await db.getSetting('currency')) ?? 'ج.م';
    await reloadAll();
  }

  Future<void> reloadAll() async {
    categories = await db.getCategories();
    suppliers = await db.getSuppliers();
    products = await db.getProducts();
    movements = await db.getMovements();
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
  Future<void> addMovement({
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

    await reloadAll();
  }

  /// إتلاف دفعة كاملة (منتهية الصلاحية مثلاً).
  Future<void> wasteBatch(Product product, StockBatch batch) async {
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
    await reloadAll();
  }

  Future<void> loadDemoData() async {
    await db.loadDemoData();
    await reloadAll();
  }

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
