import 'package:flutter/material.dart';
import 'services/expense_service.dart';
import 'models/expense.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Expense DB Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const DbTestScreen(),
    );
  }
}

class DbTestScreen extends StatefulWidget {
  const DbTestScreen({super.key});

  @override
  State<DbTestScreen> createState() => _DbTestScreenState();
}

class _DbTestScreenState extends State<DbTestScreen> {
  // 1. Instantiate the Service Layer
  final ExpenseService _expenseService = ExpenseService();
  
  // 2. State is now a strongly typed List of Expense Models!
  List<Expense> _expenses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshExpenses();
  }

  // Fetch data using the Service
  Future<void> _refreshExpenses() async {
    setState(() => _isLoading = true);
    try {
      final data = await _expenseService.getAllExpenses();
      setState(() {
        _expenses = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error fetching expenses: $e');
    }
  }

  // Add a test expense using the Model and Service
  Future<void> _addTestExpense() async {
    // Create an instance of the Model
    final newExpense = Expense(
      amount: 1500.50,
      categoryId: 1, // 'Food & Dining' based on your default DB setup
      merchantName: 'Pizza Hut Test',
      dateTime: DateTime.now(),
      note: 'Test entry via Service Layer',
      source: 'manual',
    );

    try {
      // Pass the Model to the Service
      await _expenseService.addExpense(newExpense);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test Expense Added via Service!')),
        );
      }
      _refreshExpenses(); // Reload UI
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Delete an expense using the Service
  Future<void> _deleteExpense(int id) async {
    await _expenseService.deleteExpense(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense Deleted!')),
      );
    }
    _refreshExpenses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Layered Architecture Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _expenses.isEmpty
              ? const Center(child: Text('No expenses yet. Add one!'))
              : ListView.builder(
                  itemCount: _expenses.length,
                  itemBuilder: (context, index) {
                    // 3. UI now uses the strongly typed Expense Model
                    final expense = _expenses[index];
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(expense.id.toString()),
                        ),
                        // Notice how we use dot notation (expense.amount) instead of map keys (expense['amount'])
                        title: Text('Rs ${expense.amount} - ${expense.merchantName ?? 'Unknown'}'),
                        subtitle: Text(
                          'Category: ${expense.categoryName ?? 'ID: ${expense.categoryId}'}\n'
                          'Source: ${expense.source}\n'
                          'Date: ${expense.dateTime.toString().split(' ')[0]}',
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteExpense(expense.id!),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTestExpense,
        label: const Text('Add Test Expense'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}