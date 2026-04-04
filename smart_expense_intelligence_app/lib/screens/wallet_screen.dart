import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/expense.dart';
import '../services/expense_service.dart';
import '../services/budget_service.dart';
import '../database/database_helper.dart';

class WalletScreen extends StatefulWidget {
  final int refreshTrigger; 
  const WalletScreen({super.key, this.refreshTrigger = 0}); 

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final ExpenseService _expenseService = ExpenseService();
  final BudgetService _budgetService = BudgetService();
  
  Map<String, double> _budgetData = {};
  double totalBudget = 0.0;
  double spent = 0.0;
  Map<String, double> categoryTotals = {};
  
  // New variables for the Highlight Card
  String _topCategory = "";
  double _topCategoryAmount = 0.0;

  final Color oceanDeep = const Color(0xFF006064);
  final Color oceanLight = const Color(0xFF00838F);
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _budgetController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  @override
  void didUpdateWidget(covariant WalletScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshTrigger != oldWidget.refreshTrigger) {
      _loadWalletData();
    }
  }

  Future<void> _loadWalletData() async {
    String monthYear = DateFormat('yyyy-MM').format(_selectedDate);
    final allExpenses = await _expenseService.getAllExpenses();

    final filtered = allExpenses.where((exp) => 
        exp.dateTime.year == _selectedDate.year && 
        exp.dateTime.month == _selectedDate.month).toList();

    double calculatedTotalSpent = 0.0;
    Map<String, double> totals = {};
    
    for (var exp in filtered) {
      calculatedTotalSpent += exp.amount;
      String cat = exp.categoryName ?? 'Other';
      totals[cat] = (totals[cat] ?? 0) + exp.amount;
    }

    // Logic to find the highest category
    String highestCat = "";
    double highestAmt = 0.0;
    if (totals.isNotEmpty) {
      var topEntry = totals.entries.reduce((a, b) => a.value > b.value ? a : b);
      highestCat = topEntry.key;
      highestAmt = topEntry.value;
    }

    final intelligence = await _budgetService.calculateIntelligence(monthYear, calculatedTotalSpent);

    if (mounted) {
      setState(() {
        _budgetData = intelligence;
        spent = intelligence['spent'] ?? 0.0;
        totalBudget = intelligence['limit'] ?? 0.0;
        categoryTotals = totals;
        _topCategory = highestCat;
        _topCategoryAmount = highestAmt;
      });
    }
  }

  Future<void> _saveBudget() async {
    double amount = double.tryParse(_budgetController.text) ?? 0;
    String monthYear = DateFormat('yyyy-MM').format(_selectedDate);
    await DatabaseHelper.instance.insertBudget(monthYear, amount);
    _budgetController.clear();
    _loadWalletData();
  }

  @override
  Widget build(BuildContext context) {
    double progress = totalBudget == 0 ? 0 : spent / totalBudget;
    bool isBudgetSet = _budgetData.containsKey('limit') && totalBudget > 0;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Analytics & Budget'), 
        backgroundColor: oceanDeep, 
        foregroundColor: Colors.white, 
        elevation: 0
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMonthSelector(),
            const SizedBox(height: 16),
            
            if (!isBudgetSet) 
              _buildEnterBudgetBox()
            else 
              _buildBudgetCard(progress),

            const SizedBox(height: 24),
            
            // 🔥 NEW: Top Spender Highlight Card
            if (_topCategory.isNotEmpty) ...[
              _buildTopSpenderCard(),
              const SizedBox(height: 24),
            ],

            const Text("Category Breakdown", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 12),
            
            _buildPieChartSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSpenderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: oceanDeep.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.trending_up, color: Colors.redAccent, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Highest Spend This Month", style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 4),
                Text(_topCategory, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
          ),
          Text("Rs ${_topCategoryAmount.toStringAsFixed(0)}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent)),
        ],
      ),
    );
  }

  Widget _buildPieChartSection() {
    if (categoryTotals.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: const Center(child: Text("No expenses to chart this month.", style: TextStyle(color: Colors.grey))),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 50,
                sections: categoryTotals.entries.map((entry) {
                  return PieChartSectionData(
                    color: _getColorForCategory(entry.key),
                    value: entry.value,
                    title: '${((entry.value / spent) * 100).toStringAsFixed(0)}%',
                    radius: 50,
                    titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ...categoryTotals.entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                CircleAvatar(backgroundColor: _getColorForCategory(e.key), radius: 6),
                const SizedBox(width: 12),
                Expanded(child: Text(e.key, style: const TextStyle(fontSize: 15, color: Colors.black87))),
                Text("Rs ${e.value.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Color _getColorForCategory(String category) {
    switch (category) {
      case 'Food & Dining': return Colors.redAccent;
      case 'Transport': return Colors.blueAccent;
      case 'Entertainment': return Colors.purpleAccent;
      case 'Shopping': return Colors.orangeAccent;
      case 'Bills & Utilities': return Colors.teal;
      default: return Colors.blueGrey;
    }
  }

  Widget _buildEnterBudgetBox() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Enter Monthly Budget", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _budgetController, 
            keyboardType: TextInputType.number, 
            decoration: InputDecoration(
              labelText: "Total Budget (Rs)",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: Icon(Icons.account_balance_wallet, color: oceanDeep),
            )
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _saveBudget, 
              style: ElevatedButton.styleFrom(
                backgroundColor: oceanDeep,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ), 
              child: const Text("Save Budget", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBudgetCard(double progress) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [oceanLight, oceanDeep], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: oceanDeep.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   const Text("Total Budget", style: TextStyle(color: Colors.white70, fontSize: 14)),
                   const SizedBox(height: 4),
                   Text("Rs ${totalBudget.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                 ],
               ),
               IconButton(
                 onPressed: () => _showEditDialog(), 
                 icon: const Icon(Icons.edit, color: Colors.white70),
                 tooltip: "Edit Budget",
               ),
             ],
           ),
           const SizedBox(height: 24),
           ClipRRect(
             borderRadius: BorderRadius.circular(10),
             child: LinearProgressIndicator(
               value: progress.clamp(0.0, 1.0), 
               minHeight: 8, 
               backgroundColor: Colors.white.withOpacity(0.2), 
               valueColor: AlwaysStoppedAnimation<Color>(progress > 0.9 ? Colors.redAccent : Colors.white)
             ),
           ),
           const SizedBox(height: 12),
           Text("Rs ${spent.toStringAsFixed(2)} spent", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _showEditDialog() {
    _budgetController.text = totalBudget.toStringAsFixed(0);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Budget"),
        content: TextField(
          controller: _budgetController, 
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "New Amount (Rs)"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: oceanDeep),
            onPressed: () { _saveBudget(); Navigator.pop(context); }, 
            child: const Text("Save", style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(icon: const Icon(Icons.chevron_left, size: 28), onPressed: () { setState(() => _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1)); _loadWalletData(); }),
        const SizedBox(width: 8),
        Text(DateFormat('MMMM yyyy').format(_selectedDate), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(width: 8),
        IconButton(icon: const Icon(Icons.chevron_right, size: 28), onPressed: () { setState(() => _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1)); _loadWalletData(); }),
      ],
    );
  }
}