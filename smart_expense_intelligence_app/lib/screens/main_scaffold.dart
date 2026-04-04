import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dashboard_screen.dart';
import 'wallet_screen.dart';
import 'expense_history_screen.dart';
import 'insights_screen.dart';
import 'add_expense_screen.dart';
import '../services/ocr_service.dart';
import '../models/pending_expense.dart';
import '../models/expense.dart';
import '../services/expense_service.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> with SingleTickerProviderStateMixin {
  int _refreshTrigger = 0; // 🔔 THE SILENT ALARM
  int _selectedIndex = 0;
  final Color oceanDeep = const Color(0xFF006064);

  late AnimationController _fabController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _fabAnimation = CurvedAnimation(parent: _fabController, curve: Curves.easeOut);
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

  void _changeTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _scanReceipt() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (image == null) return;

    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.white)));

    final ocrService = OcrService();
    final PendingExpense? extractedData = await ocrService.processReceipt(image.path);

    if (mounted) Navigator.pop(context);

    if (extractedData == null || (extractedData.amount == null && extractedData.merchantName == null)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not read receipt clearly."), backgroundColor: Colors.red));
      return;
    }

    int guessedCategoryId = await ocrService.guessCategoryId(extractedData.merchantName);
    if (mounted) _showConfirmationDialog(extractedData, guessedCategoryId);
  }

  void _showConfirmationDialog(PendingExpense data, int guessedCategoryId) {
    final amountController = TextEditingController(text: data.amount?.toStringAsFixed(2) ?? '');
    final merchantController = TextEditingController(text: data.merchantName ?? '');
    int selectedCategoryId = guessedCategoryId;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: Row(children: [Icon(Icons.auto_awesome, color: oceanDeep), const SizedBox(width: 8), const Text("Smart Extract")]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: "Amount (Rs)", border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: merchantController, decoration: const InputDecoration(labelText: "Merchant Name", border: OutlineInputBorder())),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: selectedCategoryId,
                  decoration: const InputDecoration(labelText: "Category", border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text("Food & Dining")),
                    DropdownMenuItem(value: 2, child: Text("Transport")),
                    DropdownMenuItem(value: 3, child: Text("Entertainment")),
                    DropdownMenuItem(value: 4, child: Text("Shopping")),
                    DropdownMenuItem(value: 5, child: Text("Bills & Utilities")),
                    DropdownMenuItem(value: 6, child: Text("Other")),
                  ],
                  onChanged: (val) { if (val != null) setDialogState(() => selectedCategoryId = val); },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Discard", style: TextStyle(color: Colors.red))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: oceanDeep),
              onPressed: () async {
                final confirmedExpense = Expense(
                  amount: double.tryParse(amountController.text) ?? 0.0,
                  categoryId: selectedCategoryId,
                  merchantName: merchantController.text.isNotEmpty ? merchantController.text : 'Unknown',
                  dateTime: DateTime.now(),
                  source: data.source ?? 'unknown',
                );
                await ExpenseService().addExpense(confirmedExpense);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Expense saved!")));
                  setState(() { _refreshTrigger++; }); // 🔔 ALARM FIRED
                }
              },
              child: const Text("Save", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Passing the trigger down to the screens!
    // (Make sure you updated WalletScreen and ExpenseHistoryScreen constructors too!)
    final List<Widget> pages = [
      DashboardScreen(onChangeTab: _changeTab, refreshTrigger: _refreshTrigger),
      WalletScreen(refreshTrigger: _refreshTrigger),
      ExpenseHistoryScreen(refreshTrigger: _refreshTrigger),
      const InsightsScreen(), 
    ];

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _selectedIndex, children: pages),
          
          if (_fabController.isAnimating || _fabController.isCompleted)
            IgnorePointer(
              ignoring: !_fabController.isCompleted,
              child: GestureDetector(
                onTap: _toggleFab,
                child: FadeTransition(opacity: _fabAnimation, child: Container(color: Colors.black.withOpacity(0.5))),
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
              onPressed: () { _toggleFab(); _scanReceipt(); },
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
                await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddExpenseScreen()));
                setState(() { _refreshTrigger++; }); // 🔔 ALARM FIRED
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _changeTab,
        selectedItemColor: oceanDeep,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.pie_chart_outline), activeIcon: Icon(Icons.pie_chart), label: "Analytics"),
          BottomNavigationBarItem(icon: Icon(Icons.history), activeIcon: Icon(Icons.history), label: "History"),
          BottomNavigationBarItem(icon: Icon(Icons.lightbulb_outline), activeIcon: Icon(Icons.lightbulb), label: "Insights"),
        ],
      ),
    );
  }
}