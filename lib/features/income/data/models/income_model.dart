import 'package:equatable/equatable.dart';

class IncomeModel extends Equatable {
  final String id;
  final String coupleId;
  final String userId;
  final String? walletId;
  final String? incomeSourceId;
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

  const IncomeModel({
    required this.id,
    required this.coupleId,
    required this.userId,
    this.walletId,
    this.incomeSourceId,
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

  factory IncomeModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value, {DateTime? fallback}) {
      if (value is String && value.trim().isNotEmpty) {
        return DateTime.parse(value);
      }
      return fallback ?? DateTime.now();
    }

    return IncomeModel(
      id: json['id'] as String,
      coupleId: json['couple_id'] as String,
      userId: json['user_id'] as String,
      walletId: json['wallet_id'] as String?,
      incomeSourceId: json['income_source_id'] as String?,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String?,
      isFromTransfer: (json['is_from_transfer'] as bool?) ?? false,
      linkedTransferId: json['linked_transfer_id'] as String?,
      date: parseDate(json['date']),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(
        json['updated_at'],
        fallback: parseDate(json['created_at']),
      ),
      updatedBy: json['updated_by'] as String?,
      isDeleted: (json['is_deleted'] as bool?) ?? false,
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
      'wallet_id': walletId,
      'income_source_id': incomeSourceId,
      'amount': amount,
      'description': description,
      'is_from_transfer': isFromTransfer,
      'linked_transfer_id': linkedTransferId,
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
