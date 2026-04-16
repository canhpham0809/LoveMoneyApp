import 'package:equatable/equatable.dart';

class DebtPaymentEntity extends Equatable {
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

  const DebtPaymentEntity({
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
