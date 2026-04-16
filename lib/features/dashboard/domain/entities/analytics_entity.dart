import 'package:equatable/equatable.dart';

class AnalyticsEntity extends Equatable {
  final String coupleId;
  final Map<String, double> expenseByCategory;
  final Map<String, double> incomeBySource;
  final List<double> monthlyTrend;
  final double totalExpense;
  final double totalIncome;

  const AnalyticsEntity({
    required this.coupleId,
    required this.expenseByCategory,
    required this.incomeBySource,
    required this.monthlyTrend,
    required this.totalExpense,
    required this.totalIncome,
  });

  @override
  List<Object?> get props => [
    coupleId,
    expenseByCategory,
    incomeBySource,
    monthlyTrend,
    totalExpense,
    totalIncome,
  ];
}
