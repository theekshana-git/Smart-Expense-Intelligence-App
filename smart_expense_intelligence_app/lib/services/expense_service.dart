import '../database/database_helper.dart';
import '../models/expense.dart';

class ExpenseService {
  final dbHelper = DatabaseHelper.instance;

  // CREATE
  Future<int> addExpense(Expense expense) async {
    // Basic validation
    if (expense.amount <= 0) {
      throw Exception('Amount must be greater than 0');
    }

    if (expense.source.isEmpty) {
      throw Exception('Source is required');
    }

    return await dbHelper.insertExpense(expense.toMap());
  }

  // READ
  Future<List<Expense>> getAllExpenses() async {
    final data = await dbHelper.getExpenses();
    return data.map((e) => Expense.fromMap(e)).toList();
  }

  // UPDATE
  Future<int> updateExpense(Expense expense) async {
    if (expense.id == null) {
      throw Exception('Expense ID is required for update');
    }

    return await dbHelper.updateExpense(
      expense.id!,
      expense.copyWith(
        updatedAt: DateTime.now(),
      ).toMap(),
    );
  }

  // DELETE
  Future<int> deleteExpense(int id) async {
    return await dbHelper.deleteExpense(id);
  }
}