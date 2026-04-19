import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/transaction_service.dart';
import '../../../../core/models/monthly_summary.dart';
import '../../../../core/models/transaction.dart';
import '../../../home/widgets/monthly_card.dart';
import '../../../home/widgets/transaction_list.dart';

class DashboardScreen extends StatefulWidget {
  final String coupleId;
  final String viewerUserId;
  final String currentUserId;
  final String viewerLabel;
  final String? partnerUserId;
  final VoidCallback? onToggleViewer;
  final ValueListenable<int>? refreshSignal;
  final Future<void> Function()? onCreatePressed;

  const DashboardScreen({
    super.key,
    required this.coupleId,
    required this.viewerUserId,
    required this.currentUserId,
    required this.viewerLabel,
    this.partnerUserId,
    this.onToggleViewer,
    this.refreshSignal,
    this.onCreatePressed,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _transactionService = TransactionService();
  final PageController _monthPageController = PageController(
    viewportFraction: 0.85,
  );
  List<MonthlySummary> _monthlySummaries = [];
  int _selectedMonthIndex = 0;
  List<Transaction> _recentTransactions = [];
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
    if (oldWidget.viewerUserId != widget.viewerUserId) {
      _load(showLoader: false);
    }
  }

  @override
  void dispose() {
    _monthPageController.dispose();
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
      final now = DateTime.now();
      final futures = await Future.wait<dynamic>([
        _transactionService.fetchMonthlySummaries(
          coupleId: widget.coupleId,
          viewerUserId: widget.viewerUserId,
        ),
        _transactionService.fetchRecentTransactions(
          coupleId: widget.coupleId,
          year: now.year,
          month: now.month,
          viewerUserId: widget.viewerUserId,
        ),
      ]);

      final summaries = List<MonthlySummary>.from(futures[0] as List);
      var recentTransactions = List<Transaction>.from(futures[1] as List);

      if (summaries.isNotEmpty) {
        final firstSummary = summaries.first;
        final isCurrentMonth =
            firstSummary.year == now.year && firstSummary.month == now.month;
        if (!isCurrentMonth) {
          recentTransactions = await _transactionService
              .fetchRecentTransactions(
                coupleId: widget.coupleId,
                year: firstSummary.year,
                month: firstSummary.month,
                viewerUserId: widget.viewerUserId,
              );
        }
      } else {
        recentTransactions = const <Transaction>[];
      }

      setState(() {
        _monthlySummaries = summaries;
        _selectedMonthIndex = 0;
        _recentTransactions = recentTransactions;
      });
      if (_monthPageController.hasClients) {
        _monthPageController.jumpToPage(0);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (showLoader && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadRecentTransactions() async {
    if (_monthlySummaries.isEmpty) {
      if (!mounted) return;
      setState(() {
        _recentTransactions = const [];
      });
      return;
    }
    final summary = _monthlySummaries[_selectedMonthIndex];
    final txs = await _transactionService.fetchRecentTransactions(
      coupleId: widget.coupleId,
      year: summary.year,
      month: summary.month,
      viewerUserId: widget.viewerUserId,
    );
    if (!mounted) return;
    setState(() {
      _recentTransactions = txs;
    });
  }

  void _onMonthChanged(int index) async {
    setState(() {
      _selectedMonthIndex = index;
    });
    await _loadRecentTransactions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          if (widget.partnerUserId != null)
            IconButton(
              onPressed: widget.onToggleViewer,
              icon: Icon(
                widget.viewerUserId == widget.currentUserId
                    ? Icons.person
                    : Icons.people_alt_outlined,
              ),
              tooltip: 'Đang xem: ${widget.viewerLabel}. Chạm để đổi.',
            ),
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
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  widget.onCreatePressed == null ? 16 : 96,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Đang xem: ${widget.viewerLabel}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    // Monthly swipeable summary cards
                    if (_monthlySummaries.isNotEmpty)
                      SizedBox(
                        height: 180,
                        child: PageView.builder(
                          controller: _monthPageController,
                          itemCount: _monthlySummaries.length,
                          onPageChanged: _onMonthChanged,
                          itemBuilder: (context, idx) => MonthlyCard(
                            summary: _monthlySummaries[idx],
                            isSelected: idx == _selectedMonthIndex,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    // Recent transactions (always current month)
                    const Text(
                      '20 giao dịch gần nhất',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TransactionList(
                      transactions: _recentTransactions,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                    ),
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
}
