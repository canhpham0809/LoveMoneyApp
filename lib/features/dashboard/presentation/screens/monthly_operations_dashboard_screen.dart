import 'package:flutter/material.dart';

import 'package:flutter_app_demo/core/theme/app_colors.dart';
import 'package:flutter_app_demo/core/utils/category_visuals.dart';
import 'package:flutter_app_demo/core/utils/formatters.dart';
import 'package:flutter_app_demo/core/widgets/busy_overlay.dart';
import 'package:flutter_app_demo/features/dashboard/data/services/dashboard_service.dart';

class MonthlyOperationsDashboardScreen extends StatefulWidget {
  final String coupleId;
  final String viewerUserId;
  final String viewerLabel;
  final String currentUserId;
  final String? partnerUserId;
  final String? selfLabel;
  final String? partnerLabel;
  final VoidCallback? onToggleViewer;
  final int year;
  final int month;

  const MonthlyOperationsDashboardScreen({
    super.key,
    required this.coupleId,
    required this.viewerUserId,
    required this.viewerLabel,
    required this.currentUserId,
    this.partnerUserId,
    this.selfLabel,
    this.partnerLabel,
    this.onToggleViewer,
    required this.year,
    required this.month,
  });

  @override
  State<MonthlyOperationsDashboardScreen> createState() =>
      _MonthlyOperationsDashboardScreenState();
}

