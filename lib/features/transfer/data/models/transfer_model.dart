import 'package:equatable/equatable.dart';

class TransferModel extends Equatable {
  final String id;
  final String coupleId;
  final String fromUserId;
  final String toUserId;
  final String? fromWalletId;
  final String? toWalletId;
  final double amount;
  final String? note;
  final String? linkedIncomeId;
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? updatedBy;
  final bool isDeleted;
  final DateTime? deletedAt;

  const TransferModel({
    required this.id,
    required this.coupleId,
    required this.fromUserId,
    required this.toUserId,
    this.fromWalletId,
    this.toWalletId,
    required this.amount,
    this.note,
    this.linkedIncomeId,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    this.updatedBy,
    required this.isDeleted,
    this.deletedAt,
  });

  factory TransferModel.fromJson(Map<String, dynamic> json) {
    return TransferModel(
      id: json['id'] as String,
      coupleId: json['couple_id'] as String,
      fromUserId: json['from_user_id'] as String,
      toUserId: json['to_user_id'] as String,
      fromWalletId: json['from_wallet_id'] as String?,
      toWalletId: json['to_wallet_id'] as String?,
      amount: (json['amount'] as num).toDouble(),
      note: json['note'] as String?,
      linkedIncomeId: json['linked_income_id'] as String?,
      date: DateTime.parse(json['date'] as String),
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
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'from_wallet_id': fromWalletId,
      'to_wallet_id': toWalletId,
      'amount': amount,
      'note': note,
      'linked_income_id': linkedIncomeId,
      'date': date.toIso8601String(),
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
    fromUserId,
    toUserId,
    fromWalletId,
    toWalletId,
    amount,
    note,
    linkedIncomeId,
    date,
    createdAt,
    updatedAt,
    updatedBy,
    isDeleted,
    deletedAt,
  ];
}
