import 'package:equatable/equatable.dart';

class FundModel extends Equatable {
  final String id;
  final String coupleId;
  final String name;
  final String? icon;
  final int sortOrder;
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

  const FundModel({
    required this.id,
    required this.coupleId,
    required this.name,
    this.icon,
    required this.sortOrder,
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

  factory FundModel.fromJson(Map<String, dynamic> json) {
    return FundModel(
      id: json['id'] as String,
      coupleId: json['couple_id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      targetAmount: json['target_amount'] != null
          ? (json['target_amount'] as num).toDouble()
          : null,
      currentAmount: (json['current_amount'] as num).toDouble(),
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'] as String)
          : null,
      color: json['color'] as String?,
      isActive: json['is_active'] as bool,
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
      'name': name,
      'icon': icon,
      'sort_order': sortOrder,
      'target_amount': targetAmount,
      'current_amount': currentAmount,
      'deadline': deadline?.toIso8601String(),
      'color': color,
      'is_active': isActive,
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
    name,
    icon,
    sortOrder,
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
