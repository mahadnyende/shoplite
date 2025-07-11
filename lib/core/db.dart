import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

class AppDatabase {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    sqfliteFfiInit();
    var dbPath = await databaseFactoryFfi.getDatabasesPath();
    final path = p.join(dbPath, 'shoplite.db');
    print('DB path: $path');
    _db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 8,
        onCreate: (db, version) async {
          print('DB onCreate called');
          await db.execute('''
            CREATE TABLE branches (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT UNIQUE
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS accounting (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT,
              description TEXT,
              amount INTEGER,
              type TEXT,
              reference_id INTEGER,
              branch_id INTEGER
            )
          ''');
          await db.execute('''
            CREATE TABLE settings (
              key TEXT PRIMARY KEY,
              value TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE inventory (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT,
              qty INTEGER,
              purchase INTEGER,
              sale INTEGER,
              expiry_date TEXT,
              branch_id INTEGER,
              FOREIGN KEY(branch_id) REFERENCES branches(id)
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS written_off (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT,
              qty INTEGER,
              purchase INTEGER,
              sale INTEGER,
              branch_id INTEGER,
              expiry_date TEXT,
              reason TEXT,
              written_off_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE purchases (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              supplier TEXT,
              date TEXT,
              payment_status TEXT,
              delivery_status TEXT,
              branch_id INTEGER,
              stock_name TEXT,
              qty INTEGER,
              purchase_price INTEGER,
              total INTEGER,
              notes TEXT,
              amount_paid INTEGER DEFAULT 0,
              FOREIGN KEY(branch_id) REFERENCES branches(id)
            )
          ''');
          await db.execute('''
            CREATE TABLE payments (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              invoice_id INTEGER,
              amount INTEGER,
              date TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS purchase_items (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              purchase_id INTEGER,
              stock_name TEXT,
              qty INTEGER,
              purchase_price INTEGER,
              total INTEGER,
              expiry_date TEXT,
              received_qty INTEGER DEFAULT 0,
              FOREIGN KEY(purchase_id) REFERENCES purchases(id)
            )
          ''');
          print('purchase_items table created or already exists (onCreate)');
          await db.execute('''
            CREATE TABLE sales (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT,
              amount INTEGER,
              payment_status TEXT,
              branch_id INTEGER,
              customer_name TEXT,
              customer_contact TEXT,
              notes TEXT,
              paid INTEGER DEFAULT 0,
              return_status TEXT,
              FOREIGN KEY(branch_id) REFERENCES branches(id)
            )
          ''');
          await db.execute('''
            CREATE TABLE sale_items (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              sale_id INTEGER,
              stock_name TEXT,
              qty INTEGER,
              price INTEGER,
              total INTEGER,
              FOREIGN KEY(sale_id) REFERENCES sales(id)
            )
          ''');
          await db.execute('''
            CREATE TABLE expenses (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              description TEXT,
              date TEXT,
              amount INTEGER,
              branch_id INTEGER,
              FOREIGN KEY(branch_id) REFERENCES branches(id)
            )
          ''');
          final tables = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table'",
          );
          print('Tables in DB (onCreate): $tables');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          print('DB onUpgrade called');
          // Always ensure purchase_items table exists on upgrade
          await db.execute('''CREATE TABLE IF NOT EXISTS accounting (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT,
            description TEXT,
            amount INTEGER,
            type TEXT,
            reference_id INTEGER,
            branch_id INTEGER
          )''');
          await db.execute('''CREATE TABLE IF NOT EXISTS purchase_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            purchase_id INTEGER,
            stock_name TEXT,
            qty INTEGER,
            purchase_price INTEGER,
            total INTEGER,
            received_qty INTEGER DEFAULT 0,
            FOREIGN KEY(purchase_id) REFERENCES purchases(id)
          )''');
          await db.execute('''CREATE TABLE IF NOT EXISTS written_off (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            qty INTEGER,
            purchase INTEGER,
            sale INTEGER,
            branch_id INTEGER,
            expiry_date TEXT,
            reason TEXT,
            written_off_at TEXT
          )''');
          try {
            await db.execute(
              "ALTER TABLE purchase_items ADD COLUMN received_qty INTEGER DEFAULT 0",
            );
          } catch (e) {}
          try {
            await db.execute(
              "ALTER TABLE inventory ADD COLUMN expiry_date TEXT",
            );
          } catch (e) {}
          try {
            await db.execute(
              "ALTER TABLE purchase_items ADD COLUMN expiry_date TEXT",
            );
          } catch (e) {}
          await db.execute('''CREATE TABLE IF NOT EXISTS payments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            invoice_id INTEGER,
            amount INTEGER,
            date TEXT
          )''');
          print('purchase_items table created or already exists (onUpgrade)');
          final tables = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table'",
          );
          print('Tables in DB (onUpgrade): $tables');
          if (oldVersion < 2) {
            await db.execute(
              '''CREATE TABLE IF NOT EXISTS branches (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE)''',
            );
            await db.execute(
              '''CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)''',
            );
            await db.execute(
              '''ALTER TABLE inventory ADD COLUMN branch_id INTEGER''',
            );
          }
          await db.execute('''CREATE TABLE IF NOT EXISTS purchases (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            supplier TEXT,
            date TEXT,
            payment_status TEXT,
            delivery_status TEXT,
            branch_id INTEGER,
            stock_name TEXT,
            qty INTEGER,
            purchase_price INTEGER,
            total INTEGER,
            notes TEXT,
            amount_paid INTEGER DEFAULT 0,
            FOREIGN KEY(branch_id) REFERENCES branches(id)
          )''');
          // Add missing columns for upgrades
          try {
            await db.execute("ALTER TABLE purchases ADD COLUMN notes TEXT");
          } catch (e) {}
          try {
            await db.execute(
              "ALTER TABLE purchases ADD COLUMN amount_paid INTEGER DEFAULT 0",
            );
          } catch (e) {}
          await db.execute('''CREATE TABLE IF NOT EXISTS purchase_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            purchase_id INTEGER,
            stock_name TEXT,
            qty INTEGER,
            purchase_price INTEGER,
            total INTEGER,
            received_qty INTEGER DEFAULT 0,
            FOREIGN KEY(purchase_id) REFERENCES purchases(id)
          )''');
          try {
            await db.execute(
              "ALTER TABLE purchase_items ADD COLUMN received_qty INTEGER DEFAULT 0",
            );
          } catch (e) {}
          // Add missing columns for upgrades
          try {
            await db.execute(
              "ALTER TABLE purchases ADD COLUMN stock_name TEXT",
            );
          } catch (e) {}
          try {
            await db.execute("ALTER TABLE purchases ADD COLUMN qty INTEGER");
          } catch (e) {}
          try {
            await db.execute(
              "ALTER TABLE purchases ADD COLUMN purchase_price INTEGER",
            );
          } catch (e) {}
          try {
            await db.execute("ALTER TABLE purchases ADD COLUMN total INTEGER");
          } catch (e) {}
          await db.execute('''CREATE TABLE IF NOT EXISTS sales (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT,
            amount INTEGER,
            payment_status TEXT,
            branch_id INTEGER,
            customer_name TEXT,
            customer_contact TEXT,
            notes TEXT,
            paid INTEGER DEFAULT 0,
            return_status TEXT,
            FOREIGN KEY(branch_id) REFERENCES branches(id)
          )''');
          // Add missing columns for upgrades
          try {
            await db.execute("ALTER TABLE sales ADD COLUMN customer_name TEXT");
          } catch (e) {}
          try {
            await db.execute(
              "ALTER TABLE sales ADD COLUMN customer_contact TEXT",
            );
          } catch (e) {}
          try {
            await db.execute("ALTER TABLE sales ADD COLUMN notes TEXT");
          } catch (e) {}
          try {
            await db.execute(
              "ALTER TABLE sales ADD COLUMN paid INTEGER DEFAULT 0",
            );
          } catch (e) {}
          try {
            await db.execute("ALTER TABLE sales ADD COLUMN return_status TEXT");
          } catch (e) {}
          // Add credit sales columns
          try {
            await db.execute("ALTER TABLE sales ADD COLUMN is_credit INTEGER DEFAULT 0");
          } catch (e) {}
          try {
            await db.execute("ALTER TABLE sales ADD COLUMN due_date TEXT");
          } catch (e) {}
          await db.execute('''CREATE TABLE IF NOT EXISTS sale_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sale_id INTEGER,
            stock_name TEXT,
            qty INTEGER,
            price INTEGER,
            total INTEGER,
            FOREIGN KEY(sale_id) REFERENCES sales(id)
          )''');
          await db.execute('''CREATE TABLE IF NOT EXISTS expenses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            description TEXT,
            date TEXT,
            amount INTEGER,
            branch_id INTEGER,
            FOREIGN KEY(branch_id) REFERENCES branches(id)
          )''');
          // Migration: add description column if missing
          try {
            await db.execute(
              "ALTER TABLE expenses ADD COLUMN description TEXT",
            );
          } catch (e) {}
        },
      ),
    );
    return _db!;
  }

  // Branches
  static Future<List<Map<String, dynamic>>> getBranches() async {
    final db = await database;
    return await db.query('branches');
  }

  static Future<int> addBranch(String name) async {
    final db = await database;
    return await db.insert('branches', {
      'name': name,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<int> deleteBranch(int id) async {
    final db = await database;
    return await db.delete('branches', where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> updateBranchName(int id, String name) async {
    final db = await database;
    return await db.update(
      'branches',
      {'name': name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Settings (active branch)
  static Future<void> setActiveBranch(int branchId) async {
    final db = await database;
    await db.insert('settings', {
      'key': 'active_branch',
      'value': branchId.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<int?> getActiveBranch() async {
    final db = await database;
    final result = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['active_branch'],
    );
    if (result.isNotEmpty) {
      return int.tryParse(result.first['value'] as String);
    }
    return null;
  }

  // Inventory
  static Future<List<Map<String, dynamic>>> getInventory({
    int? branchId,
  }) async {
    final db = await database;
    if (branchId != null) {
      return await db.query(
        'inventory',
        where: 'branch_id = ?',
        whereArgs: [branchId],
        orderBy: 'name ASC',
      );
    } else {
      return await db.query('inventory', orderBy: 'name ASC');
    }
  }

  static Future<int> addInventory(Map<String, dynamic> item) async {
    final db = await database;
    return await db.insert(
      'inventory',
      item,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<int> updateInventory(int id, Map<String, dynamic> item) async {
    final db = await database;
    return await db.update('inventory', item, where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> deleteInventory(int id) async {
    final db = await database;
    return await db.delete('inventory', where: 'id = ?', whereArgs: [id]);
  }

  // Purchases
  static Future<List<Map<String, dynamic>>> getPurchases({
    int? branchId,
  }) async {
    final db = await database;
    if (branchId != null) {
      return await db.query(
        'purchases',
        where: 'branch_id = ?',
        whereArgs: [branchId],
      );
    } else {
      return await db.query('purchases');
    }
  }

  static Future<int> addPurchase(Map<String, dynamic> purchase) async {
    final db = await database;
    return await db.insert(
      'purchases',
      purchase,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<int> updatePurchase(
    int id,
    Map<String, dynamic> purchase,
  ) async {
    final db = await database;
    return await db.update(
      'purchases',
      purchase,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<int> deletePurchase(int id) async {
    final db = await database;
    return await db.delete('purchases', where: 'id = ?', whereArgs: [id]);
  }

  // Sale Items
  static Future<List<Map<String, dynamic>>> getSaleItems(int saleId) async {
    final db = await database;
    return await db.query(
      'sale_items',
      where: 'sale_id = ?',
      whereArgs: [saleId],
    );
  }

  static Future<int> addSaleItem(Map<String, dynamic> item) async {
    final db = await database;
    return await db.insert(
      'sale_items',
      item,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<int> deleteSaleItem(int id) async {
    final db = await database;
    return await db.delete('sale_items', where: 'id = ?', whereArgs: [id]);
  }

  // Sales
  static Future<List<Map<String, dynamic>>> getSales({int? branchId}) async {
    final db = await database;
    if (branchId != null) {
      return await db.query(
        'sales',
        where: 'branch_id = ?',
        whereArgs: [branchId],
      );
    } else {
      return await db.query('sales');
    }
  }

  static Future<int> addSale(Map<String, dynamic> sale) async {
    final db = await database;
    return await db.insert(
      'sales',
      sale,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<int> deleteSale(int id) async {
    final db = await database;
    return await db.delete('sales', where: 'id = ?', whereArgs: [id]);
  }

  // Expenses
  static Future<List<Map<String, dynamic>>> getExpenses({int? branchId}) async {
    final db = await database;
    if (branchId != null) {
      return await db.query(
        'expenses',
        where: 'branch_id = ?',
        whereArgs: [branchId],
      );
    } else {
      return await db.query('expenses');
    }
  }

  static Future<int> addExpense(Map<String, dynamic> expense) async {
    final db = await database;
    return await db.insert(
      'expenses',
      expense,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<int> deleteExpense(int id) async {
    final db = await database;
    return await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }
}
