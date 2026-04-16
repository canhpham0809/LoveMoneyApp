import 'package:equatable/equatable.dart';

class DashboardEntity extends Equatable {
  final String coupleId;
  final double familyBalance;
  final double monthlyNet;
  final double monthlyBudgetSpent;
  final double monthlyBudgetLimit;
  final List<String> debtReminders;
  final List<String> fundGoals;

  const DashboardEntity({
    required this.coupleId,
    required this.familyBalance,
    required this.monthlyNet,
    required this.monthlyBudgetSpent,
    required this.monthlyBudgetLimit,
    required this.debtReminders,
    required this.fundGoals,
  });

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
