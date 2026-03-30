class MonthlyBudget {
  final int? id;
  final String monthYear; // Format: 'YYYY-MM'
  final double limitAmount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MonthlyBudget({
    this.id,
    required this.monthYear,
    required this.limitAmount,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'month_year': monthYear,
      'limit_amount': limitAmount,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory MonthlyBudget.fromMap(Map<String, dynamic> map) {
    return MonthlyBudget(
      id: map['id'],
      monthYear: map['month_year'],
      limitAmount: (map['limit_amount'] as num).toDouble(),
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
    );
  }

  MonthlyBudget copyWith({
    int? id,
    String? monthYear,
    double? limitAmount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MonthlyBudget(
      id: id ?? this.id,
      monthYear: monthYear ?? this.monthYear,
      limitAmount: limitAmount ?? this.limitAmount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}