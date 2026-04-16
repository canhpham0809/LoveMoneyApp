import 'package:equatable/equatable.dart';

class DebtPaymentModel extends Equatable {
  final String id;
  final String coupleId;
  final String debtId;
  final String walletId;
  final double amount;
  final DateTime date;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? updatedBy;
  final bool isDeleted;
  final DateTime? deletedAt;

  const DebtPaymentModel({
    required this.id,
    required this.coupleId,
    required this.debtId,
    required this.walletId,
    required this.amount,
    required this.date,
    this.note,
    required this.createdAt,
    required this.updatedAt,
    this.updatedBy,
    required this.isDeleted,
    this.deletedAt,
  });

  factory DebtPaymentModel.fromJson(Map<String, dynamic> json) {
    return DebtPaymentModel(
      id: json['id'] as String,
      coupleId: json['couple_id'] as String,
      debtId: json['debt_id'] as String,
      walletId: json['wallet_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      updatedBy: json['updated_by'] as String?,
      isDeleted: json['is_deleted'] as bool,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'couple_id': coupleId,
      'debt_id': debtId,
      'wallet_id': walletId,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'updated_by': updatedBy,
      'is_deleted': isDeleted,
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    coupleId,
    debtId,
    walletId,
    amount,
    date,
    note,
    createdAt,
    updatedAt,
    updatedBy,
    isDeleted,
    deletedAt,
  ];
}
