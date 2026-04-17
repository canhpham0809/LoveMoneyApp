import 'package:equatable/equatable.dart';

class TransferEntity extends Equatable {
  final String id;
  final String coupleId;
  final String fromUserId;
  final String toUserId;
  final String? fromWalletId;
  final String? toWalletId;
  final double amount;
  final String? note;
  final String linkedIncomeId;
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? updatedBy;
  final bool isDeleted;
  final DateTime? deletedAt;

  const TransferEntity({
    required this.id,
    required this.coupleId,
    required this.fromUserId,
    required this.toUserId,
    this.fromWalletId,
    this.toWalletId,
    required this.amount,
    this.note,
    required this.linkedIncomeId,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    this.updatedBy,
    required this.isDeleted,
    this.deletedAt,
  });

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
