import 'package:equatable/equatable.dart';

class ExpenseModel extends Equatable {
  final String id;
  final String coupleId;
  final String userId;
  final String walletId;
  final String categoryId;
  final String? categoryName;
  final String? categoryIcon;
  final double amount;
  final String? description;
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? updatedBy;
  final bool isDeleted;
  final DateTime? deletedAt;
  final String? eventId;

  const ExpenseModel({
    required this.id,
    required this.coupleId,
    required this.userId,
    required this.walletId,
    required this.categoryId,
    this.categoryName,
    this.categoryIcon,
    required this.amount,
    this.description,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    this.updatedBy,
    required this.isDeleted,
    this.deletedAt,
    this.eventId,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'] as String,
      coupleId: json['couple_id'] as String,
      userId: json['user_id'] as String,
      walletId: json['wallet_id'] as String,
      categoryId: json['category_id'] as String,
      categoryName: json['category_name'] as String?,
      categoryIcon: json['category_icon'] as String?,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String?,
      date: DateTime.parse(json['date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      updatedBy: json['updated_by'] as String?,
      isDeleted: json['is_deleted'] as bool,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
      eventId: json['event_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'couple_id': coupleId,
      'user_id': userId,
      'wallet_id': walletId,
      'category_id': categoryId,
      'category_name': categoryName,
      'category_icon': categoryIcon,
      'amount': amount,
      'description': description,
      'date': date.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'updated_by': updatedBy,
      'is_deleted': isDeleted,
      'deleted_at': deletedAt?.toIso8601String(),
      'event_id': eventId,
    };
  }

  @override
  List<Object?> get props => [
    id,
    coupleId,
    userId,
    walletId,
    categoryId,
    categoryName,
    categoryIcon,
    amount,
    description,
    date,
    createdAt,
    updatedAt,
    updatedBy,
    isDeleted,
    deletedAt,
    eventId,
  ];
}
