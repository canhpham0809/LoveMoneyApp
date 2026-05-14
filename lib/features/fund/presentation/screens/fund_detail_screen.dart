import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_app_demo/core/theme/app_colors.dart';

import 'package:flutter_app_demo/core/utils/amount_input.dart';
import 'package:flutter_app_demo/core/widgets/amount_suggestion_chips.dart';
import 'package:flutter_app_demo/core/widgets/busy_overlay.dart';
import 'package:flutter_app_demo/core/utils/formatters.dart';
import 'package:flutter_app_demo/features/fund/data/models/fund_contribution_model.dart';
import 'package:flutter_app_demo/features/fund/data/models/fund_model.dart';
import 'package:flutter_app_demo/features/fund/data/services/fund_service.dart';
import 'package:flutter_app_demo/features/wallet/data/services/wallet_service.dart';

class FundDetailScreen extends StatefulWidget {
  final String coupleId;
  final String fundId;

  const FundDetailScreen({
    super.key,
    required this.coupleId,
    required this.fundId,
  });

  @override
  State<FundDetailScreen> createState() => _FundDetailScreenState();
}

class _FundDetailScreenState extends State<FundDetailScreen> {
  final _fundService = FundService();
  final _walletService = WalletService();

  FundModel? _fund;
  List<FundContributionModel> _contributions = [];
  Map<String, String> _memberNameById = {};
  bool _isLoading = true;
  bool _isMutating = false;

  Future<T> _runMutation<T>(Future<T> Function() action) async {
    if (mounted) {
      setState(() => _isMutating = true);
    }
    try {
      return await action();
    } finally {
      if (mounted) {
        setState(() => _isMutating = false);
      }
    }
  }

  String _normalizeUserId(String userId) => userId.trim().toLowerCase();

  String _resolveMemberName(String userId) {
    final name = _memberNameById[_normalizeUserId(userId)]?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Thành viên';
  }

