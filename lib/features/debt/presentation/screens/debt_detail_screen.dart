import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_app_demo/core/theme/app_colors.dart';
import 'package:flutter_app_demo/core/utils/amount_input.dart';
import 'package:flutter_app_demo/core/widgets/amount_suggestion_chips.dart';
import 'package:flutter_app_demo/core/widgets/busy_overlay.dart';
import 'package:flutter_app_demo/core/utils/formatters.dart';
import 'package:flutter_app_demo/features/debt/data/models/debt_model.dart';
import 'package:flutter_app_demo/features/debt/data/models/debt_payment_model.dart';
import 'package:flutter_app_demo/features/debt/data/services/debt_service.dart';
import 'package:flutter_app_demo/features/wallet/data/services/wallet_service.dart';

class DebtDetailScreen extends StatefulWidget {
  final String coupleId;
  final String debtId;

  const DebtDetailScreen({
    super.key,
    required this.coupleId,
    required this.debtId,
  });

  @override
  State<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends State<DebtDetailScreen> {
  final _debtService = DebtService();
  final _walletService = WalletService();

  DebtModel? _debt;
  List<DebtPaymentModel> _payments = [];
  Map<String, String> _memberNameById = {};
  String? _defaultWalletId;
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
      final debt = await _debtService.getDebtById(widget.debtId);
      final payments = await _debtService.getPaymentsByDebt(
        coupleId: widget.coupleId,
        debtId: widget.debtId,
      );
      final memberIds = <String>{
        debt.userId,
        ...payments.map((p) => p.updatedBy).whereType<String>(),
      };
      final memberNameById = await _loadMemberNamesByIds(memberIds);

      final wallets = await _walletService.getWallets(widget.coupleId);
      String? defaultWalletId;
      if (wallets.isNotEmpty) {
        wallets.sort((a, b) {
          if (a.isDefault == b.isDefault) return 0;
          return a.isDefault ? -1 : 1;
        });
        defaultWalletId = wallets.first.id;
      }

      if (!mounted) return;
      setState(() {
        _debt = debt;
        _payments = payments;
        _memberNameById = memberNameById;
        _defaultWalletId = defaultWalletId;
      });
    } finally {
      if (showLoader && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openPaymentPopup({DebtPaymentModel? existing}) async {
    final wallets = await _walletService.getWallets(widget.coupleId);
    if (!mounted) return;
    if (wallets.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Chưa có ví để trả nợ.')));
      return;
    }

    wallets.sort((a, b) {
      if (a.isDefault == b.isDefault) return 0;
      return a.isDefault ? -1 : 1;
    });
    final walletId = wallets.first.id;

    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    DateTime selectedDate = existing?.date ?? DateTime.now();
    var isSubmitting = false;
    if (existing != null) {
      amountCtrl.text = formatAmountInput(existing.amount.toStringAsFixed(0));
      noteCtrl.text = existing.note ?? '';
    }

    final saved = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, anim1, anim2) {
        final isLend = _debt?.debtKind == 'lend';
        final media = MediaQuery.sizeOf(dialogContext);
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => Dialog(
            alignment: Alignment.center,
            insetAnimationDuration: Duration.zero,
            insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 520,
                maxHeight: media.height * 0.8,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      existing == null
                          ? (isLend ? 'Thu hồi nợ' : 'Trả nợ')
                          : (isLend ? 'Sửa đợt thu hồi' : 'Sửa đợt trả nợ'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
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
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.pop(dialogContext, false),
                            child: const Text('Hủy'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              if (isSubmitting) return;
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
                                  await _debtService.createPayment(
                                    coupleId: widget.coupleId,
                                    debtId: widget.debtId,
                                    walletId: walletId,
                                    amount: amount,
                                    date: selectedDate,
                                    note: noteCtrl.text.trim().isEmpty
                                        ? null
                                        : noteCtrl.text.trim(),
                                  );
                                } else {
                                  await _debtService.updatePayment(
                                    paymentId: existing.id,
                                    debtId: widget.debtId,
                                    amount: amount,
                                    date: selectedDate,
                                    note: noteCtrl.text.trim().isEmpty
                                        ? null
                                        : noteCtrl.text.trim(),
                                  );
                                }
                              } finally {
                                if (dialogContext.mounted) {
                                  setDialogState(() => isSubmitting = false);
                                }
                              }
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext, true);
                              }
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
        );
      },
    );

    if (saved == true) {
      await _load(showLoader: false);
    }
  }

  Future<void> _showPaymentActions(DebtPaymentModel item) async {
    if (_debt?.isSplitBill == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vui lòng sử dụng danh sách check chọn ở trên để cập nhật trạng thái.',
          ),
        ),
      );
      return;
    }

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
      await _openPaymentPopup(existing: item);
      return;
    }
    if (action == 'delete') {
      final impact = await _debtService.previewDeletePaymentImpact(item.id);
      if (!mounted) return;
      String message;
      if (impact < 0) {
        message =
            'Nếu xác nhận xóa đợt này, số dư ví sẽ bị trừ lại ${formatVnd(impact.abs())}. Hệ thống đồng thời hủy giao dịch thu nhập liên kết.';
      } else if (impact > 0) {
        message =
            'Nếu xác nhận xóa đợt này, bạn sẽ được cộng thêm ${formatVnd(impact)}.';
      } else {
        message =
            'Nếu xác nhận xóa đợt này, hệ thống không phát sinh giao dịch bù trừ mới.';
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Xác nhận xóa đợt giao dịch nợ'),
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

      try {
        await _runMutation(() async {
          await _debtService.deletePayment(
            paymentId: item.id,
            debtId: widget.debtId,
          );
          await _load(showLoader: false);
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi xóa: $e')));
      }
    }
  }

  Future<void> _toggleSharePaidStatus(
    DebtModel debt,
    SplitBillInfo info,
    int index,
    bool paid,
  ) async {
    final defaultWalletId = _defaultWalletId;
    if (defaultWalletId == null && paid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có ví mặc định để nhận tiền.')),
      );
      return;
    }

    try {
      await _runMutation(() async {
        final share = info.shares[index];
        String? paymentId = share.paymentId;

        if (paid) {
          final createdPayment = await _debtService.createPayment(
            coupleId: widget.coupleId,
            debtId: widget.debtId,
            walletId: defaultWalletId!,
            amount: info.shareAmount,
            date: DateTime.now(),
            note: '${share.name} trả tiền ${debt.name}',
          );
          paymentId = createdPayment.id;
        } else {
          if (paymentId != null) {
            await _debtService.deletePayment(
              paymentId: paymentId,
              debtId: widget.debtId,
            );
            paymentId = null;
          }
        }

        final updatedShares = List<SplitShare>.from(info.shares);
        updatedShares[index] = SplitShare(
          name: share.name,
          paid: paid,
          paymentId: paymentId,
        );

        final updatedInfo = SplitBillInfo(
          totalBill: info.totalBill,
          peopleCount: info.peopleCount,
          shareAmount: info.shareAmount,
          userNote: info.userNote,
          shares: updatedShares,
        );

        final noteString = jsonEncode(updatedInfo.toJson());

        await _debtService.updateSplitBillNote(
          debtId: widget.debtId,
          note: noteString,
        );

        await _load(showLoader: false);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi cập nhật trạng thái: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final debt = _debt;
    final isLend = debt?.debtKind == 'lend';
    return Scaffold(
      appBar: AppBar(title: Text(isLend ? 'Chi tiết Cho mượn' : 'Chi tiết Nợ')),
      body: BusyOverlay(
        isVisible: _isMutating,
        message: 'Đang xử lý ...',
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : debt == null
            ? const Center(child: Text('Không tìm thấy khoản nợ.'))
            : Column(
                children: [
                  Builder(
                    builder: (context) {
                      final pct = debt.originalAmount > 0
                          ? 1 - (debt.remainingAmount / debt.originalAmount)
                          : 1.0;
                      final clampedPct = pct.clamp(0.0, 1.0);
                      final paidAmount =
                          (debt.originalAmount - debt.remainingAmount).clamp(
                            0.0,
                            debt.originalAmount,
                          );
                      final accentColor = debt.isClosed
                          ? AppColors.success
                          : (isLend ? AppColors.tealDeep : AppColors.danger);
                      final accentSoft = debt.isClosed
                          ? AppColors.successSoft
                          : (isLend
                                ? AppColors.tealSoft
                                : AppColors.dangerSoft);
                      final leadingIcon = debt.isClosed
                          ? Icons.check_circle_outline
                          : (isLend
                                ? Icons.account_balance_wallet_outlined
                                : Icons.credit_card_outlined);

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
                                      color: accentSoft,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      leadingIcon,
                                      color: accentColor,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      debt.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    formatVnd(debt.originalAmount),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: accentColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: clampedPct,
                                  minHeight: 8,
                                  backgroundColor: accentSoft,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    accentColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Tiến độ: ${(clampedPct * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: accentColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Đã đóng: ${formatVnd(paidAmount)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Còn lại: ${formatVnd(debt.remainingAmount)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                debt.dueDate != null
                                    ? 'Hạn: ${formatDate(debt.dueDate!)}'
                                    : 'Hạn: Không có',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Người tạo: ${_resolveMemberName(debt.userId)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Ghi chú: ${debt.isSplitBill ? (debt.splitBillInfo?.userNote ?? 'Không có') : (debt.note?.trim().isNotEmpty == true ? debt.note!.trim() : 'Không có')}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  if (debt.isSplitBill) ...[
                    Container(
                      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                      padding: const EdgeInsets.all(14),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Chi tiết chia tiền',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Builder(
                            builder: (context) {
                              final info = debt.splitBillInfo!;
                              return Column(
                                children: List.generate(info.shares.length, (i) {
                                  final share = info.shares[i];
                                  return CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    title: Text(
                                      '${share.name} (${formatVnd(info.shareAmount)})',
                                      style: TextStyle(
                                        decoration: share.paid
                                            ? TextDecoration.lineThrough
                                            : null,
                                        color: share.paid
                                            ? Colors.black45
                                            : Colors.black87,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    value: share.paid,
                                    onChanged: (val) {
                                      if (val != null) {
                                        _toggleSharePaidStatus(debt, info, i, val);
                                      }
                                    },
                                  );
                                }),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        isLend ? 'Lịch sử trả nợ' : 'Lịch sử trả nợ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _payments.isEmpty
                        ? Center(
                            child: Text(
                              isLend
                                  ? 'Chưa có đợt thu hồi nào.'
                                  : 'Chưa có đợt trả nợ nào.',
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                            itemCount: _payments.length,
                            itemBuilder: (context, index) {
                              final p = _payments[index];
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
                                    backgroundColor: AppColors.successSoft,
                                    child: const Icon(
                                      Icons.timeline,
                                      color: AppColors.success,
                                      size: 20,
                                    ),
                                  ),
                                  onTap: () => _showPaymentActions(p),
                                  title: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Trả nợ',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${formatDate(p.date)} ${formatTimeUtcPlus7(p.updatedAt)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Người tạo: ${p.updatedBy != null ? _resolveMemberName(p.updatedBy!) : 'Không rõ'}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Ghi chú: ${p.note?.trim().isNotEmpty == true ? p.note!.trim() : 'Không có'}',
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
                                        '+${formatVnd(p.amount)}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.success,
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
      floatingActionButton: (debt?.isSplitBill == true)
          ? null
          : FloatingActionButton(
              onPressed: _openPaymentPopup,
              child: const Icon(Icons.add),
            ),
    );
  }
}
