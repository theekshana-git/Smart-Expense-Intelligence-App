class PendingExpense {
  final int? id;
  final double? amount;
  final String? merchantName;
  final DateTime? dateTime;
  final String? source; // 'ocr' or 'sms'
  final DateTime? createdAt;

  PendingExpense({
    this.id,
    this.amount,
    this.merchantName,
    this.dateTime,
    this.source,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'merchant_name': merchantName,
      'date_time': dateTime?.toIso8601String(),
      'source': source,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory PendingExpense.fromMap(Map<String, dynamic> map) {
    return PendingExpense(
      id: map['id'],
      amount: map['amount'],
      merchantName: map['merchant_name'],
      dateTime: map['date_time'] != null ? DateTime.parse(map['date_time']) : null,
      source: map['source'],
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : null,
    );
  }
}