import 'package:equatable/equatable.dart';

class FundContributionEntity extends Equatable {
  final String id;
  final String coupleId;
  final String userId;
  final String fundId;
  final String walletId;
  final double amount;
  final String? note;
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? updatedBy;
  final bool isDeleted;
  final DateTime? deletedAt;

  const FundContributionEntity({
    required this.id,
    required this.coupleId,
    required this.userId,
    required this.fundId,
    required this.walletId,
    required this.amount,
    this.note,
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
    fundId,
    walletId,
    amount,
    note,
    date,
    createdAt,
    updatedAt,
    updatedBy,
    isDeleted,
    deletedAt,
  ];
}
