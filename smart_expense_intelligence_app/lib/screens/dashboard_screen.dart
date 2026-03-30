import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'add_expense_screen.dart';
import '../models/expense.dart';
import '../services/expense_service.dart';
import 'expense_history_screen.dart'; // Fixed import

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _expenseService = ExpenseService();
  bool _isLoading = true;
  double _totalSpent = 0.0;
  List<Expense> _recentExpenses = [];

  final Color oceanDeep = const Color(0xFF006064);
  final Color oceanLight = const Color(0xFF00838F);

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final allExpenses = await _expenseService.getAllExpenses();
      double sum = 0;
      for (var expense in allExpenses) {
        sum += expense.amount;
      }
      if (mounted) {
        setState(() {
          _totalSpent = sum;
          _recentExpenses = allExpenses.take(5).toList();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], 
      appBar: AppBar(
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
                    Text(
                      "${_getGreeting()}, User!",
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 24),
                    _buildSummaryCard(),
                    const SizedBox(height: 24),
                    _buildRecentTransactionsHeader(),
                    const SizedBox(height: 8),
                    _buildRecentTransactionsList(),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
          );
          if (result == true) {
            _loadDashboardData();
          }
        },
        backgroundColor: oceanDeep,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
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
          Text("Rs ${_totalSpent.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("Budget Limit", style: TextStyle(color: Colors.white70, fontSize: 14)),
              Text("60%", style: TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _totalSpent == 0 ? 0.0 : (_totalSpent / 50000).clamp(0.0, 1.0), 
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("Recent Transactions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        TextButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ExpenseHistoryScreen()),
            );
            _loadDashboardData();
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