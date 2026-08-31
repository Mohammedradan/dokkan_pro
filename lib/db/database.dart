import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/category.dart';
import '../models/product.dart';
import '../models/stock_batch.dart';
import '../models/stock_movement.dart';
import '../models/supplier.dart';

class AppDatabase {
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), 'dokkan_pro.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE suppliers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL DEFAULT '',
        address TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE products(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        barcode TEXT NOT NULL DEFAULT '',
        category_id INTEGER,
        supplier_id INTEGER,
        unit TEXT NOT NULL DEFAULT 'قطعة',
        cost_price REAL NOT NULL DEFAULT 0,
        sell_price REAL NOT NULL DEFAULT 0,
        min_stock REAL NOT NULL DEFAULT 0,
        quantity REAL NOT NULL DEFAULT 0,
        notes TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE batches(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        expiry_date INTEGER,
        received_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE stock_movements(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_cost REAL,
        supplier_id INTEGER,
        batch_id INTEGER,
        note TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE settings(
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_products_category ON products(category_id)');
    await db.execute('CREATE INDEX idx_batches_product ON batches(product_id)');
    await db.execute('CREATE INDEX idx_batches_expiry ON batches(expiry_date)');
    await db.execute('CREATE INDEX idx_movements_product ON stock_movements(product_id)');
  }

  // ===================== الإعدادات =====================

  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ===================== الفئات =====================

  Future<List<Category>> getCategories() async {
    final db = await database;
    final rows = await db.query('categories', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(Category.fromMap).toList();
  }

  Future<int> insertCategory(String name) async {
    final db = await database;
    return db.insert('categories', {
      'name': name,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> updateCategory(Category category) async {
    final db = await database;
    await db.update('categories', category.toMap(),
        where: 'id = ?', whereArgs: [category.id]);
  }

  Future<int> countProductsInCategory(int categoryId) async {
    final db = await database;
    final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM products WHERE category_id = ?', [categoryId]);
    return rows.first['c'] as int;
  }

  Future<void> deleteCategory(int categoryId) async {
    final db = await database;
    await db.delete('categories', where: 'id = ?', whereArgs: [categoryId]);
  }

  // ===================== الموردون =====================

  Future<List<Supplier>> getSuppliers() async {
    final db = await database;
    final rows = await db.query('suppliers', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(Supplier.fromMap).toList();
  }

  Future<int> insertSupplier(Supplier supplier) async {
    final db = await database;
    return db.insert('suppliers', supplier.toMap());
  }

  Future<void> updateSupplier(Supplier supplier) async {
    final db = await database;
    await db.update('suppliers', supplier.toMap(),
        where: 'id = ?', whereArgs: [supplier.id]);
  }

  Future<void> deleteSupplier(int supplierId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('products', {'supplier_id': null},
          where: 'supplier_id = ?', whereArgs: [supplierId]);
      await txn.delete('suppliers', where: 'id = ?', whereArgs: [supplierId]);
    });
  }

  // ===================== المنتجات =====================

  Future<List<Product>> getProducts() async {
    final db = await database;
    final rows = await db.query('products', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(Product.fromMap).toList();
  }

  Future<int> insertProduct(Product product) async {
    final db = await database;
    return db.insert('products', product.toMap());
  }

  Future<void> updateProduct(Product product) async {
    final db = await database;
    await db.update('products', product.toMap(),
        where: 'id = ?', whereArgs: [product.id]);
  }

  Future<void> deleteProduct(int productId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('batches', where: 'product_id = ?', whereArgs: [productId]);
      await txn.delete('stock_movements',
          where: 'product_id = ?', whereArgs: [productId]);
      await txn.delete('products', where: 'id = ?', whereArgs: [productId]);
    });
  }

  Future<void> updateProductQuantity(int productId, double quantity) async {
    final db = await database;
    await db.update(
      'products',
      {
        'quantity': quantity,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  // ===================== الدفعات =====================

  Future<List<StockBatch>> getBatchesForProduct(int productId) async {
    final db = await database;
    final rows = await db.query('batches',
        where: 'product_id = ? AND quantity > 0',
        whereArgs: [productId],
        orderBy: 'expiry_date IS NULL, expiry_date ASC, received_at ASC');
    return rows.map(StockBatch.fromMap).toList();
  }

  Future<List<StockBatch>> getAllBatches() async {
    final db = await database;
    final rows = await db.query('batches',
        where: 'quantity > 0', orderBy: 'expiry_date ASC');
    return rows.map(StockBatch.fromMap).toList();
  }

  Future<int> insertBatch(StockBatch batch) async {
    final db = await database;
    return db.insert('batches', batch.toMap());
  }

  Future<void> updateBatch(StockBatch batch) async {
    final db = await database;
    await db.update('batches', batch.toMap(),
        where: 'id = ?', whereArgs: [batch.id]);
  }

  Future<void> deleteBatch(int batchId) async {
    final db = await database;
    await db.delete('batches', where: 'id = ?', whereArgs: [batchId]);
  }

  /// خصم كمية من الدفعات الأقدم أولاً (FIFO). تُحذف الدفعات التي تصل للصفر.
  Future<void> deductFromBatches(int productId, double quantity) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('batches',
          where: 'product_id = ? AND quantity > 0',
          whereArgs: [productId],
          orderBy: 'expiry_date IS NULL, expiry_date ASC, received_at ASC');
      var remaining = quantity;
      for (final row in rows) {
        if (remaining <= 0) break;
        final batch = StockBatch.fromMap(row);
        if (batch.id == null) continue;
        final take = remaining >= batch.quantity ? batch.quantity : remaining;
        final newQty = batch.quantity - take;
        remaining -= take;
        if (newQty <= 0.0001) {
          await txn.delete('batches', where: 'id = ?', whereArgs: [batch.id]);
        } else {
          await txn.update('batches', {'quantity': newQty},
              where: 'id = ?', whereArgs: [batch.id]);
        }
      }
    });
  }

  // ===================== الحركات =====================

  Future<List<StockMovement>> getMovements() async {
    final db = await database;
    final rows =
        await db.query('stock_movements', orderBy: 'created_at DESC, id DESC');
    return rows.map(StockMovement.fromMap).toList();
  }

  Future<List<StockMovement>> getMovementsForProduct(int productId) async {
    final db = await database;
    final rows = await db.query('stock_movements',
        where: 'product_id = ?',
        whereArgs: [productId],
        orderBy: 'created_at DESC, id DESC');
    return rows.map(StockMovement.fromMap).toList();
  }

  Future<int> insertMovement(StockMovement movement) async {
    final db = await database;
    return db.insert('stock_movements', movement.toMap());
  }

  // ===================== النسخ الاحتياطي =====================

  Future<String> get _dbFilePath async =>
      join(await getDatabasesPath(), 'dokkan_pro.db');

  /// إنشاء نسخة احتياطية من قاعدة البيانات، يعيد اسم الملف.
  Future<String> createBackup() async {
    final dir = await getDatabasesPath();
    final source = await _dbFilePath;
    final name = 'backup_${DateTime.now().millisecondsSinceEpoch}.db';
    await File(source).copy(join(dir, name));
    return name;
  }

  /// قائمة النسخ الاحتياطية مرتبة من الأحدث.
  Future<List<Map<String, Object?>>> listBackups() async {
    final dir = await getDatabasesPath();
    final result = <Map<String, Object?>>[];
    final pattern = RegExp(r'^backup_\d+\.db$');
    for (final entity in Directory(dir).listSync()) {
      if (entity is! File) continue;
      final name = entity.path.split(Platform.pathSeparator).last;
      if (!pattern.hasMatch(name)) continue;
      result.add({
        'name': name,
        'path': entity.path,
        'size': entity.lengthSync(),
        'modified': entity.lastModifiedSync().millisecondsSinceEpoch,
      });
    }
    result.sort(
        (a, b) => (b['modified'] as int).compareTo(a['modified'] as int));
    return result;
  }

  /// استعادة نسخة احتياطية: يغلق قاعدة البيانات الحالية،
  /// ينسخ ملف النسخة مكانها، ثم يُعاد فتحها عند الطلب التالي.
  Future<void> restoreBackup(String backupPath) async {
    final db = await database;
    await db.close();
    _db = null;
    final target = await _dbFilePath;
    await File(backupPath).copy(target);
  }

  Future<void> deleteBackup(String backupPath) async {
    final f = File(backupPath);
    if (await f.exists()) await f.delete();
  }

  // ===================== بيانات تجريبية =====================

  Future<void> loadDemoData() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      Future<int> cat(String name) async {
        return txn.insert('categories', {'name': name, 'created_at': now});
      }

      Future<int> sup(String name, String phone, String addr) async {
        return txn.insert('suppliers', {
          'name': name,
          'phone': phone,
          'address': addr,
          'notes': '',
          'created_at': now,
        });
      }

      Future<int> prod(
        String name,
        int catId,
        int supId,
        String unit,
        double cost,
        double sell,
        double minStock,
        double qty,
      ) async {
        return txn.insert('products', {
          'name': name,
          'barcode': '',
          'category_id': catId,
          'supplier_id': supId,
          'unit': unit,
          'cost_price': cost,
          'sell_price': sell,
          'min_stock': minStock,
          'quantity': qty,
          'notes': '',
          'created_at': now,
          'updated_at': now,
        });
      }

      Future<void> batch(int productId, double qty, int? expiry) async {
        return txn.insert('batches', {
          'product_id': productId,
          'quantity': qty,
          'expiry_date': expiry,
          'received_at': now,
        });
      }

      Future<void> mov(int productId, String type, double qty,
          {double? cost, String note = ''}) async {
        return txn.insert('stock_movements', {
          'product_id': productId,
          'type': type,
          'quantity': qty,
          'unit_cost': cost,
          'supplier_id': null,
          'batch_id': null,
          'note': note,
          'created_at': now,
        });
      }

      final veg = await cat('خضار وفواكه');
      final dairy = await cat('ألبان وأجبان');
      final drinks = await cat('مشروبات');
      final dry = await cat('مواد غذائية');
      final clean = await cat('منظفات');

      final s1 = await sup('شركة النيل للمواد الغذائية', '01012345678', 'المنطقة الصناعية');
      final s2 = await sup('مزرعة الخير', '01122334455', 'الطريق الزراعي');
      final s3 = await sup('مصنع الأهرام للألبان', '01233445566', 'مدينة الألبان');

      final nowMs = DateTime.now();
      final day = const Duration(days: 1);
      final expIn = (int d) => nowMs.add(day * d).millisecondsSinceEpoch;
      final expired = nowMs.subtract(day * 5).millisecondsSinceEpoch;

      final tomato = await prod('طماطم', veg, s2, 'كيلو', 8, 12, 10, 25);
      await batch(tomato, 25, null);
      final apple = await prod('تفاح أحمر', veg, s2, 'كيلو', 15, 22, 8, 0);
      final potato = await prod('بطاطس', veg, s2, 'كيلو', 6, 10, 15, 40);
      await batch(potato, 40, null);

      final milk = await prod('لبن كامل الدسم (1 لتر)', dairy, s3, 'عبوة', 18, 25, 12, 30);
      await batch(milk, 20, expIn(7));
      await batch(milk, 10, expIn(25));
      final cheese = await prod('جبنة بيضاء (كيلو)', dairy, s3, 'كيلو', 55, 75, 5, 8);
      await batch(cheese, 8, expIn(12));
      final yoghurt = await prod('زبادي (علبة)', dairy, s3, 'علبة', 5, 8, 20, 10);
      await batch(yoghurt, 10, expired); // منتهي

      final juice = await prod('عصير برتقال (1 لتر)', drinks, s1, 'عبوة', 14, 20, 10, 6);
      await batch(juice, 6, expIn(40));
      final water = await prod('مياه معدنية (1.5 لتر)', drinks, s1, 'عبوة', 4, 7, 24, 60);
      await batch(water, 60, null);

      final rice = await prod('أرز مصري (كيس 1 كيلو)', dry, s1, 'كيس', 22, 30, 20, 15);
      await batch(rice, 15, expIn(200));
      final oil = await prod('زيت عباد الشمس (1 لتر)', dry, s1, 'عبوة', 32, 42, 12, 4);
      await batch(oil, 4, expIn(150));
      final sugar = await prod('سكر (كيس 1 كيلو)', dry, s1, 'كيس', 20, 28, 20, 35);
      await batch(sugar, 35, expIn(180));

      final soap = await prod('صابون غسيل', clean, s1, 'قطعة', 3, 5, 20, 45);
      await batch(soap, 45, null);
      final bleach = await prod('كلور (1 لتر)', clean, s1, 'عبوة', 8, 12, 10, 3);
      await batch(bleach, 3, expIn(90));

      await mov(tomato, 'receive', 25, cost: 8, note: 'استلام أول');
      await mov(apple, 'receive', 15, cost: 15);
      await mov(apple, 'adjust_out', 15, note: 'تلف أثناء النقل');
      await mov(potato, 'receive', 40, cost: 6);
      await mov(milk, 'receive', 30, cost: 18);
      await mov(cheese, 'receive', 8, cost: 55);
      await mov(yoghurt, 'receive', 10, cost: 5);
      await mov(juice, 'receive', 6, cost: 14);
      await mov(water, 'receive', 60, cost: 4);
      await mov(rice, 'receive', 15, cost: 22);
      await mov(oil, 'receive', 4, cost: 32);
      await mov(sugar, 'receive', 35, cost: 20);
      await mov(soap, 'receive', 45, cost: 3);
      await mov(bleach, 'receive', 3, cost: 8);
    });
  }
}
