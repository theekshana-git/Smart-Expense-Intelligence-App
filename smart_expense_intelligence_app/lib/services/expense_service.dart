import '../repositories/expense_repository.dart';
import '../models/expense.dart';

class ExpenseService {
  final ExpenseRepository _repository = ExpenseRepository();

  Future<void> addExpense(Expense expense) async => await _repository.insertExpense(expense);
  Future<void> updateExpense(Expense expense) async => await _repository.updateExpense(expense);
  Future<void> deleteExpense(int id) async => await _repository.deleteExpense(id);
  Future<List<Expense>> getAllExpenses() async => await _repository.getAllExpenses();
}