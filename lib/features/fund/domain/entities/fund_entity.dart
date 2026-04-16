import 'package:equatable/equatable.dart';

class FundEntity extends Equatable {
  final String id;
  final String coupleId;
  final String name;
  final String? icon;
  final double? targetAmount;
  final double currentAmount;
  final DateTime? deadline;
  final String? color;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? updatedBy;
  final bool isDeleted;
  final DateTime? deletedAt;

  const FundEntity({
    required this.id,
    required this.coupleId,
    required this.name,
    this.icon,
    this.targetAmount,
    required this.currentAmount,
    this.deadline,
    this.color,
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
    targetAmount,
    currentAmount,
    deadline,
    color,
    isActive,
    createdAt,
    updatedAt,
    updatedBy,
    isDeleted,
    deletedAt,
  ];
}
