import 'package:equatable/equatable.dart';

class ExpenseEntity extends Equatable {
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

  const ExpenseEntity({
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
  });

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
  ];
}
