import 'dart:convert';
import 'package:equatable/equatable.dart';

class DebtModel extends Equatable {
  final String id;
  final String coupleId;
  final String userId;
  final String debtTypeId;
  final int sortOrder;
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
    required this.sortOrder,
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
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
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
      'sort_order': sortOrder,
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
    sortOrder,
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

  bool get isSplitBill {
    if (note == null || !note!.trim().startsWith('{')) return false;
    try {
      final data = jsonDecode(note!);
      return data['is_split'] == true;
    } catch (_) {
      return false;
    }
  }

  SplitBillInfo? get splitBillInfo {
    if (!isSplitBill) return null;
    return SplitBillInfo.fromJson(jsonDecode(note!));
  }
}

class SplitBillInfo {
  final double totalBill;
  final int peopleCount;
  final double shareAmount;
  final String? userNote;
  final List<SplitShare> shares;

  SplitBillInfo({
    required this.totalBill,
    required this.peopleCount,
    required this.shareAmount,
    this.userNote,
    required this.shares,
  });

  factory SplitBillInfo.fromJson(Map<String, dynamic> json) {
    return SplitBillInfo(
      totalBill: (json['total_bill'] as num).toDouble(),
      peopleCount: (json['people_count'] as num).toInt(),
      shareAmount: (json['share_amount'] as num).toDouble(),
      userNote: json['user_note'] as String?,
      shares: (json['shares'] as List)
          .map((e) => SplitShare.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_split': true,
      'total_bill': totalBill,
      'people_count': peopleCount,
      'share_amount': shareAmount,
      'user_note': userNote,
      'shares': shares.map((e) => e.toJson()).toList(),
    };
  }
}

class SplitShare {
  final String name;
  final bool paid;
  final String? paymentId;

  SplitShare({
    required this.name,
    required this.paid,
    this.paymentId,
  });

  factory SplitShare.fromJson(Map<String, dynamic> json) {
    return SplitShare(
      name: json['name'] as String,
      paid: json['paid'] as bool? ?? false,
      paymentId: json['payment_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'paid': paid,
      'payment_id': paymentId,
    };
  }

  SplitShare copyWith({bool? paid, String? paymentId}) {
    return SplitShare(
      name: name,
      paid: paid ?? this.paid,
      paymentId: paymentId ?? this.paymentId,
    );
  }
}
