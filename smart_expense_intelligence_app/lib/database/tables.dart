class DatabaseTables {
  // --- Table Names ---
  static const String categoriesTable = 'categories';
  static const String expensesTable = 'expenses';
  static const String pendingExpensesTable = 'pending_expenses';
  static const String monthlyBudgetsTable = 'monthly_budgets';

  // --- DDL: Create Tables ---

  static const String createCategoriesTable = '''
    CREATE TABLE $categoriesTable (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE COLLATE NOCASE,
      is_essential INTEGER NOT NULL DEFAULT 0 CHECK(is_essential IN (0,1)),
      icon_code INTEGER,
      is_deleted INTEGER NOT NULL DEFAULT 0 CHECK(is_deleted IN (0,1)),
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT
    )
  ''';

  static const String createExpensesTable = '''
    CREATE TABLE $expensesTable (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      amount REAL NOT NULL CHECK(amount > 0),
      category_id INTEGER NOT NULL,
      merchant_name TEXT,
      date_time TEXT NOT NULL,
      note TEXT,
      source TEXT NOT NULL CHECK(source IN ('manual', 'ocr', 'sms')),
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT,
      FOREIGN KEY (category_id) 
        REFERENCES $categoriesTable(id)
        ON DELETE RESTRICT
    )
  ''';

  static const String createPendingExpensesTable = '''
    CREATE TABLE $pendingExpensesTable (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      amount REAL CHECK(amount > 0),
      merchant_name TEXT,
      date_time TEXT,
      source TEXT CHECK(source IN ('ocr', 'sms')),
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
  ''';

  static const String createMonthlyBudgetsTable = '''
    CREATE TABLE $monthlyBudgetsTable (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      month_year TEXT NOT NULL UNIQUE,
      limit_amount REAL NOT NULL CHECK(limit_amount > 0),
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      updated_at TEXT
    )
  ''';

  // --- Indexes ---
  static const String createIndexDate =
      'CREATE INDEX idx_expenses_date ON $expensesTable(date_time)';

  static const String createIndexCategory =
      'CREATE INDEX idx_expenses_category ON $expensesTable(category_id)';

  static const String createIndexSource =
      'CREATE INDEX idx_expenses_source ON $expensesTable(source)';
}