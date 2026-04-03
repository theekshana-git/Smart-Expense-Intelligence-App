import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../services/expense_service.dart';
import '../services/budget_service.dart';
import '../database/database_helper.dart';
import 'dashboard_screen.dart';
import 'expense_history_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final ExpenseService _expenseService = ExpenseService();
  final BudgetService _budgetService = BudgetService();

  List<Expense> _expenses = [];

  Map<String, double> _budgetData = {};
  double totalBudget = 0.0;
  double spent = 0.0;

  final Color oceanDeep = const Color(0xFF006064);

  int _selectedIndex = 3;
  DateTime _selectedDate = DateTime.now();

  final TextEditingController _budgetController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  Future<void> _loadWalletData() async {
    String monthYear = DateFormat('yyyy-MM').format(_selectedDate);

    final intelligence = await _budgetService.calculateIntelligence(monthYear);

    final allExpenses = await _expenseService.getAllExpenses();

    final filtered = allExpenses.where((expense) {
      return expense.dateTime.year == _selectedDate.year &&
          expense.dateTime.month == _selectedDate.month;
    }).toList();

    filtered.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    setState(() {
      _expenses = filtered;
      _budgetData = intelligence;

      spent = intelligence['spent'] ?? 0.0;
      totalBudget = intelligence['limit'] ?? 0.0;
    });
  }

  // ✅ SAVE / EDIT BUDGET
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
        title: const Text('Wallet'),
        backgroundColor: oceanDeep,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildMonthSelector(),
            const SizedBox(height: 20),

            // ===============================
            // 🔥 ENTER BUDGET WIDGET
            // ===============================
            if (!isBudgetSet)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Enter Budget",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Set your budget for ${DateFormat('MMMM yyyy').format(_selectedDate)}",
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _budgetController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Total Budget (Rs)",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveBudget,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: oceanDeep,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text("Save Budget",
                            style: TextStyle(color: Colors.white)),
                      ),
                    )
                  ],
                ),
              )

            // ===============================
            // 🔥 BUDGET DISPLAY + EDIT
            // ===============================
            else ...[
              // 🔹 HEADER (CENTERED)
              const Center(
                child: Text(
                  "Total Budget",
                  style: TextStyle(color: Colors.grey),
                ),
              ),

              const SizedBox(height: 6),

// 🔹 AMOUNT + EDIT
              Stack(
                alignment: Alignment.center,
                children: [
                  // 👇 Centered Amount
                  Center(
                    child: Text(
                      "Rs ${totalBudget.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // 👇 Edit Button (Right Side)
                  Positioned(
                    right: 0,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor:
                            Colors.black, // 👈 this sets text color
                      ),
                      onPressed: () {
                        _budgetController.text = totalBudget.toStringAsFixed(0);
                        _showEditDialog();
                      },
                      child: const Text("Edit"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                  "Rs ${spent.toStringAsFixed(2)} spent from Rs ${totalBudget.toStringAsFixed(2)}"),
            ],

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Transaction History",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(
                  DateFormat('d/M/yyyy').format(DateTime.now()),
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Column(
              children: _expenses.map((expense) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: oceanDeep.withOpacity(0.1),
                      child: Icon(Icons.monetization_on, color: oceanDeep),
                    ),
                    title: Text(
                      expense.merchantName ?? 'Name',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle:
                        Text(DateFormat('MMM dd').format(expense.dateTime)),
                    trailing: Text(
                      "Rs ${expense.amount.toStringAsFixed(2)}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.home_outlined, "Home", 0),
            _navItem(Icons.bar_chart_outlined, "Analytics", 1),
            _navItem(Icons.history, "History", 2),
            _navItem(Icons.account_balance_wallet_outlined, "Wallet", 3),
          ],
        ),
      ),
    );
  }

  // ✅ EDIT DIALOG
  void _showEditDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Budget"),
        content: TextField(
          controller: _budgetController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Enter amount"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await _saveBudget();
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _selectedDate =
                  DateTime(_selectedDate.year, _selectedDate.month - 1);
            });
            _loadWalletData();
          },
        ),
        Text(
          DateFormat('MMM yyyy').format(_selectedDate),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        IconButton(
          icon: const Icon(Icons.arrow_forward),
          onPressed: () {
            setState(() {
              _selectedDate =
                  DateTime(_selectedDate.year, _selectedDate.month + 1);
            });
            _loadWalletData();
          },
        ),
      ],
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    bool isActive = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });

        if (index == 0) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        } else if (index == 2) {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const ExpenseHistoryScreen()),
          );
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isActive ? oceanDeep : Colors.grey),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? oceanDeep : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
