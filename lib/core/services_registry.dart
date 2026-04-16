import 'package:flutter_app_demo/features/wallet/data/services/wallet_service.dart';
import 'package:flutter_app_demo/features/expense/data/services/expense_service.dart';
import 'package:flutter_app_demo/features/income/data/services/income_service.dart';
import 'package:flutter_app_demo/features/transfer/data/services/transfer_service.dart';
import 'package:flutter_app_demo/features/fund/data/services/fund_service.dart';
import 'package:flutter_app_demo/features/debt/data/services/debt_service.dart';
import 'package:flutter_app_demo/features/dashboard/data/services/dashboard_service.dart';
import 'package:flutter_app_demo/features/settings/data/services/settings_service.dart';

/// Convenience accessors — all services use Supabase.instance.client directly.
class ServiceRegistry {
  final WalletService walletService = WalletService();
  final ExpenseService expenseService = ExpenseService();
  final IncomeService incomeService = IncomeService();
  final TransferService transferService = TransferService();
  final FundService fundService = FundService();
  final DebtService debtService = DebtService();
  final DashboardService dashboardService = DashboardService();
  final SettingsService settingsService = SettingsService();
}
