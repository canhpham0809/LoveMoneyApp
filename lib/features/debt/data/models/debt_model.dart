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

  bool get isBankLoan {
    if (note == null || !note!.trim().startsWith('{')) return false;
    try {
      final data = jsonDecode(note!);
      return data['is_bank_loan'] == true;
    } catch (_) {
      return false;
    }
  }

  BankLoanInfo? get bankLoanInfo {
    if (!isBankLoan) return null;
    return BankLoanInfo.fromJson(jsonDecode(note!));
  }

  String? get displayNote {
    if (note == null) return null;
    if (!note!.trim().startsWith('{')) return note;
    try {
      final data = jsonDecode(note!);
      return data['user_note'] as String?;
    } catch (_) {
      return note;
    }
  }

  List<DebtIncrement> get increments {
    if (note == null || !note!.trim().startsWith('{')) return [];
    try {
      final data = jsonDecode(note!);
      if (data['increments'] is List) {
        return (data['increments'] as List)
            .map((e) => DebtIncrement.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return [];
  }
}

class DebtIncrement extends Equatable {
  final double amount;
  final DateTime date;
  final String? note;
  final String? linkedIncomeId;
  final String? linkedExpenseId;
  final DateTime? createdAt;

  const DebtIncrement({
    required this.amount,
    required this.date,
    this.note,
    this.linkedIncomeId,
    this.linkedExpenseId,
    this.createdAt,
  });

  factory DebtIncrement.fromJson(Map<String, dynamic> json) {
    return DebtIncrement(
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      note: json['note'] as String?,
      linkedIncomeId: json['linked_income_id'] as String?,
      linkedExpenseId: json['linked_expense_id'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'date': date.toIso8601String().substring(0, 10),
      'note': note,
      'linked_income_id': linkedIncomeId,
      'linked_expense_id': linkedExpenseId,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        amount,
        date,
        note,
        linkedIncomeId,
        linkedExpenseId,
        createdAt,
      ];
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

class BankLoanInfo {
  final int totalMonths;
  final int repaymentDay;
  final List<InterestRateRule> interestRules;
  final List<RepaymentScheduleItem> schedule;

  BankLoanInfo({
    required this.totalMonths,
    required this.repaymentDay,
    required this.interestRules,
    required this.schedule,
  });

  factory BankLoanInfo.fromJson(Map<String, dynamic> json) {
    return BankLoanInfo(
      totalMonths: json['total_months'] as int,
      repaymentDay: json['repayment_day'] as int,
      interestRules: (json['interest_rules'] as List)
          .map((e) => InterestRateRule.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      schedule: (json['schedule'] as List)
          .map((e) => RepaymentScheduleItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_bank_loan': true,
      'total_months': totalMonths,
      'repayment_day': repaymentDay,
      'interest_rules': interestRules.map((e) => e.toJson()).toList(),
      'schedule': schedule.map((e) => e.toJson()).toList(),
    };
  }
}

class InterestRateRule {
  final int fromMonth;
  final int toMonth;
  final double rate;

  InterestRateRule({
    required this.fromMonth,
    required this.toMonth,
    required this.rate,
  });

  factory InterestRateRule.fromJson(Map<String, dynamic> json) {
    return InterestRateRule(
      fromMonth: json['from_month'] as int,
      toMonth: json['to_month'] as int,
      rate: (json['rate'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'from_month': fromMonth,
      'to_month': toMonth,
      'rate': rate,
    };
  }
}

class RepaymentScheduleItem {
  final int monthIndex;
  final DateTime dueDate;
  final double principal;
  final double interest;
  final double rate;
  final double paidAmount;
  final String? paymentId;
  final String? expenseId;
  final DateTime? paidDate;
  final bool isPaid;
  final double earlyPrincipal;
  final double penaltyFee;

  RepaymentScheduleItem({
    required this.monthIndex,
    required this.dueDate,
    required this.principal,
    required this.interest,
    required this.rate,
    this.paidAmount = 0.0,
    this.paymentId,
    this.expenseId,
    this.paidDate,
    this.isPaid = false,
    this.earlyPrincipal = 0.0,
    this.penaltyFee = 0.0,
  });

  factory RepaymentScheduleItem.fromJson(Map<String, dynamic> json) {
    return RepaymentScheduleItem(
      monthIndex: json['month_index'] as int,
      dueDate: DateTime.parse(json['due_date'] as String),
      principal: (json['principal'] as num).toDouble(),
      interest: (json['interest'] as num).toDouble(),
      rate: (json['rate'] as num).toDouble(),
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0.0,
      paymentId: json['payment_id'] as String?,
      expenseId: json['expense_id'] as String?,
      paidDate: json['paid_date'] != null ? DateTime.parse(json['paid_date'] as String) : null,
      isPaid: json['is_paid'] as bool? ?? false,
      earlyPrincipal: (json['early_principal'] as num?)?.toDouble() ?? 0.0,
      penaltyFee: (json['penalty_fee'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'month_index': monthIndex,
      'due_date': dueDate.toIso8601String().substring(0, 10),
      'principal': principal,
      'interest': interest,
      'rate': rate,
      'paid_amount': paidAmount,
      'payment_id': paymentId,
      'expense_id': expenseId,
      'paid_date': paidDate?.toIso8601String().substring(0, 10),
      'is_paid': isPaid,
      'early_principal': earlyPrincipal,
      'penalty_fee': penaltyFee,
    };
  }

  RepaymentScheduleItem copyWith({
    double? paidAmount,
    String? paymentId,
    String? expenseId,
    DateTime? paidDate,
    bool? isPaid,
    double? earlyPrincipal,
    double? penaltyFee,
  }) {
    return RepaymentScheduleItem(
      monthIndex: monthIndex,
      dueDate: dueDate,
      principal: principal,
      interest: interest,
      rate: rate,
      paidAmount: paidAmount ?? this.paidAmount,
      paymentId: paymentId ?? this.paymentId,
      expenseId: expenseId ?? this.expenseId,
      paidDate: paidDate ?? this.paidDate,
      isPaid: isPaid ?? this.isPaid,
      earlyPrincipal: earlyPrincipal ?? this.earlyPrincipal,
      penaltyFee: penaltyFee ?? this.penaltyFee,
    );
  }
}
