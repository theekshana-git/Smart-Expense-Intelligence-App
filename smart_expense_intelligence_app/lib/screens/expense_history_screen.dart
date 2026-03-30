import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../services/expense_service.dart';
import 'add_expense_screen.dart'; 

class ExpenseHistoryScreen extends StatefulWidget {
  const ExpenseHistoryScreen({Key? key}) : super(key: key);

  @override
  _ExpenseHistoryScreenState createState() => _ExpenseHistoryScreenState();
}

class _ExpenseHistoryScreenState extends State<ExpenseHistoryScreen> {
  final _expenseService = ExpenseService();
  final TextEditingController _searchController = TextEditingController();
  final Color oceanDeep = const Color(0xFF006064);
  
  bool _isLoading = true;
  String _searchQuery = '';
  List<Expense> _allExpenses = [];

  @override
  void initState() {
    super.initState();
    _loadAllExpenses();
  }

  Future<void> _loadAllExpenses() async {
    setState(() => _isLoading = true);
    final expenses = await _expenseService.getAllExpenses();
    setState(() {
      _allExpenses = expenses;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _allExpenses.where((e) => 
      (e.merchantName ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
      (e.categoryName ?? '').toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Transaction History'),
        backgroundColor: oceanDeep,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: Icon(Icons.search, color: oceanDeep),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: oceanDeep))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final expense = filtered[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (c) => AddExpenseScreen(expenseToEdit: expense)));
                    _loadAllExpenses();
                  },
                  leading: CircleAvatar(
                    backgroundColor: oceanDeep.withOpacity(0.1),
                    child: Icon(Icons.monetization_on, color: oceanDeep),
                  ),
                  title: Text(expense.merchantName ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${expense.categoryName ?? 'Other'} • ${DateFormat('MMM dd, yyyy').format(expense.dateTime)}'),
                  trailing: Text("- Rs ${expense.amount.toStringAsFixed(0)}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ),
              );
            },
          ),
    );
  }
}