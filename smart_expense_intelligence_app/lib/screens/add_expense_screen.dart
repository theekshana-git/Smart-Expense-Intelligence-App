import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../services/expense_service.dart';

class AddExpenseScreen extends StatefulWidget {
  final Expense? expenseToEdit;
  const AddExpenseScreen({Key? key, this.expenseToEdit}) : super(key: key);

  @override
  _AddExpenseScreenState createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  
  String? _selectedCategoryName;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  final Color oceanDeep = const Color(0xFF006064);

  final Map<String, IconData> _categoryData = {
    'Food & Dining': Icons.restaurant,
    'Transport': Icons.directions_bus,
    'Entertainment': Icons.movie,
    'Shopping': Icons.shopping_bag,
    'Bills & Utilities': Icons.receipt,
    'Other': Icons.category,
  };

  bool get isEditing => widget.expenseToEdit != null;

  // --- Backend Mappers ---
  int _getCategoryId(String name) {
    switch (name) {
      case 'Food & Dining': return 1;
      case 'Transport': return 2;
      case 'Entertainment': return 3;
      case 'Shopping': return 4;
      case 'Bills & Utilities': return 5;
      default: return 6; // Other
    }
  }

  String _getCategoryName(int id) {
    switch (id) {
      case 1: return 'Food & Dining';
      case 2: return 'Transport';
      case 3: return 'Entertainment';
      case 4: return 'Shopping';
      case 5: return 'Bills & Utilities';
      default: return 'Other';
    }
  }

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _amountController.text = widget.expenseToEdit!.amount.toString();
      _noteController.text = widget.expenseToEdit!.merchantName ?? '';
      _selectedCategoryName = widget.expenseToEdit!.categoryName ?? _getCategoryName(widget.expenseToEdit!.categoryId);
      _selectedDate = widget.expenseToEdit!.dateTime;
    } else {
      _selectedCategoryName = _categoryData.keys.first; 
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: oceanDeep, onPrimary: Colors.white, onSurface: oceanDeep),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _deleteExpense() async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Expense?"),
        content: const Text("Are you sure you want to remove this record?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && widget.expenseToEdit?.id != null) {
      await ExpenseService().deleteExpense(widget.expenseToEdit!.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Expense deleted successfully"))
        );
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _saveOrUpdateExpense() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      
      // Building the Model with your rock-solid architecture
      final expenseData = Expense(
        id: isEditing ? widget.expenseToEdit!.id : null,
        amount: double.parse(_amountController.text),
        categoryId: _getCategoryId(_selectedCategoryName ?? 'Other'),
        merchantName: _noteController.text.isNotEmpty ? _noteController.text : 'Unknown', 
        dateTime: _selectedDate,
        source: isEditing ? widget.expenseToEdit!.source : 'manual',
        createdAt: isEditing ? widget.expenseToEdit!.createdAt : DateTime.now(),
      );

      if (isEditing) {
        await ExpenseService().updateExpense(expenseData);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text("Changes updated!"), backgroundColor: oceanDeep)
        );
      } else {
        await ExpenseService().addExpense(expenseData);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text("Expense saved!"), backgroundColor: oceanDeep)
        );
      }

      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Expense' : 'Add Expense', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: oceanDeep,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (isEditing) IconButton(icon: const Icon(Icons.delete_outline), onPressed: _deleteExpense),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Amount (Rs)', 
                  prefixIcon: Icon(Icons.attach_money, color: oceanDeep),
                  border: InputBorder.none,
                ),
                validator: (value) => (value == null || value.isEmpty) ? 'Enter amount' : null,
              ),
              const Divider(),
              const SizedBox(height: 30),
              const Text("Category", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: _categoryData.entries.map((entry) {
                  final isSelected = _selectedCategoryName == entry.key;
                  return ChoiceChip(
                    label: Text(entry.key),
                    avatar: Icon(
                      entry.value, 
                      color: isSelected ? Colors.white : oceanDeep, 
                      size: 18
                    ),
                    selected: isSelected,
                    selectedColor: oceanDeep,
                    backgroundColor: Colors.grey.shade100,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onSelected: (selected) => setState(() => _selectedCategoryName = entry.key),
                  );
                }).toList(),
              ),
              const SizedBox(height: 30),
              const Text("Date", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _selectDate(context),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: oceanDeep, size: 20),
                      const SizedBox(width: 12),
                      Text(DateFormat('MMMM dd, yyyy').format(_selectedDate), style: const TextStyle(fontSize: 16)),
                      const Spacer(),
                      Text('Change', style: TextStyle(color: oceanDeep, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: 'Merchant / Note', 
                  prefixIcon: Icon(Icons.store, color: oceanDeep), 
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveOrUpdateExpense,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: oceanDeep, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  child: _isSaving 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text('Save Expense', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}