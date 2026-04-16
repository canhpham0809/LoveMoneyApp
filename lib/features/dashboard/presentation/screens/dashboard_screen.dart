import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_app_demo/core/utils/formatters.dart';
import 'package:flutter_app_demo/features/dashboard/data/services/dashboard_service.dart';

class DashboardScreen extends StatefulWidget {
  final String coupleId;
  final ValueListenable<int>? refreshSignal;
  final Future<void> Function()? onCreatePressed;

  const DashboardScreen({
    super.key,
    required this.coupleId,
    this.refreshSignal,
    this.onCreatePressed,
  });

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
    widget.refreshSignal?.addListener(_onExternalRefresh);
    _load(showLoader: true);
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      oldWidget.refreshSignal?.removeListener(_onExternalRefresh);
      widget.refreshSignal?.addListener(_onExternalRefresh);
    }
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_onExternalRefresh);
    super.dispose();
  }

  void _onExternalRefresh() {
    if (!mounted) return;
    _load(showLoader: false);
  }

  Future<void> _load({required bool showLoader}) async {
    if (showLoader) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else {
      if (mounted) {
        setState(() => _error = null);
      }
    }
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
      if (showLoader && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            onPressed: () => _load(showLoader: false),
            icon: const Icon(Icons.refresh),
          ),
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
                  FilledButton(
                    onPressed: () => _load(showLoader: true),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () => _load(showLoader: false),
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
                      '20 giao dịch gần nhất',
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
                        final isTransfer = tx['type'] == 'transfer';
                        final amount = (tx['amount'] as num?)?.toDouble() ?? 0;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isTransfer
                                ? Colors.blueGrey[50]
                                : isExpense
                                ? Colors.red[50]
                                : Colors.green[50],
                            child: Icon(
                              isTransfer
                                  ? Icons.swap_horiz
                                  : isExpense
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              color: isTransfer
                                  ? Colors.blueGrey
                                  : isExpense
                                  ? Colors.red
                                  : Colors.green,
                              size: 16,
                            ),
                          ),
                          title: Text(
                            isTransfer
                                ? ((tx['note'] as String?) ?? 'Chuyen tien')
                                : (() {
                                    final description = tx['description'] as String?;
                                    final categoryName =
                                        tx['resolved_category_name'] as String?;
                                    if (description != null && description.trim().isNotEmpty) {
                                      return description;
                                    }
                                    if (isExpense &&
                                        categoryName != null &&
                                        categoryName.trim().isNotEmpty) {
                                      return categoryName;
                                    }
                                    return isExpense ? 'Chi tiêu' : 'Thu nhập';
                                  }()),
                          ),
                          subtitle: Text(() {
                            final dateText = tx['date'] as String? ?? '';
                            final createdAtRaw = tx['created_at'] as String?;
                            final createdAt = createdAtRaw == null
                                ? null
                                : DateTime.tryParse(createdAtRaw);
                            if (createdAt == null) {
                              return dateText;
                            }
                            return '$dateText · ${formatDateTime(createdAt).split(' ').last}';
                          }()),
                          trailing: Text(
                            '${isTransfer ? '↔ ' : (isExpense ? '-' : '+')}${formatVnd(amount)}',
                            style: TextStyle(
                              color: isTransfer
                                  ? Colors.blueGrey
                                  : isExpense
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
      floatingActionButton: widget.onCreatePressed == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () async => widget.onCreatePressed!.call(),
              icon: const Icon(Icons.flash_on_outlined),
              label: const Text('Quick Add'),
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
