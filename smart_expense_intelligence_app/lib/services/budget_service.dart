import '../database/database_helper.dart';
import '../models/monthly_budget.dart';

class BudgetService {
  final dbHelper = DatabaseHelper.instance;

  // Get budget for selected month
  Future<MonthlyBudget?> getBudgetByMonth(String monthYear) async {
    final db = await dbHelper.database;

    final maps = await db.query(
      'monthly_budgets',
      where: 'month_year = ?',
      whereArgs: [monthYear],
    );

    if (maps.isNotEmpty) {
      return MonthlyBudget.fromMap(maps.first);
    }
    return null;
  }

  // Get total expenses for month
  Future<double> getTotalExpensesByMonth(String monthYear) async {
    final db = await dbHelper.database;

    final result = await db.rawQuery(
      "SELECT SUM(amount) as total FROM expenses WHERE strftime('%Y-%m', date_time) = ?",
      [monthYear],
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // Intelligence Engine
  Future<Map<String, double>> calculateIntelligence(String monthYear, double spent) async {
    final budgetMap = await DatabaseHelper.instance.getBudgetByMonth(monthYear);

    // If no budget is set, still return the amount spent!
    if (budgetMap == null) {
      return {
        'limit': 0.0,
        'spent': spent,
        'dailySafe': 0.0,
        'progress': 0.0,
      };
    }

    double limit = (budgetMap['limit_amount'] as num).toDouble();
    int daysInMonth = DateTime(_parseYear(monthYear), _parseMonth(monthYear) + 1, 0).day;
    int today = DateTime.now().day;
    int daysRemaining = daysInMonth - today + 1;

    double remaining = limit - spent;
    double dailySafe = remaining > 0 ? remaining / daysRemaining : 0.0;

    return {
      'limit': limit,
      'spent': spent,
      'dailySafe': dailySafe,
      'progress': limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0,
    };
  }

// helpers
  int _parseYear(String monthYear) => int.parse(monthYear.split('-')[0]);
  int _parseMonth(String monthYear) => int.parse(monthYear.split('-')[1]);
}
