import 'package:equatable/equatable.dart';

class CategoryModel extends Equatable {
  final String id;
  final String coupleId;
  final String name;
  final String icon;
  final String color;
  final double? budgetLimit;
  final int sortOrder;
  final bool showInQuickAdd;
  final bool showInExpenseForm;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? updatedBy;
  final bool isDeleted;
  final DateTime? deletedAt;

  const CategoryModel({
    required this.id,
    required this.coupleId,
    required this.name,
    required this.icon,
    required this.color,
    this.budgetLimit,
    required this.sortOrder,
    required this.showInQuickAdd,
    required this.showInExpenseForm,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.updatedBy,
    required this.isDeleted,
    this.deletedAt,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      coupleId: json['couple_id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String,
      color: json['color'] as String,
      budgetLimit: json['budget_limit'] != null
          ? (json['budget_limit'] as num).toDouble()
          : null,
      sortOrder: json['sort_order'] as int,
      showInQuickAdd: (json['show_in_quick_add'] as bool?) ?? true,
      showInExpenseForm: (json['show_in_expense_form'] as bool?) ?? true,
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
      'color': color,
      'budget_limit': budgetLimit,
      'sort_order': sortOrder,
      'show_in_quick_add': showInQuickAdd,
      'show_in_expense_form': showInExpenseForm,
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
    color,
    budgetLimit,
    sortOrder,
    showInQuickAdd,
    showInExpenseForm,
    isActive,
    createdAt,
    updatedAt,
    updatedBy,
    isDeleted,
    deletedAt,
  ];
}
