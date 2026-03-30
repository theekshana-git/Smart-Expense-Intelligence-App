class Expense {
  final int? id;
  final double amount;
  final String categoryId;
  final String merchantName;
  final DateTime dateTime;
  final String source;

  Expense({
    this.id,
    required this.amount,
    required this.categoryId,
    required this.merchantName,
    required this.dateTime,
    this.source = 'manual',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'categoryId': categoryId,
      'merchantName': merchantName,
      'dateTime': dateTime.toIso8601String(),
      'source': source,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['categoryId'] ?? 'Other',
      merchantName: map['merchantName'] ?? 'Unknown',
      dateTime: DateTime.parse(map['dateTime']),
      source: map['source'] ?? 'manual',
    );
  }
}