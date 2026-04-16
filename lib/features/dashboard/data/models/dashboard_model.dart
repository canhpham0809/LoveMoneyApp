import 'package:equatable/equatable.dart';

class DashboardModel extends Equatable {
  final String coupleId;
  final double familyBalance;
  final double monthlyNet;
  final double monthlyBudgetSpent;
  final double monthlyBudgetLimit;
  final List<String> debtReminders;
  final List<String> fundGoals;

  const DashboardModel({
    required this.coupleId,
    required this.familyBalance,
    required this.monthlyNet,
    required this.monthlyBudgetSpent,
    required this.monthlyBudgetLimit,
    required this.debtReminders,
    required this.fundGoals,
  });

  factory DashboardModel.fromJson(Map<String, dynamic> json) {
    return DashboardModel(
      coupleId: json['couple_id'] as String,
      familyBalance: (json['family_balance'] as num).toDouble(),
      monthlyNet: (json['monthly_net'] as num).toDouble(),
      monthlyBudgetSpent: (json['monthly_budget_spent'] as num).toDouble(),
      monthlyBudgetLimit: (json['monthly_budget_limit'] as num).toDouble(),
      debtReminders: List<String>.from(json['debt_reminders'] as List),
      fundGoals: List<String>.from(json['fund_goals'] as List),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'couple_id': coupleId,
      'family_balance': familyBalance,
      'monthly_net': monthlyNet,
      'monthly_budget_spent': monthlyBudgetSpent,
      'monthly_budget_limit': monthlyBudgetLimit,
      'debt_reminders': debtReminders,
      'fund_goals': fundGoals,
    };
  }

  @override
  List<Object?> get props => [
    coupleId,
    familyBalance,
    monthlyNet,
    monthlyBudgetSpent,
    monthlyBudgetLimit,
    debtReminders,
    fundGoals,
  ];
}
