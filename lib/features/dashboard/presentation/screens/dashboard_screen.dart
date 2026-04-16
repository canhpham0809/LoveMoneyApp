import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_app_demo/core/utils/formatters.dart';
import 'package:flutter_app_demo/features/dashboard/data/services/dashboard_service.dart';

class DashboardScreen extends StatefulWidget {
  final String coupleId;

  const DashboardScreen({super.key, required this.coupleId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _service = DashboardService();

  double _totalBalance = 0;
  double _monthlyIncome = 0;
  double _monthlyExpense = 0;
  List<Map<String, dynamic>> _recentTx = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final wallets = await _service.getWalletBalances(widget.coupleId);
      final income = await _service.getMonthlyIncome(widget.coupleId);
      final expense = await _service.getMonthlyExpense(widget.coupleId);
      final tx = await _service.getRecentTransactions(widget.coupleId);
      final balance = wallets.fold<double>(
        0,
        (s, w) => s + ((w['computed_balance'] as num?)?.toDouble() ?? 0),
      );
      if (mounted) {
        setState(() {
          _totalBalance = balance;
          _monthlyIncome = income;
          _monthlyExpense = expense;
          _recentTx = tx;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          IconButton(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: const Text('Thử lại')),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Total balance card
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tổng số dư',
                              style: TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              formatVnd(_totalBalance),
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Monthly summary
                    const Text(
                      'Tháng này',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _summaryRow(
                              'Thu nhập',
                              _monthlyIncome,
                              Colors.green[600]!,
                            ),
                            const Divider(),
                            _summaryRow(
                              'Chi tiêu',
                              _monthlyExpense,
                              Theme.of(context).colorScheme.error,
                            ),
                            const Divider(),
                            _summaryRow(
                              'Còn lại',
                              _monthlyIncome - _monthlyExpense,
                              _monthlyIncome >= _monthlyExpense
                                  ? Colors.green[700]!
                                  : Theme.of(context).colorScheme.error,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Recent transactions
                    const Text(
                      'Giao dịch gần đây',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_recentTx.isEmpty)
                      const Center(child: Text('Chưa có giao dịch nào.'))
                    else
                      ...(_recentTx.map((tx) {
                        final isExpense = tx['type'] == 'expense';
                        final amount = (tx['amount'] as num?)?.toDouble() ?? 0;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isExpense
                                ? Colors.red[50]
                                : Colors.green[50],
                            child: Icon(
                              isExpense
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              color: isExpense ? Colors.red : Colors.green,
                              size: 16,
                            ),
                          ),
                          title: Text(
                            tx['description'] as String? ??
                                (isExpense ? 'Chi tiêu' : 'Thu nhập'),
                          ),
                          subtitle: Text(tx['date'] as String? ?? ''),
                          trailing: Text(
                            '${isExpense ? '-' : '+'}${formatVnd(amount)}',
                            style: TextStyle(
                              color: isExpense
                                  ? Theme.of(context).colorScheme.error
                                  : Colors.green[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      })),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _summaryRow(String label, double amount, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          formatVnd(amount),
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
