import 'package:equatable/equatable.dart';

class DebtModel extends Equatable {
  final String id;
  final String coupleId;
  final String userId;
  final String debtTypeId;
  final String debtKind;
  final bool recordToIncome;
  final String? linkedIncomeId;
  final String? linkedExpenseId;
  final String name;
  final double originalAmount;
  final double remainingAmount;
  final String creditorName;
  final DateTime startDate;
  final DateTime? dueDate;
  final int? reminderDaysBefore;
  final String? note;
  final bool isClosed;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? updatedBy;
  final bool isDeleted;
  final DateTime? deletedAt;

  const DebtModel({
    required this.id,
    required this.coupleId,
    required this.userId,
    required this.debtTypeId,
    required this.debtKind,
    required this.recordToIncome,
    this.linkedIncomeId,
    this.linkedExpenseId,
    required this.name,
    required this.originalAmount,
    required this.remainingAmount,
    required this.creditorName,
    required this.startDate,
    this.dueDate,
    this.reminderDaysBefore,
    this.note,
    required this.isClosed,
    required this.createdAt,
    required this.updatedAt,
    this.updatedBy,
    required this.isDeleted,
    this.deletedAt,
  });

  factory DebtModel.fromJson(Map<String, dynamic> json) {
    return DebtModel(
      id: json['id'] as String,
      coupleId: json['couple_id'] as String,
      userId: json['user_id'] as String,
      debtTypeId: json['debt_type_id'] as String,
      debtKind: (json['debt_kind'] as String?) ?? 'debt',
      recordToIncome: (json['record_to_income'] as bool?) ?? false,
      linkedIncomeId: json['linked_income_id'] as String?,
      linkedExpenseId: json['linked_expense_id'] as String?,
      name: json['name'] as String,
      originalAmount: (json['original_amount'] as num).toDouble(),
      remainingAmount: (json['remaining_amount'] as num).toDouble(),
      creditorName: json['creditor_name'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : null,
      reminderDaysBefore: json['reminder_days_before'] as int?,
      note: json['note'] as String?,
      isClosed: json['is_closed'] as bool,
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
      'debt_type_id': debtTypeId,
      'debt_kind': debtKind,
      'record_to_income': recordToIncome,
      'linked_income_id': linkedIncomeId,
      'linked_expense_id': linkedExpenseId,
      'name': name,
      'original_amount': originalAmount,
      'remaining_amount': remainingAmount,
      'creditor_name': creditorName,
      'start_date': startDate.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'reminder_days_before': reminderDaysBefore,
      'note': note,
      'is_closed': isClosed,
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
    debtTypeId,
    debtKind,
    recordToIncome,
    linkedIncomeId,
    linkedExpenseId,
    name,
    originalAmount,
    remainingAmount,
    creditorName,
    startDate,
    dueDate,
    reminderDaysBefore,
    note,
    isClosed,
    createdAt,
    updatedAt,
    updatedBy,
    isDeleted,
    deletedAt,
  ];
}
