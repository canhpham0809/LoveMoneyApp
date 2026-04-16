import 'package:equatable/equatable.dart';

class IncomeEntity extends Equatable {
  final String id;
  final String coupleId;
  final String userId;
  final String walletId;
  final String incomeSourceId;
  final double amount;
  final String? description;
  final bool isFromTransfer;
  final String? linkedTransferId;
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? updatedBy;
  final bool isDeleted;
  final DateTime? deletedAt;

  const IncomeEntity({
    required this.id,
    required this.coupleId,
    required this.userId,
    required this.walletId,
    required this.incomeSourceId,
    required this.amount,
    this.description,
    required this.isFromTransfer,
    this.linkedTransferId,
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
    userId,
    walletId,
    incomeSourceId,
    amount,
    description,
    isFromTransfer,
    linkedTransferId,
    date,
    createdAt,
    updatedAt,
    updatedBy,
    isDeleted,
    deletedAt,
  ];
}