  Future<Map<String, String>> _loadMemberNamesByIds(Set<String> userIds) async {
    if (userIds.isEmpty) return {};
    final users = List<Map<String, dynamic>>.from(
      await Supabase.instance.client
          .from('users')
          .select('id, display_name, email')
          .inFilter('id', userIds.toList()),
    );
    return {
      for (final u in users)
        _normalizeUserId(
          u['id'] as String,
        ): ((u['display_name'] as String?)?.trim().isNotEmpty == true
            ? (u['display_name'] as String).trim()
            : ((u['email'] as String?) ?? 'Thành viên')),
    };
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showLoader = true}) async {
    if (showLoader) {
      setState(() => _isLoading = true);
    }
    try {
      final fund = await _fundService.getFundById(widget.fundId);
      final contributions = await _fundService.getContributionsByFund(
        coupleId: widget.coupleId,
        fundId: widget.fundId,
      );
      final memberIds = <String>{
        if (fund.creatorUserId != null) fund.creatorUserId!,
        ...contributions.map((c) => c.userId),
      };
      final memberNameById = await _loadMemberNamesByIds(memberIds);

      if (!mounted) return;
      setState(() {
        _fund = fund;
        _contributions = contributions;
        _memberNameById = memberNameById;
      });
    } finally {
      if (showLoader && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openContributionPopup({
    FundContributionModel? existing,
    bool isWithdrawal = false,
  }) async {
    final walletList = await _walletService.getWallets(widget.coupleId);
    if (!mounted) return;
    if (walletList.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Chưa có ví để góp quỹ.')));
      return;
    }

    walletList.sort((a, b) {
      if (a.isDefault == b.isDefault) return 0;
      return a.isDefault ? -1 : 1;
    });
    final walletId = walletList.first.id;

    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    DateTime selectedDate = existing?.date ?? DateTime.now();
    var isClosingDialog = false;
    var isSubmitting = false;
    if (existing != null) {
      amountCtrl.text = formatAmountInput(existing.amount.toStringAsFixed(0));
      noteCtrl.text = existing.note ?? '';
    }

    final isWithdrawalTx =
        isWithdrawal || existing?.contributionType == 'withdrawal';

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final media = MediaQuery.of(dialogContext).size;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 20,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 520,
                maxHeight: media.height * 0.8,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        existing == null
                            ? (isWithdrawalTx ? 'Rút quỹ' : 'Góp quỹ')
                            : (isWithdrawalTx ? 'Sửa đợt rút' : 'Sửa đợt góp'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          ThousandsSeparatorInputFormatter(),
                        ],
                        decoration: const InputDecoration(hintText: 'Số tiền'),
                      ),
                      AmountSuggestionChips(
                        controller: amountCtrl,
                        onSelected: (value) {
                          amountCtrl.text = formatAmountInput(value.toString());
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: noteCtrl,
                        maxLines: 2,
                        minLines: 2,
                        decoration: const InputDecoration(hintText: 'Ghi chú'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedDate = picked);
                          }
                        },
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text('Ngày: ${formatDate(selectedDate)}'),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                if (isClosingDialog || isSubmitting) return;
                                isClosingDialog = true;
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (!dialogContext.mounted) return;
                                  Navigator.of(dialogContext).maybePop(false);
                                });
                              },
                              child: const Text('Hủy'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: () async {
                                if (isClosingDialog || isSubmitting) return;
                                final amount = parseAmountInput(
                                  amountCtrl.text.trim(),
                                );
                                if (amount == null || amount <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Số tiền không hợp lệ.'),
                                    ),
                                  );
                                  return;
                                }
                                setDialogState(() => isSubmitting = true);
                                try {
                                  if (existing == null) {
                                    final uid = Supabase
                                        .instance
                                        .client
                                        .auth
                                        .currentUser!
                                        .id;
                                    if (isWithdrawalTx) {
                                      await _fundService.createWithdrawal(
                                        coupleId: widget.coupleId,
                                        userId: uid,
                                        fundId: widget.fundId,
                                        walletId: walletId,
                                        amount: amount,
                                        note: noteCtrl.text.trim().isEmpty
                                            ? null
                                            : noteCtrl.text.trim(),
                                        date: selectedDate,
                                      );
                                    } else {
                                      await _fundService.createContribution(
                                        coupleId: widget.coupleId,
                                        userId: uid,
                                        fundId: widget.fundId,
                                        walletId: walletId,
                                        amount: amount,
                                        note: noteCtrl.text.trim().isEmpty
                                            ? null
                                            : noteCtrl.text.trim(),
                                        date: selectedDate,
                                      );
                                    }
                                  } else {
                                    await _fundService.updateContribution(
                                      contributionId: existing.id,
                                      fundId: widget.fundId,
                                      amount: amount,
                                      note: noteCtrl.text.trim().isEmpty
                                          ? null
                                          : noteCtrl.text.trim(),
                                      date: selectedDate,
                                    );
                                  }
                                } finally {
                                  if (dialogContext.mounted) {
                                    setDialogState(() => isSubmitting = false);
                                  }
                                }
                                isClosingDialog = true;
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (!dialogContext.mounted) return;
                                  Navigator.of(dialogContext).maybePop(true);
                                });
                              },
                              child: isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Lưu'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (saved == true) {
      await _load(showLoader: false);
    }
  }

  Future<void> _showContributionActions(FundContributionModel item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () => Navigator.pop(sheetContext, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete'),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'edit') {
      await _openContributionPopup(
        existing: item,
        isWithdrawal: item.contributionType == 'withdrawal',
      );
      return;
    }
    if (action == 'delete') {
      final impact = await _fundService.previewDeleteContributionImpact(
        item.id,
      );
      if (!mounted) return;
      String message;
      if (impact < 0) {
        message =
            'Nếu xác nhận xóa giao dịch này, số dư ví sẽ bị trừ lại ${formatVnd(impact.abs())}. Hệ thống đồng thời hủy giao dịch thu nhập liên kết.';
      } else if (impact > 0) {
        message =
            'Nếu xác nhận xóa giao dịch này, bạn sẽ được cộng thêm ${formatVnd(impact)}.';
      } else {
        message =
            'Nếu xác nhận xóa giao dịch này, hệ thống không phát sinh giao dịch bù trừ mới.';
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Xác nhận xóa giao dịch quỹ'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Xóa'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      await _runMutation(() async {
        await _fundService.deleteContribution(
          contributionId: item.id,
          fundId: widget.fundId,
        );
        await _load(showLoader: false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fund = _fund;
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết Quỹ')),
      body: BusyOverlay(
        isVisible: _isMutating,
        message: 'Đang xử lý...',
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : fund == null
            ? const Center(child: Text('Không tìm thấy quỹ.'))
            : Column(
                children: [
                  Builder(
                    builder: (context) {
                      final target = fund.targetAmount;
                      final hasTarget = target != null && target > 0;
                      final progress = hasTarget
                          ? (fund.currentAmount / target).clamp(0.0, 1.0)
                          : 1.0;
                      final remaining = hasTarget
                          ? (target - fund.currentAmount).clamp(0.0, target)
                          : 0.0;

                      return Container(
                        margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    height: 50,
                                    width: 50,
                                    decoration: BoxDecoration(
                                      color: AppColors.tealSoft,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.savings_outlined,
                                      color: AppColors.tealDeep,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      fund.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    formatVnd(fund.currentAmount),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: AppColors.tealDeep,
                                    ),
                                  ),
                                ],
                              ),
                              if (hasTarget) ...[
                                const SizedBox(height: 14),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 8,
                                    backgroundColor: AppColors.tealSoft,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          AppColors.tealDeep,
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tiến độ: ${(progress * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.tealDeep,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (hasTarget)
                                Text(
                                  'Mục tiêu: ${formatVnd(target)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              if (hasTarget) const SizedBox(height: 4),
                              Text(
                                hasTarget
                                    ? 'Còn lại: ${formatVnd(remaining)}'
                                    : 'Còn lại: Không có mục tiêu',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                fund.deadline != null
                                    ? 'Hạn: ${formatDate(fund.deadline!)}'
                                    : 'Hạn: Không có',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                              if (fund.creatorUserId != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Người tạo: ${_resolveMemberName(fund.creatorUserId!)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Lịch sử giao dịch góp/rút quỹ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _contributions.isEmpty
                        ? const Center(child: Text('Chưa có đợt góp nào.'))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                            itemCount: _contributions.length,
                            itemBuilder: (context, index) {
                              final c = _contributions[index];
                              final isWithdrawal =
                                  c.contributionType == 'withdrawal';
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  minVerticalPadding: 6,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  leading: CircleAvatar(
                                    radius: 22,
                                    backgroundColor: isWithdrawal
                                        ? AppColors.successSoft
                                        : Colors.orange.withValues(alpha: 0.12),
                                    child: Icon(
                                      isWithdrawal
                                          ? Icons.south_west_rounded
                                          : Icons.north_east_rounded,
                                      color: isWithdrawal
                                          ? AppColors.success
                                          : Colors.orange,
                                      size: 20,
                                    ),
                                  ),
                                  onLongPress: () =>
                                      _showContributionActions(c),
                                  title: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isWithdrawal ? 'Rút quỹ' : 'Góp quỹ',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${formatDate(c.date)} ${formatTimeUtcPlus7(c.updatedAt)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Người tạo: ${_resolveMemberName(c.updatedBy ?? c.userId)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Ghi chú: ${c.note?.trim().isNotEmpty == true ? c.note!.trim() : 'Không có'}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        isWithdrawal
                                            ? '-${formatVnd(c.amount)}'
                                            : '+${formatVnd(c.amount)}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isWithdrawal
                                              ? Colors.orange
                                              : AppColors.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'fund_withdraw',
            onPressed: () => _openContributionPopup(isWithdrawal: true),
            child: const Icon(Icons.south_west_rounded),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'fund_contribute',
            onPressed: _openContributionPopup,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
