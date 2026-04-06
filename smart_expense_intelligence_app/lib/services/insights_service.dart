import '../models/insight.dart';
import '../database/database_helper.dart';

class InsightsService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<Insight>> generateInsights(DateTime month) async {
    List<Insight> insights = [];
    String monthYear = "${month.year}-${month.month.toString().padLeft(2, '0')}";

    final db = await _dbHelper.database;
    
    final budgetData = await _dbHelper.getBudgetByMonth(monthYear);
    double budgetLimit = (budgetData?['limit_amount'] as num?)?.toDouble() ?? 0.0;

    final List<Map<String, dynamic>> allExpenses = await db.rawQuery('''
      SELECT e.amount, e.merchant_name, e.date_time, c.name AS category_name, c.is_essential
      FROM expenses e
      LEFT JOIN categories c ON e.category_id = c.id
      WHERE strftime('%Y-%m', e.date_time) = ?
    ''', [monthYear]);

    if (allExpenses.isEmpty) {
      return [Insight(
        title: "Perfectly Balanced",
        message: "Your finances are perfectly balanced this month. Keep it up!",
        type: 'positive'
      )];
    }

    double totalSpent = allExpenses.fold(0, (sum, e) => sum + (e['amount'] as num).toDouble());
    double comparisonBase = budgetLimit > 0 ? budgetLimit : totalSpent;

    // --- RULE 1: Frequent Merchant ---
    var merchantCounts = <String, int>{};
    for (var e in allExpenses) {
      String name = (e['merchant_name'] ?? 'Unknown').toString().trim();
      if (name.isNotEmpty) {
        merchantCounts[name] = (merchantCounts[name] ?? 0) + 1;
      }
    }
    if (merchantCounts.isNotEmpty) {
      var topEntry = merchantCounts.entries.reduce((a, b) => a.value > b.value ? a : b);
      if (topEntry.value > 1) { 
        insights.add(Insight(
          title: "Frequent Merchant",
          message: "You shop frequently at ${topEntry.key}. Consider loyalty programs there.",
          type: 'neutral'
        ));
      }
    }

    // ✅ ADDED RULE 2: High Food Spending 
    double foodSpent = allExpenses
        .where((e) => e['category_name'] == 'Food & Dining')
        .fold(0, (sum, e) => sum + (e['amount'] as num).toDouble());
    double foodPercent = (foodSpent / comparisonBase) * 100;

    if (foodPercent > 35) {
      insights.add(Insight(
        title: "High Food Spending",
        message: "Your food spending is over 35%. Try cooking at home more often to save money.",
        type: 'warning'
      ));
    }

    // --- RULE 3: Late Night Transactions ---
    int lateNightCount = 0;
    for (var e in allExpenses) {
      DateTime dt = DateTime.parse(e['date_time']);
      if (dt.hour >= 22 || dt.hour <= 4) lateNightCount++; 
    }
    
    if (lateNightCount > 3) {
      insights.add(Insight(
        title: _getRule3Title(lateNightCount),
        message: _getRule3Message(lateNightCount),
        type: 'warning'
      ));
    }

    // --- RULE 4: High Transport (> 30%) ---
    double transportSpent = allExpenses
        .where((e) => e['category_name'] == 'Transport')
        .fold(0, (sum, e) => sum + (e['amount'] as num).toDouble());
    double transPercent = (transportSpent / comparisonBase) * 100;

    if (transPercent >= 30) {
      insights.add(Insight(
        title: transPercent >= 75 ? "CRITICAL: Transport" : "High Transport",
        message: _getTieredMessage('Transport', transPercent),
        type: 'warning'
      ));
    }

    // --- RULE 5: High "Wants" Spending (> 40%) ---
    double wantsSpent = allExpenses
        .where((e) => e['is_essential'] == 0)
        .fold(0, (sum, e) => sum + (e['amount'] as num).toDouble());
    double wantsPercent = (wantsSpent / comparisonBase) * 100;

    if (wantsPercent >= 40) {
      insights.add(Insight(
        title: wantsPercent >= 80 ? "CRITICAL: Wants" : "High Wants Spending",
        message: _getTieredMessage('Wants', wantsPercent),
        type: 'warning'
      ));
    }

    // Default Fallback 
    if (insights.isEmpty) {
      insights.add(Insight(
        title: "Perfectly Balanced",
        message: "Your finances are perfectly balanced this month. Keep it up!",
        type: 'positive'
      ));
    }

    return insights;
  }

  String _getTieredMessage(String rule, double percent) {
    if (rule == 'Transport') {
      if (percent >= 100) return "Transport budget exhausted! You must use public transit or walk.";
      if (percent >= 75) return "Your transport costs are critical. Avoid private rides for a few days.";
      if (percent >= 50) return "Half your transport budget is gone. Try sharing rides to save money.";
      return "Transport is taking up >30% of your budget. Suggest reducing ride-hailing.";
    } else { 
      if (percent >= 100) return "100% of budget spent on non-essentials! Stop all shopping immediately.";
      if (percent >= 80) return "Non-essential spending is extremely high. You are risking your savings.";
      if (percent >= 60) return "Over 60% of spending is on 'wants'. Time to prioritize your 'needs'.";
      return "Over 40% of your spending is on non-essentials. Great savings opportunity here!";
    }
  }

  String _getRule3Title(int count) {
    if (count > 10) return "URGENT: Night Habits";
    if (count > 6) return "Warning: Late Spending";
    return "Late Night Purchases";
  }

  String _getRule3Message(int count) {
    if (count > 10) return "You have $count late-night purchases. This habit is significantly draining your budget.";
    if (count > 6) return "With $count purchases after 10PM, you are likely making impulse buys.";
    return "You have $count late-night purchases. Try limiting these to avoid impulse buys.";
  }
}