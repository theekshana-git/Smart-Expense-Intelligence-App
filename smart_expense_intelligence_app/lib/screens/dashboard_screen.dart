import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart'; 
import 'add_expense_screen.dart';
import '../models/expense.dart';
import '../models/pending_expense.dart'; 
import '../services/expense_service.dart';
import '../services/ocr_service.dart'; 
import 'expense_history_screen.dart'; 

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  final _expenseService = ExpenseService();
  bool _isLoading = true;
  double _totalSpent = 0.0;
  List<Expense> _recentExpenses = [];

  final Color oceanDeep = const Color(0xFF006064);
  final Color oceanLight = const Color(0xFF00838F);

  late AnimationController _fabController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();

    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _fabController.dispose(); 
    super.dispose();
  }

  void _toggleFab() {
    if (_fabController.isDismissed) {
      _fabController.forward();
    } else {
      _fabController.reverse();
    }
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

  Future<void> _scanReceipt() async {
    final picker = ImagePicker();
    
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80, 
    );

    if (image == null) return; 

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    final ocrService = OcrService();
    final PendingExpense? extractedData = await ocrService.processReceipt(image.path);

    if (mounted) Navigator.pop(context);

    if (extractedData == null || (extractedData.amount == null && extractedData.merchantName == null)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not read receipt clearly. Please try again or use manual entry."), backgroundColor: Colors.red),
        );
      }
      return;
    }

    // 🧠 Run the Intelligence Engine (Now properly awaits the DB check!)
    int guessedCategoryId = await ocrService.guessCategoryId(extractedData.merchantName);

    if (mounted) {
      _showOcrConfirmationDialog(extractedData, guessedCategoryId);
    }
  }

  void _showOcrConfirmationDialog(PendingExpense data, int guessedCategoryId) {
    final amountController = TextEditingController(text: data.amount?.toStringAsFixed(2) ?? '');
    final merchantController = TextEditingController(text: data.merchantName ?? '');
    
    // State variable to hold the category the user selects in the dialog
    int selectedCategoryId = guessedCategoryId;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder( 
        builder: (context, setDialogState) {
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
                  // Auto-selected Category Dropdown
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
                    source: 'ocr',
                    createdAt: DateTime.now(),
                  );

                  await _expenseService.addExpense(confirmedExpense);
                  
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Receipt saved successfully!")),
                    );
                    _loadDashboardData();
                  }
                },
                child: const Text("Save Expense", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
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
      body: Stack(
        children: [
          _isLoading
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
          
          if (_fabController.isAnimating || _fabController.isCompleted)
            IgnorePointer(
              ignoring: !_fabController.isCompleted,
              child: GestureDetector(
                onTap: _toggleFab,
                child: FadeTransition(
                  opacity: _fabAnimation,
                  child: Container(color: Colors.black.withOpacity(0.5)),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ScaleTransition(
            scale: _fabAnimation,
            child: FloatingActionButton.extended(
              heroTag: 'scan',
              onPressed: () {
                _toggleFab();
                _scanReceipt(); 
              },
              backgroundColor: Colors.white,
              icon: Icon(Icons.camera_alt, color: oceanDeep),
              label: Text("Scan Receipt", style: TextStyle(color: oceanDeep, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
          ScaleTransition(
            scale: _fabAnimation,
            child: FloatingActionButton.extended(
              heroTag: 'manual',
              onPressed: () async {
                _toggleFab();
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
                );
                if (result == true) {
                  _loadDashboardData();
                }
              },
              backgroundColor: Colors.white,
              icon: Icon(Icons.edit, color: oceanDeep),
              label: Text("Manual Entry", style: TextStyle(color: oceanDeep, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'main',
            onPressed: _toggleFab,
            backgroundColor: oceanDeep,
            child: RotationTransition(
              turns: Tween(begin: 0.0, end: 0.125).animate(_fabAnimation),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ],
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