class _MonthlyOperationsDashboardScreenState
    extends State<MonthlyOperationsDashboardScreen> {
  final _service = DashboardService();

  late String _viewerUserId;
  late String _viewerLabel;

  bool _isLoading = true;
  bool _isRefreshingContent = false;
  String _refreshMessage = 'Đang tải dữ liệu...';
  String? _error;

  List<Map<String, dynamic>> _incomeBySource = const [];
  List<Map<String, dynamic>> _expenseByCategory = const [];
  List<Map<String, dynamic>> _fundContributionByItem = const [];
  List<Map<String, dynamic>> _debtBorrowedByItem = const [];
  List<Map<String, dynamic>> _debtLentByItem = const [];
  double _transferSent = 0;
  double _transferReceived = 0;
  double _totalIncome = 0;
  double _totalExpense = 0;
  double _totalFundWithdrawal = 0;
  double _totalFundContribution = 0;
  double _totalDebtBorrow = 0;
  double _totalDebtLend = 0;
  double _totalDebtPaymentMade = 0;
  double _totalDebtPaymentReceived = 0;

  @override
  void initState() {
    super.initState();
    _viewerUserId = widget.viewerUserId;
    _viewerLabel = widget.viewerLabel;
    _load(showLoader: true);
  }

  Future<void> _load({bool showLoader = false, String? overlayMessage}) async {
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
      final data = await _service.getMonthlyOperationsDashboard(
        coupleId: widget.coupleId,
        viewerUserId: _viewerUserId,
        year: widget.year,
        month: widget.month,
      );

      if (!mounted) return;
      final transfer = Map<String, dynamic>.from(
        data['transfer_summary'] as Map,
      );
      final totals = Map<String, dynamic>.from(data['totals'] as Map);

      setState(() {
        _incomeBySource = List<Map<String, dynamic>>.from(
          data['income_by_source'] as List,
        );
        _expenseByCategory = List<Map<String, dynamic>>.from(
          data['expense_by_category'] as List,
        );
        _fundContributionByItem = List<Map<String, dynamic>>.from(
          data['fund_contribution_by_item'] as List,
        );
        _debtBorrowedByItem = List<Map<String, dynamic>>.from(
          data['debt_borrowed_by_item'] as List,
        );
        _debtLentByItem = List<Map<String, dynamic>>.from(
          data['debt_lent_by_item'] as List,
        );

        _transferSent = (transfer['sent'] as num?)?.toDouble() ?? 0;
        _transferReceived = (transfer['received'] as num?)?.toDouble() ?? 0;
        _totalIncome = (totals['income'] as num?)?.toDouble() ?? 0;
        _totalExpense = (totals['expense'] as num?)?.toDouble() ?? 0;
        _totalFundWithdrawal =
            (totals['fund_withdrawal'] as num?)?.toDouble() ?? 0;
        _totalFundContribution =
            (totals['fund_contribution'] as num?)?.toDouble() ?? 0;
        _totalDebtBorrow = (totals['debt_borrow'] as num?)?.toDouble() ?? 0;
        _totalDebtLend = (totals['debt_lend'] as num?)?.toDouble() ?? 0;
        _totalDebtPaymentMade =
            (totals['debt_payment_made'] as num?)?.toDouble() ?? 0;
        _totalDebtPaymentReceived =
            (totals['debt_payment_received'] as num?)?.toDouble() ?? 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
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

  Future<void> _toggleViewerFromMonthlyDashboard() async {
    if (widget.partnerUserId == null) return;
    if (!mounted) return;
    final goingToPartner = _viewerUserId == widget.currentUserId;
    setState(() {
      _viewerUserId = goingToPartner
          ? widget.partnerUserId!
          : widget.currentUserId;
      _viewerLabel = goingToPartner
          ? (widget.partnerLabel ?? 'Người kia')
          : (widget.selfLabel ?? 'Tôi');
    });
    widget.onToggleViewer?.call();
    await _load(showLoader: false, overlayMessage: 'Đang chuyển view...');
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel =
        '${widget.month.toString().padLeft(2, '0')}/${widget.year}';

    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard $monthLabel'),
        actions: [
          if (widget.partnerUserId != null)
            IconButton(
              onPressed: _toggleViewerFromMonthlyDashboard,
              icon: Icon(
                _viewerUserId == widget.currentUserId
                    ? Icons.person
                    : Icons.people_alt_outlined,
              ),
              tooltip: 'Đang xem: $_viewerLabel. Chạm để đổi.',
            ),
          IconButton(
            onPressed: () =>
                _load(showLoader: false, overlayMessage: 'Đang tải dữ liệu...'),
            icon: const Icon(Icons.refresh),
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
                child: Padding(
                  padding: const EdgeInsets.all(20),
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
                ),
              )
            : RefreshIndicator(
                onRefresh: () => _load(
                  showLoader: false,
                  overlayMessage: 'Đang tải dữ liệu...',
                ),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.tealSoft.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Đang xem: $_viewerLabel',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: AppColors.tealDeep,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SummaryHeader(
                      totalIncome: _totalIncome,
                      totalExpense: _totalExpense,
                      totalFundWithdrawal: _totalFundWithdrawal,
                      totalFundContribution: _totalFundContribution,
                      transferSent: _transferSent,
                      transferReceived: _transferReceived,
                      totalDebtBorrow: _totalDebtBorrow,
                      totalDebtLend: _totalDebtLend,
                      totalDebtPaymentMade: _totalDebtPaymentMade,
                      totalDebtPaymentReceived: _totalDebtPaymentReceived,
                    ),
                    const SizedBox(height: 14),
                    _BreakdownSection(
                      title: 'Tổng Thu',
                      emptyText: 'Không có dữ liệu thu trong tháng.',
                      rows: _incomeBySource,
                      amountColor: Colors.green[700]!,
                    ),
                    const SizedBox(height: 12),
                    _BreakdownSection(
                      title: 'Tổng Chi',
                      emptyText: 'Không có dữ liệu chi trong tháng.',
                      rows: _expenseByCategory,
                      amountColor: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                    _BreakdownSection(
                      title: 'Tổng tiền góp Quỹ',
                      emptyText: 'Không có giao dịch góp quỹ trong tháng.',
                      rows: _fundContributionByItem,
                      amountColor: Colors.orange[700]!,
                    ),
                    const SizedBox(height: 12),
                    _TransferSection(
                      transferSent: _transferSent,
                      transferReceived: _transferReceived,
                    ),
                    const SizedBox(height: 12),
                    _BreakdownSection(
                      title: 'Tổng tiền Mượn Nợ',
                      emptyText: 'Không có khoản mượn nợ trong tháng.',
                      rows: _debtBorrowedByItem,
                      amountColor: Colors.blue[700]!,
                      defaultIcon: Icons.request_quote_outlined,
                    ),
                    const SizedBox(height: 12),
                    _BreakdownSection(
                      title: 'Tổng tiền Cho mượn',
                      emptyText: 'Không có khoản cho mượn trong tháng.',
                      rows: _debtLentByItem,
                      amountColor: Colors.deepPurple[700]!,
                      defaultIcon: Icons.account_balance_wallet_outlined,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final double totalIncome;
  final double totalExpense;
  final double totalFundWithdrawal;
  final double totalFundContribution;
  final double transferSent;
  final double transferReceived;
  final double totalDebtBorrow;
  final double totalDebtLend;
  final double totalDebtPaymentMade;
  final double totalDebtPaymentReceived;

  const _SummaryHeader({
    required this.totalIncome,
    required this.totalExpense,
    required this.totalFundWithdrawal,
    required this.totalFundContribution,
    required this.transferSent,
    required this.transferReceived,
    required this.totalDebtBorrow,
    required this.totalDebtLend,
    required this.totalDebtPaymentMade,
    required this.totalDebtPaymentReceived,
  });

  @override
  Widget build(BuildContext context) {
    final net =
        totalIncome +
        transferReceived +
        totalDebtBorrow +
        totalDebtPaymentReceived +
        totalFundWithdrawal -
        totalExpense -
        totalDebtLend -
        totalDebtPaymentMade -
        totalFundContribution -
        transferSent;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            // Row 1: Tổng Thu | Tổng Chi
            Row(
              children: [
                Expanded(
                  child: _miniTile(
                    'Tổng Thu',
                    totalIncome,
                    Colors.green[700]!,
                    Icons.south_west_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _miniTile(
                    'Tổng Chi',
                    totalExpense,
                    Colors.red[700]!,
                    Icons.north_east_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row 2: Nhận từ | Chuyển cho
            Row(
              children: [
                Expanded(
                  child: _miniTile(
                    'Nhận tiền',
                    transferReceived,
                    Colors.green[700]!,
                    Icons.arrow_downward,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _miniTile(
                    'Chuyển tiền',
                    transferSent,
                    Colors.red[700]!,
                    Icons.arrow_upward,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row 3: Mượn Nợ | Cho Mượn
            Row(
              children: [
                Expanded(
                  child: _miniTile(
                    'Mượn Nợ',
                    totalDebtBorrow,
                    Colors.blue[700]!,
                    Icons.request_quote_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _miniTile(
                    'Cho Mượn',
                    totalDebtLend,
                    Colors.deepPurple[700]!,
                    Icons.account_balance_wallet_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row 4: Được trả | Trả nợ
            Row(
              children: [
                Expanded(
                  child: _miniTile(
                    'Được trả',
                    totalDebtPaymentReceived,
                    Colors.teal[700]!,
                    Icons.move_to_inbox_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _miniTile(
                    'Trả nợ',
                    totalDebtPaymentMade,
                    Colors.orange[800]!,
                    Icons.outbox_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row 5: Rút Quỹ | Góp Quỹ
            Row(
              children: [
                Expanded(
                  child: _miniTile(
                    'Rút Quỹ',
                    totalFundWithdrawal,
                    Colors.lightBlue[700]!,
                    Icons.download_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _miniTile(
                    'Góp Quỹ',
                    totalFundContribution,
                    Colors.orange[700]!,
                    Icons.savings_outlined,
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            // Row 6: Còn lại
            Row(
              children: [
                Expanded(
                  child: _miniTile(
                    'Còn lại',
                    net,
                    net >= 0 ? Colors.blue[700]! : Colors.red[700]!,
                    Icons.account_balance_wallet_outlined,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniTile(String label, double value, Color color, IconData icon) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              formatVnd(value),
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownSection extends StatelessWidget {
  final String title;
  final String emptyText;
  final List<Map<String, dynamic>> rows;
  final Color amountColor;
  final IconData defaultIcon;

  const _BreakdownSection({
    required this.title,
    required this.emptyText,
    required this.rows,
    required this.amountColor,
    this.defaultIcon = Icons.label_outline,
  });

  @override
  Widget build(BuildContext context) {
    final total = rows.fold<double>(
      0,
      (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(emptyText),
              )
            else
              ...rows.map((row) {
                final amount = (row['amount'] as num?)?.toDouble() ?? 0;
                final percent = total > 0 ? amount / total : 0.0;
                final iconKey = row['icon_key'] as String?;
                final icon = iconKey == null || iconKey.trim().isEmpty
                    ? defaultIcon
                    : iconFromKey(iconKey);
                final subItems =
                    (row['sub_items'] as List?)?.cast<Map<String, dynamic>>() ??
                    const <Map<String, dynamic>>[];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: amountColor.withValues(
                              alpha: 0.15,
                            ),
                            child: Icon(icon, size: 16, color: amountColor),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              (row['name'] as String?) ?? 'Không rõ',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatVnd(amount),
                            style: TextStyle(
                              color: amountColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: percent,
                          minHeight: 7,
                          color: amountColor,
                          backgroundColor: Colors.grey.withValues(alpha: 0.18),
                        ),
                      ),
                      if (subItems.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        ...subItems.map((sub) {
                          final subType = (sub['type'] as String?) ?? '';
                          final subAmount =
                              (sub['amount'] as num?)?.toDouble() ?? 0;
                          final subDate = sub['date'] as String?;
                          final subDesc = sub['description'] as String?;
                          final isOutgoing =
                              subType == 'withdrawal' ||
                              subType == 'payment' ||
                              subType == 'record_expense';
                          final subColor = isOutgoing
                              ? Colors.red[700]!
                              : Colors.green[700]!;
                          final subLabel = subDesc?.isNotEmpty == true
                              ? subDesc!
                              : (isOutgoing
                                    ? (subType == 'withdrawal'
                                          ? 'Rút quỹ'
                                          : (subType == 'record_expense'
                                                ? 'Ghi vào Chi'
                                                : 'Trả nợ'))
                                    : (subType == 'receipt'
                                          ? 'Nhận lại'
                                          : (subType == 'record_income'
                                                ? 'Ghi vào Thu'
                                                : 'Góp quỹ')));
                          final dateStr =
                              subDate != null && subDate.length >= 10
                              ? subDate.substring(5, 10).replaceAll('-', '/')
                              : '';
                          return Padding(
                            padding: const EdgeInsets.only(left: 36, top: 3),
                            child: Row(
                              children: [
                                Icon(
                                  isOutgoing
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward,
                                  size: 12,
                                  color: subColor,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    subLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (dateStr.isNotEmpty)
                                  Text(
                                    dateStr,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                const SizedBox(width: 6),
                                Text(
                                  '${isOutgoing ? '-' : '+'} ${formatVnd(subAmount)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: subColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _TransferSection extends StatelessWidget {
  final double transferSent;
  final double transferReceived;

  const _TransferSection({
    required this.transferSent,
    required this.transferReceived,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tổng tiền đã Chuyển/Nhận',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _row(
              label: 'Tổng tiền đã chuyển',
              amount: transferSent,
              icon: Icons.north_east_rounded,
              color: Colors.red[700]!,
            ),
            const SizedBox(height: 8),
            _row(
              label: 'Tổng tiền đã nhận',
              amount: transferReceived,
              icon: Icons.south_west_rounded,
              color: Colors.green[700]!,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row({
    required String label,
    required double amount,
    required IconData icon,
    required Color color,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: color.withValues(alpha: 0.2),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(label)),
            Text(
              formatVnd(amount),
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
