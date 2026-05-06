import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/transaction_service.dart';
import '../../../../core/models/monthly_summary.dart';
import '../../../../core/models/transaction.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/busy_overlay.dart';
import '../../../income/data/services/income_service.dart';
import 'monthly_operations_dashboard_screen.dart';
import '../../../home/widgets/monthly_card.dart';
import '../../../home/widgets/transaction_list.dart';

class DashboardScreen extends StatefulWidget {
  final String coupleId;
  final String viewerUserId;
  final String currentUserId;
  final String viewerLabel;
  final String? partnerUserId;
  final String? selfLabel;
  final String? partnerLabel;
  final VoidCallback? onToggleViewer;
  final ValueListenable<int>? refreshSignal;
  final Future<void> Function()? onCreatePressed;
  final VoidCallback? onDataChanged;

  const DashboardScreen({
    super.key,
    required this.coupleId,
    required this.viewerUserId,
    required this.currentUserId,
    required this.viewerLabel,
    this.partnerUserId,
    this.selfLabel,
    this.partnerLabel,
    this.onToggleViewer,
    this.refreshSignal,
    this.onCreatePressed,
    this.onDataChanged,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _transactionService = TransactionService();
  final _incomeService = IncomeService();
  final PageController _monthPageController = PageController(
    viewportFraction: 0.85,
  );
  List<MonthlySummary> _monthlySummaries = [];
  int _selectedMonthIndex = 0;
  List<Transaction> _recentTransactions = [];
  bool _isLoading = true;
  bool _isRefreshingContent = false;
  String _refreshMessage = 'Đang tải dữ liệu...';
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
      _load(showLoader: false, overlayMessage: 'Đang chuyển view...');
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
    _load(showLoader: false, overlayMessage: 'Đang tải dữ liệu...');
  }

  Future<void> _load({required bool showLoader, String? overlayMessage}) async {
    if (showLoader) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else {
      if (mounted) {
        setState(() {
          _error = null;
          _isRefreshingContent = true;
          _refreshMessage = overlayMessage ?? 'Đang tải dữ liệu...';
        });
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
      if (mounted) {
        setState(() {
          if (showLoader) {
            _isLoading = false;
          } else {
            _isRefreshingContent = false;
          }
        });
      }
    }
  }

  Future<void> _loadRecentTransactions({String? overlayMessage}) async {
    if (_monthlySummaries.isEmpty) {
      if (!mounted) return;
      setState(() {
        _recentTransactions = const [];
      });
      return;
    }
    if (mounted) {
      setState(() {
        _isRefreshingContent = true;
        _refreshMessage = overlayMessage ?? 'Đang tải giao dịch...';
      });
    }
    final summary = _monthlySummaries[_selectedMonthIndex];
    try {
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
    } finally {
      if (mounted) {
        setState(() => _isRefreshingContent = false);
      }
    }
  }

  void _onMonthChanged(int index) async {
    setState(() {
      _selectedMonthIndex = index;
    });
    await _loadRecentTransactions(
      overlayMessage: 'Đang tải giao dịch tháng...',
    );
  }

  Future<void> _openMonthlyDashboard(MonthlySummary summary) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MonthlyOperationsDashboardScreen(
          coupleId: widget.coupleId,
          viewerUserId: widget.viewerUserId,
          viewerLabel: widget.viewerLabel,
          currentUserId: widget.currentUserId,
          partnerUserId: widget.partnerUserId,
          selfLabel: widget.selfLabel,
          partnerLabel: widget.partnerLabel,
          onToggleViewer: widget.onToggleViewer,
          year: summary.year,
          month: summary.month,
        ),
      ),
    );
  }

  Future<void> _showSwitchBackToSelfAlert() async {
    final viewingLabel = widget.viewerLabel;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Không thể thao tác khi đang xem $viewingLabel'),
        content: Text(
          'Bạn đang ở view $viewingLabel. Vui lòng quay về view của tài khoản đăng nhập để thực hiện chuyển dư tháng.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).maybePop(),
            child: const Text('Đóng'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).maybePop();
              widget.onToggleViewer?.call();
            },
            child: const Text('Chuyển về tôi'),
          ),
        ],
      ),
    );
  }

  Future<String?> _resolveDefaultWalletId() async {
    final rows = await Supabase.instance.client
        .from('wallets')
        .select('id')
        .eq('couple_id', widget.coupleId)
        .eq('is_deleted', false)
        .eq('is_active', true)
        .order('is_default', ascending: false)
        .order('created_at', ascending: true)
        .limit(1);

    if (rows.isEmpty) return null;
    return rows.first['id'] as String;
  }

  Future<String> _resolveOrCreateCarryOverIncomeSourceId() async {
    const carryOverName = 'Dư tháng trước';
    final rows = await Supabase.instance.client
        .from('income_sources')
        .select('id, name')
        .eq('couple_id', widget.coupleId)
        .eq('is_deleted', false)
        .eq('name', carryOverName)
        .limit(1);

    if (rows.isNotEmpty) {
      return rows.first['id'] as String;
    }

    final created = await _incomeService.createIncomeSource(
      coupleId: widget.coupleId,
      name: carryOverName,
      icon: 'restart_alt',
      type: 'other',
      showInIncomeForm: true,
    );
    return created.id;
  }

  Future<void> _onCarryOverPressed(MonthlySummary summary) async {
    if (widget.viewerUserId != widget.currentUserId) {
      await _showSwitchBackToSelfAlert();
      return;
    }

    final carryAmount = summary.balance;
    if (carryAmount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tháng này không có dư để chuyển.')),
      );
      return;
    }

    final nextMonthDate = DateTime(summary.year, summary.month + 1, 1);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Chuyển dư sang tháng sau'),
        content: Text(
          'Bạn có muốn chuyển ${formatVnd(carryAmount)} sang tháng ${nextMonthDate.month.toString().padLeft(2, '0')}/${nextMonthDate.year} không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).maybePop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).maybePop(true),
            child: const Text('Đồng ý'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không xác định được người dùng hiện tại.'),
        ),
      );
      return;
    }

    try {
      final walletId = await _resolveDefaultWalletId();
      if (walletId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chưa có ví mặc định để ghi nhận Thu.')),
        );
        return;
      }

      final incomeSourceId = await _resolveOrCreateCarryOverIncomeSourceId();
      await _incomeService.createIncome(
        coupleId: widget.coupleId,
        userId: userId,
        walletId: walletId,
        incomeSourceId: incomeSourceId,
        amount: carryAmount,
        description:
            'Dư tháng ${summary.month.toString().padLeft(2, '0')}/${summary.year}',
        date: nextMonthDate,
      );

      widget.onDataChanged?.call();
      await _load(showLoader: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không chuyển được dư tháng: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedSummary = _monthlySummaries.isEmpty
        ? null
        : _monthlySummaries[_selectedMonthIndex];
    final titleText = selectedSummary == null
        ? 'Dashboard'
        : 'Dashboard ${selectedSummary.month.toString().padLeft(2, '0')}/${selectedSummary.year}';

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText),
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
      body: BusyOverlay(
        isVisible: _isRefreshingContent,
        message: _refreshMessage,
        child: _isLoading
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
                    12,
                    16,
                    widget.onCreatePressed == null ? 16 : 96,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.tealSoft.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Đang xem: ${widget.viewerLabel}',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: AppColors.tealDeep,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Monthly swipeable summary cards
                      if (_monthlySummaries.isNotEmpty)
                        SizedBox(
                          height: 172,
                          child: PageView.builder(
                            controller: _monthPageController,
                            itemCount: _monthlySummaries.length,
                            onPageChanged: _onMonthChanged,
                            itemBuilder: (context, idx) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              child: MonthlyCard(
                                summary: _monthlySummaries[idx],
                                isSelected: idx == _selectedMonthIndex,
                                onTap: () async {
                                  await _openMonthlyDashboard(
                                    _monthlySummaries[idx],
                                  );
                                },
                                onCarryOverPressed: () async {
                                  await _onCarryOverPressed(
                                    _monthlySummaries[idx],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            '20 giao dịch gần nhất',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.tune_rounded,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ],
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
      ),
      floatingActionButton: widget.onCreatePressed == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () async => widget.onCreatePressed!.call(),
              label: const Text('Add'),
            ),
    );
  }
}
