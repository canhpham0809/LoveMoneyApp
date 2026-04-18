enum TransactionType { income, expense, fund, debt, transfer }

class Transaction {
  final String id;
  final TransactionType type;
  final double amount;
  final DateTime date;
  final DateTime createdAt;
  final String title;
  final bool? isIncomingTransfer;

  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.createdAt,
    required this.title,
    this.isIncomingTransfer,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.parse(json['created_at'] as String);
    final rawDate = json['date'] as String?;
    return Transaction(
      id: json['id'] as String,
      type: TransactionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => TransactionType.expense,
      ),
      amount: (json['amount'] as num).toDouble(),
      date: rawDate == null ? createdAt : DateTime.parse(rawDate),
      createdAt: createdAt,
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? (json['title'] as String).trim()
          : 'Giao dịch',
      isIncomingTransfer: json['is_incoming_transfer'] as bool?,
    );
  }
}
