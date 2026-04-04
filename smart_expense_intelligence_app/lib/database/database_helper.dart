import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'tables.dart';

class DatabaseHelper {
  // Singleton instance
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  // Getter for the database
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('smart_expense.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onConfigure: _onConfigure,
    );
  }

  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _createDB(Database db, int version) async {
    await db.execute(DatabaseTables.createCategoriesTable);
    await db.execute(DatabaseTables.createExpensesTable);
    await db.execute(DatabaseTables.createPendingExpensesTable);
    await db.execute(DatabaseTables.createMonthlyBudgetsTable);

    await db.execute(DatabaseTables.createIndexDate);
    await db.execute(DatabaseTables.createIndexCategory);
    await db.execute(DatabaseTables.createIndexSource);

    await _insertDefaultCategories(db);
  }

  Future _insertDefaultCategories(Database db) async {
    // ✅ FIXED: Added Bills & Utilities (ID 5) and Other (ID 6)
    final List<Map<String, dynamic>> defaultCategories = [
      {'name': 'Food & Dining', 'is_essential': 1},      // ID 1
      {'name': 'Transport', 'is_essential': 1},          // ID 2
      {'name': 'Entertainment', 'is_essential': 0},      // ID 3
      {'name': 'Shopping', 'is_essential': 0},           // ID 4
      {'name': 'Bills & Utilities', 'is_essential': 1},  // ID 5
      {'name': 'Other', 'is_essential': 0},              // ID 6
    ];
    
    for (var category in defaultCategories) {
      await db.insert(
        DatabaseTables.categoriesTable,
        category,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  // ==========================================
  // CRUD OPERATIONS FOR EXPENSES
  // ==========================================

  // CREATE
  Future<int> insertExpense(Map<String, dynamic> expense) async {
    final db = await instance.database;
    return await db.insert(DatabaseTables.expensesTable, expense);
  }

  // READ (Get all expenses)
  Future<List<Map<String, dynamic>>> getExpenses() async {
    final db = await instance.database;
    // We join the categories table to get the category name along with the expense
    return await db.rawQuery('''
      SELECT e.*, c.name AS category_name 
      FROM ${DatabaseTables.expensesTable} e
      LEFT JOIN ${DatabaseTables.categoriesTable} c ON e.category_id = c.id
      ORDER BY e.date_time DESC
    ''');
  }

  // UPDATE
  Future<int> updateExpense(int id, Map<String, dynamic> expense) async {
    final db = await instance.database;
    return await db.update(
      DatabaseTables.expensesTable,
      expense,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // DELETE
  Future<int> deleteExpense(int id) async {
    final db = await instance.database;
    return await db.delete(
      DatabaseTables.expensesTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================
  // CRUD OPERATIONS FOR PENDING EXPENSES (SMS)
  // ==========================================

  // CREATE
  Future<int> insertPendingExpense(Map<String, dynamic> pendingExpense) async {
    final db = await instance.database;
    return await db.insert(DatabaseTables.pendingExpensesTable, pendingExpense);
  }

  // READ Pending Expenses
  Future<List<Map<String, dynamic>>> getPendingExpenses() async {
    final db = await instance.database;
    return await db.query(DatabaseTables.pendingExpensesTable,
        orderBy: 'date_time DESC');
  }

  // DELETE
  Future<int> deletePendingExpense(int id) async {
    final db = await instance.database;
    return await db.delete(
      DatabaseTables.pendingExpensesTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // NEW: Find the most recently used category for a specific merchant
  Future<int?> getCategoryForMerchant(String merchantName) async {
    final db = await instance.database;
    final result = await db.query(
      DatabaseTables.expensesTable,
      columns: ['category_id'],
      where: 'merchant_name LIKE ?',
      whereArgs: ['%$merchantName%'],
      orderBy: 'date_time DESC',
      limit: 1,
    );

    if (result.isNotEmpty) {
      return result.first['category_id'] as int?;
    }
    return null; // Not found
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }

  Future<double> getTotalExpensesByMonth(String monthYear) async {
    final db = await database;

    final result = await db.rawQuery(
      '''
    SELECT SUM(amount) as total 
    FROM expenses 
    WHERE strftime('%Y-%m', date_time) = ?
    ''',
      [monthYear],
    );

    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toDouble();
    }

    return 0.0;
  }

  Future<Map<String, dynamic>?> getBudgetByMonth(String monthYear) async {
    final db = await instance.database;

    final result = await db.query(
      DatabaseTables.monthlyBudgetsTable,
      where: 'month_year = ?',
      whereArgs: [monthYear],
      limit: 1,
    );

    if (result.isNotEmpty) {
      return result.first;
    }

    return null;
  }

  Future<int> insertBudget(String monthYear, double limitAmount) async {
    final db = await database;

    return await db.insert(
      DatabaseTables.monthlyBudgetsTable,
      {
        'month_year': monthYear,
        'limit_amount': limitAmount,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}