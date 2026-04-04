import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../models/pending_expense.dart';
import '../services/expense_service.dart';
import '../services/ocr_service.dart';
import '../services/sms_service.dart';
import '../services/budget_service.dart';
import '../database/database_helper.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int)? onChangeTab; 
  final int refreshTrigger; 

  const DashboardScreen({super.key, this.onChangeTab, this.refreshTrigger = 0}); 

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _expenseService = ExpenseService();
  final BudgetService _budgetService = BudgetService();
  
  bool _isLoading = true;
  double _totalSpent = 0.0;
  List<Expense> _recentExpenses = [];
  List<Map<String, dynamic>> _pendingExpenses = [];

  DateTime _selectedDate = DateTime.now();
  Map<String, double> _budgetData = {};

  final Color oceanDeep = const Color(0xFF006064);
  final Color oceanLight = const Color(0xFF00838F);

  @override
  void initState() {
    super.initState();
    final smsService = SmsService();
    smsService.initialize().then((_) {
      _loadDashboardData();
    });
    _loadDashboardData();
  }

  // ✅ MOVED OUTSIDE OF initState!
  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshTrigger != oldWidget.refreshTrigger) {
      _loadDashboardData();
    }
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      String monthYear = DateFormat('yyyy-MM').format(_selectedDate);

      // 1. Get ALL expenses first
      final allExpenses = await _expenseService.getAllExpenses();

      // 2. Filter them for the selected month using Dart (100% reliable)
      final filteredExpenses = allExpenses.where((expense) {
        return expense.dateTime.year == _selectedDate.year &&
            expense.dateTime.month == _selectedDate.month;
      }).toList();

      // 3. Calculate the EXACT total spent from the list
      double calculatedTotalSpent = 0.0;
      for (var exp in filteredExpenses) {
        calculatedTotalSpent += exp.amount;
      }

      // 4. Pass the calculated total to the Intelligence Engine!
      final intelligence = await _budgetService.calculateIntelligence(monthYear, calculatedTotalSpent);

      // 5. Sort latest first for the UI list
      filteredExpenses.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      final pendingData = await DatabaseHelper.instance.getPendingExpenses();

      if (mounted) {
        setState(() {
          _totalSpent = calculatedTotalSpent;
          _recentExpenses = filteredExpenses.take(5).toList();
          _pendingExpenses = pendingData;
          _budgetData = intelligence;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Future<void> _processSmsApproval(Map<String, dynamic> smsExpenseData) async {
    final ocrService = OcrService();
    int guessedCategoryId = await ocrService.guessCategoryId(smsExpenseData['merchant_name']);

    final pendingSmsData = PendingExpense(
      amount: (smsExpenseData['amount'] as num?)?.toDouble(),
      merchantName: smsExpenseData['merchant_name'],
      dateTime: DateTime.tryParse(smsExpenseData['date_time'] ?? '') ?? DateTime.now(),
      source: 'sms',
      createdAt: DateTime.now(),
    );

    if (mounted) {
      _showConfirmationDialog(pendingSmsData, guessedCategoryId, pendingSmsId: smsExpenseData['id']);
    }
  }

  Future<void> _discardSms(int id) async {
    await DatabaseHelper.instance.deletePendingExpense(id);
    _loadDashboardData();
  }

  void _showConfirmationDialog(PendingExpense data, int guessedCategoryId, {int? pendingSmsId}) {
    final amountController = TextEditingController(text: data.amount?.toStringAsFixed(2) ?? '');
    final merchantController = TextEditingController(text: data.merchantName ?? '');
    int selectedCategoryId = guessedCategoryId;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.auto_awesome, color: oceanDeep),
              const SizedBox(width: 8),
              const Text("Smart Extract"),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Please verify the extracted details.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: "Amount (Rs)", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: merchantController,
                  decoration: const InputDecoration(labelText: "Merchant Name", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: selectedCategoryId,
                  decoration: const InputDecoration(labelText: "Category", border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text("Food & Dining")),
                    DropdownMenuItem(value: 2, child: Text("Transport")),
                    DropdownMenuItem(value: 3, child: Text("Entertainment")),
                    DropdownMenuItem(value: 4, child: Text("Shopping")),
                    DropdownMenuItem(value: 5, child: Text("Bills & Utilities")),
                    DropdownMenuItem(value: 6, child: Text("Other")),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedCategoryId = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Discard", style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: oceanDeep),
              onPressed: () async {
                final confirmedExpense = Expense(
                  amount: double.tryParse(amountController.text) ?? 0.0,
                  categoryId: selectedCategoryId,
                  merchantName: merchantController.text.isNotEmpty ? merchantController.text : 'Unknown',
                  dateTime: DateTime.now(),
                  source: data.source ?? 'unknown',
                  createdAt: DateTime.now(),
                );

                await _expenseService.addExpense(confirmedExpense);

                if (pendingSmsId != null) {
                  await DatabaseHelper.instance.deletePendingExpense(pendingSmsId);
                }

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Expense saved successfully!")),
                  );
                  _loadDashboardData(); 
                }
              },
              child: const Text("Save Expense", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }),
    );
  }

  void _showBudgetDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Set Monthly Budget"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Enter amount"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              double amount = double.tryParse(controller.text) ?? 0;
              String monthYear = DateFormat('yyyy-MM').format(_selectedDate);
              await DatabaseHelper.instance.insertBudget(monthYear, amount);
              if(mounted) Navigator.pop(context);
              _loadDashboardData();
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        automaticallyImplyLeading: false, 
        title: const Text('Dashboard'),
        backgroundColor: oceanDeep,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: oceanDeep))
          : RefreshIndicator(
              color: oceanDeep,
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${_getGreeting()}, User!",
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                        ),
                        if (_budgetData.isEmpty)
                          TextButton(
                            onPressed: _showBudgetDialog,
                            child: Text("Enter Budget", style: TextStyle(color: oceanDeep, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    PendingSmsAlerts(
                      pendingExpenses: _pendingExpenses,
                      onApprove: _processSmsApproval,
                      onDiscard: _discardSms,
                    ),
                    const SizedBox(height: 16),
                    _buildSummaryCard(),
                    const SizedBox(height: 24),
                    _buildRecentTransactionsHeader(),
                    const SizedBox(height: 8),
                    _buildRecentTransactionsList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCard() {
    double limit = _budgetData['limit'] ?? 0;
    double spent = _budgetData['spent'] ?? 0;
    double dailySafe = _budgetData['dailySafe'] ?? 0;
    double progress = _budgetData['progress'] ?? 0;

    String percentText = limit > 0 
        ? (spent > limit ? "Exceeded" : "${((spent / limit) * 100).toInt()}%") 
        : "0%";

    return GestureDetector(
      onTap: () {
        if (widget.onChangeTab != null) widget.onChangeTab!(1);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [oceanLight, oceanDeep], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: oceanDeep.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Total Spent This Month", style: TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 8),
            Text("Rs ${spent.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Budget Limit: Rs ${limit.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                Text(percentText, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 16),
            Text("Daily Safe Spend: Rs ${dailySafe.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactionsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Recent Transactions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        TextButton(
          onPressed: () {
            if (widget.onChangeTab != null) widget.onChangeTab!(2);
          },
          child: Text("See All", style: TextStyle(color: oceanDeep, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildRecentTransactionsList() {
    if (_recentExpenses.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text("No expenses yet. Add one!", style: TextStyle(color: Colors.grey))));
    }
    return Column(
      children: _recentExpenses.map((expense) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: oceanDeep.withOpacity(0.1), child: Icon(Icons.monetization_on, color: oceanDeep)),
            title: Text(expense.merchantName ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(DateFormat('MMM dd').format(expense.dateTime)),
            trailing: Text("- Rs ${expense.amount.toStringAsFixed(0)}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        );
      }).toList(),
    );
  }
}

// ============================================================================
// --- Pending SMS Alerts Widget (Themed) ---
// ============================================================================

class PendingSmsAlerts extends StatelessWidget {
  final List<Map<String, dynamic>> pendingExpenses;
  final Function(Map<String, dynamic>) onApprove;
  final Function(int) onDiscard;

  const PendingSmsAlerts({
    super.key,
    required this.pendingExpenses,
    required this.onApprove,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    if (pendingExpenses.isEmpty) {
      return const SizedBox.shrink();
    }

    const Color oceanDeep = Color(0xFF006064);

    return Column(
      children: pendingExpenses.map((expense) {
        return Card(
          color: oceanDeep.withOpacity(0.05),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: oceanDeep.withOpacity(0.2), width: 1),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: oceanDeep.withOpacity(0.1), child: Icon(Icons.sms, color: oceanDeep, size: 20)),
            title: Text(
              "Found SMS: ${expense['merchant_name']}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
            ),
            subtitle: Text("Amount: Rs. ${expense['amount']}", style: const TextStyle(color: oceanDeep, fontWeight: FontWeight.w600)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.close, color: Colors.redAccent), onPressed: () => onDiscard(expense['id']), tooltip: "Discard"),
                IconButton(icon: const Icon(Icons.check_circle, color: oceanDeep, size: 28), onPressed: () => onApprove(expense), tooltip: "Approve"),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}