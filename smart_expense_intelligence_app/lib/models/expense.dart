class Expense {
  final int? id;
  final double amount;
  final int categoryId;
  final String? merchantName;
  final DateTime dateTime;
  final String? note;
  final String source; // 'manual', 'ocr', 'sms'
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  // Extra field for UI convenience (populated via SQL JOIN)
  final String? categoryName;

  Expense({
    this.id,
    required this.amount,
    required this.categoryId,
    this.merchantName,
    required this.dateTime,
    this.note,
    required this.source,
    this.createdAt,
    this.updatedAt,
    this.categoryName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'category_id': categoryId,
      'merchant_name': merchantName,
      'date_time': dateTime.toIso8601String(),
      'note': note,
      'source': source,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      amount: (map['amount']as num).toDouble(),
      categoryId: map['category_id'],
      merchantName: map['merchant_name'],
      dateTime: DateTime.parse(map['date_time']),
      note: map['note'],
      source: map['source'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      categoryName: map['category_name'], // Populated if your query includes a JOIN
    );
  }

  Expense copyWith({
    int? id,
    double? amount,
    int? categoryId,
    String? merchantName,
    DateTime? dateTime,
    String? note,
    String? source,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? categoryName,
  }) {
    return Expense(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      merchantName: merchantName ?? this.merchantName,
      dateTime: dateTime ?? this.dateTime,
      note: note ?? this.note,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      categoryName: categoryName ?? this.categoryName,
    );
  }
}