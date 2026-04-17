import 'package:equatable/equatable.dart';

class FundContributionModel extends Equatable {
  final String id;
  final String coupleId;
  final String userId;
  final String fundId;
  final String walletId;
  final double amount;
  final String contributionType;
  final String? linkedIncomeId;
  final String? note;
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? updatedBy;
  final bool isDeleted;
  final DateTime? deletedAt;

  const FundContributionModel({
    required this.id,
    required this.coupleId,
    required this.userId,
    required this.fundId,
    required this.walletId,
    required this.amount,
    required this.contributionType,
    this.linkedIncomeId,
    this.note,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    this.updatedBy,
    required this.isDeleted,
    this.deletedAt,
  });

  factory FundContributionModel.fromJson(Map<String, dynamic> json) {
    return FundContributionModel(
      id: json['id'] as String,
      coupleId: json['couple_id'] as String,
      userId: json['user_id'] as String,
      fundId: json['fund_id'] as String,
      walletId: json['wallet_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      contributionType:
          (json['contribution_type'] as String?) ?? 'contribution',
      linkedIncomeId: json['linked_income_id'] as String?,
      note: json['note'] as String?,
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
      'user_id': userId,
      'fund_id': fundId,
      'wallet_id': walletId,
      'amount': amount,
      'contribution_type': contributionType,
      'linked_income_id': linkedIncomeId,
      'note': note,
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
    userId,
    fundId,
    walletId,
    amount,
    contributionType,
    linkedIncomeId,
    note,
    date,
    createdAt,
    updatedAt,
    updatedBy,
    isDeleted,
    deletedAt,
  ];
}
