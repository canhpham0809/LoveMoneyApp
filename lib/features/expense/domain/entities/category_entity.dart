import 'package:equatable/equatable.dart';

class CategoryEntity extends Equatable {
  final String id;
  final String coupleId;
  final String name;
  final String icon;
  final String color;
  final double? budgetLimit;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? updatedBy;
  final bool isDeleted;
  final DateTime? deletedAt;

  const CategoryEntity({
    required this.id,
    required this.coupleId,
    required this.name,
    required this.icon,
    required this.color,
    this.budgetLimit,
    required this.sortOrder,
    required this.isActive,
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
    name,
    icon,
    color,
    budgetLimit,
    sortOrder,
    isActive,
    createdAt,
    updatedAt,
    updatedBy,
    isDeleted,
    deletedAt,
  ];
}
