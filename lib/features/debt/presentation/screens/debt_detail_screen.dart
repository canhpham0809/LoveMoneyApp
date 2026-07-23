import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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
  final ScrollController _scheduleScrollController = ScrollController();

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

  @override
  void dispose() {
    _scheduleScrollController.dispose();
    super.dispose();
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

      if (debt.isBankLoan && debt.bankLoanInfo != null) {
        final schedule = debt.bankLoanInfo!.schedule;
        final nextUnpaidIndex = schedule.indexWhere((item) => !item.isPaid);
        if (nextUnpaidIndex > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scheduleScrollController.hasClients) {
              // Subtract 16px padding so the card top is not cut off
              final targetOffset = (nextUnpaidIndex * 103.0) - 16.0;
              _scheduleScrollController.animateTo(
                targetOffset.clamp(0.0, _scheduleScrollController.position.maxScrollExtent),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
              );
            }
          });
        }
      }
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
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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

  void _onFabPressed(DebtModel debt) {
    final isLend = debt.debtKind == 'lend';
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(isLend ? Icons.call_received : Icons.call_made),
              title: Text(isLend ? 'Thu hồi nợ' : 'Trả bớt nợ'),
              onTap: () {
                Navigator.pop(sheetContext);
                _openPaymentPopup();
              },
            ),
            ListTile(
              leading: Icon(isLend ? Icons.add_circle_outline : Icons.remove_circle_outline),
              title: Text(isLend ? 'Cho mượn thêm' : 'Nợ thêm'),
              onTap: () {
                Navigator.pop(sheetContext);
                _openIncreaseDebtPopup();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openIncreaseDebtPopup({DebtHistoryItem? existing}) async {
    final wallets = await _walletService.getWallets(widget.coupleId);
    if (!mounted) return;
    if (wallets.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Chưa có ví.')));
      return;
    }

    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    DateTime selectedDate = existing?.date ?? DateTime.now();
    var recordTransaction = true;
    var isSubmitting = false;

    if (existing != null) {
      amountCtrl.text = formatAmountInput(existing.amount.toStringAsFixed(0));
      noteCtrl.text = existing.note ?? '';
      final isLend = _debt?.debtKind == 'lend';
      recordTransaction = isLend ? existing.linkedExpenseId != null : existing.linkedIncomeId != null;
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
                          ? (isLend ? 'Cho mượn thêm' : 'Nợ thêm')
                          : (isLend ? 'Sửa đợt cho mượn thêm' : 'Sửa đợt nợ thêm'),
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
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                            const SizedBox(height: 10),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                isLend
                                    ? 'Ghi nhận giao dịch Chi tiêu'
                                    : 'Ghi nhận giao dịch Thu nhập',
                                style: const TextStyle(fontSize: 14),
                              ),
                              subtitle: Text(
                                isLend
                                    ? 'Tiền mượn thêm sẽ tự động trừ vào ví mặc định'
                                    : 'Tiền nợ thêm sẽ tự động cộng vào ví mặc định',
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                              value: recordTransaction,
                              onChanged: (val) {
                                setDialogState(() => recordTransaction = val);
                              },
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
                                  await _debtService.increaseDebt(
                                    debtId: widget.debtId,
                                    incrementAmount: amount,
                                    date: selectedDate,
                                    recordTransaction: recordTransaction,
                                    note: noteCtrl.text.trim().isEmpty
                                        ? null
                                        : noteCtrl.text.trim(),
                                  );
                                } else {
                                  await _debtService.updateIncrement(
                                    debtId: widget.debtId,
                                    index: existing.index,
                                    newAmount: amount,
                                    date: selectedDate,
                                    note: noteCtrl.text.trim().isEmpty
                                        ? null
                                        : noteCtrl.text.trim(),
                                    recordTransaction: recordTransaction,
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

  Future<void> _showIncrementActions(DebtHistoryItem item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Sửa'),
              onTap: () => Navigator.pop(sheetContext, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Xóa'),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'edit') {
      await _openIncreaseDebtPopup(existing: item);
      return;
    }
    if (action != 'delete') return;

    final impact = await _debtService.previewDeleteIncrementImpact(
      linkedIncomeId: item.linkedIncomeId,
      linkedExpenseId: item.linkedExpenseId,
    );
    if (!mounted) return;

    String message;
    if (impact < 0) {
      message =
          'Nếu xác nhận xóa đợt này, số dư ví sẽ bị trừ lại ${formatVnd(impact.abs())}. Hệ thống đồng thời hủy giao dịch thu nhập liên kết.';
    } else if (impact > 0) {
      message =
          'Nếu xác nhận xóa đợt này, số dư ví sẽ được cộng lại ${formatVnd(impact)}. Giao dịch chi tiêu liên kết sẽ bị hủy.';
    } else {
      message =
          'Nếu xác nhận xóa đợt này, hệ thống không phát sinh giao dịch bù trừ mới (không có giao dịch liên kết).';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item.isIncrement
            ? (_debt?.debtKind == 'lend' ? 'Xóa đợt cho mượn thêm' : 'Xóa đợt nợ thêm')
            : 'Xóa đợt giao dịch nợ'),
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
        await _debtService.deleteIncrement(widget.debtId, item.index);
        await _load(showLoader: false);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi xóa: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final debt = _debt;
    final isLend = debt?.debtKind == 'lend';

    if (debt != null && debt.isBankLoan) {
      return _buildBankLoanScaffold(context, debt);
    }

    final paymentsList = _payments.map((p) => DebtHistoryItem(
          id: p.id,
          amount: p.amount,
          date: p.date,
          createdAt: p.createdAt,
          note: p.note,
          updatedBy: p.updatedBy,
          isIncrement: false,
          index: -1,
          hasTime: true,
        ));

    var incIndex = 0;
    final incrementsList = (debt?.increments ?? []).map((inc) {
      final currentIdx = incIndex++;
      return DebtHistoryItem(
        id: '',
        amount: inc.amount,
        date: inc.date,
        createdAt: inc.createdAt ?? inc.date,
        note: inc.note,
        updatedBy: debt!.userId,
        isIncrement: true,
        index: currentIdx,
        linkedIncomeId: inc.linkedIncomeId,
        linkedExpenseId: inc.linkedExpenseId,
        hasTime: inc.createdAt != null,
      );
    });

    final historyItems = [...paymentsList, ...incrementsList]
      ..sort((a, b) {
        final dateCompare = b.date.compareTo(a.date);
        if (dateCompare != 0) return dateCompare;
        return b.createdAt.compareTo(a.createdAt);
      });

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
                                'Ghi chú: ${debt.displayNote?.trim().isNotEmpty == true ? debt.displayNote!.trim() : 'Không có'}',
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
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        isLend ? 'Lịch sử giao dịch' : 'Lịch sử giao dịch',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: historyItems.isEmpty
                        ? Center(
                            child: Text(
                              isLend
                                  ? 'Chưa có lịch sử thu hồi hoặc cho mượn thêm.'
                                  : 'Chưa có lịch sử trả nợ hoặc nợ thêm.',
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                            itemCount: historyItems.length,
                            itemBuilder: (context, index) {
                              final item = historyItems[index];
                              final isOutflow = isLend ? item.isIncrement : !item.isIncrement;
                              final leadingIcon = item.isIncrement
                                  ? Icons.add_circle_outline
                                  : Icons.timeline;
                              final leadingBg = isOutflow
                                  ? AppColors.dangerSoft
                                  : AppColors.successSoft;
                              final leadingFg = isOutflow
                                  ? AppColors.danger
                                  : AppColors.success;
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
                                    backgroundColor: leadingBg,
                                    child: Icon(
                                      leadingIcon,
                                      color: leadingFg,
                                      size: 20,
                                    ),
                                  ),
                                  onTap: () {
                                    if (item.isIncrement) {
                                      _showIncrementActions(item);
                                    } else {
                                      final p = _payments.firstWhere(
                                        (pay) => pay.id == item.id,
                                      );
                                      _showPaymentActions(p);
                                    }
                                  },
                                  title: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.isIncrement
                                            ? (isLend ? 'Cho mượn thêm' : 'Nợ thêm')
                                            : (isLend ? 'Thu hồi nợ' : 'Trả nợ'),
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        !item.hasTime
                                            ? formatDate(item.date)
                                            : '${formatDate(item.date)} ${formatTimeUtcPlus7(item.createdAt)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Người tạo: ${item.updatedBy != null ? _resolveMemberName(item.updatedBy!) : 'Không rõ'}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Ghi chú: ${item.note?.trim().isNotEmpty == true ? item.note!.trim() : 'Không có'}',
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
                                        isOutflow
                                            ? '-${formatVnd(item.amount)}'
                                            : '+${formatVnd(item.amount)}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isOutflow
                                              ? AppColors.danger
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
      floatingActionButton: (debt?.isSplitBill == true)
          ? null
          : FloatingActionButton(
              onPressed: () => _onFabPressed(debt!),
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildBankLoanScaffold(BuildContext context, DebtModel debt) {
    final bankLoan = debt.bankLoanInfo!;
    final totalPrincipal = debt.originalAmount;
    final remainingPrincipal = debt.remainingAmount;
    final paidPrincipal = (totalPrincipal - remainingPrincipal).clamp(0.0, totalPrincipal);
    final pct = totalPrincipal > 0 ? (paidPrincipal / totalPrincipal) : 0.0;

    final nextUnpaid = bankLoan.schedule.firstWhere(
      (item) => !item.isPaid,
      orElse: () => bankLoan.schedule.last,
    );
    final allPaid = bankLoan.schedule.every((item) => item.isPaid);

    return Scaffold(
      appBar: AppBar(
        title: Text(debt.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.percent_outlined),
            tooltip: 'Điều chỉnh lãi suất',
            onPressed: () => _openEditInterestRulesPopup(bankLoan),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _load(showLoader: false),
          ),
        ],
      ),
      body: BusyOverlay(
        isVisible: _isMutating,
        message: 'Đang xử lý...',
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(12),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tổng dư nợ gốc',
                        style: TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        formatVnd(totalPrincipal),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Đã trả',
                        style: TextStyle(fontSize: 14, color: AppColors.success, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        formatVnd(paidPrincipal),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.success),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Còn lại',
                        style: TextStyle(fontSize: 14, color: AppColors.danger, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        formatVnd(remainingPrincipal),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.danger),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: pct.clamp(0.0, 1.0),
                      minHeight: 10,
                      backgroundColor: AppColors.successSoft,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tiến độ trả gốc: ${(pct.clamp(0.0, 1.0) * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            if (!allPaid)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Kỳ thanh toán thứ ${nextUnpaid.monthIndex}',
                          style: const TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Hạn: ${formatDate(nextUnpaid.dueDate)}',
                            style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Tiền gốc cần trả', style: TextStyle(fontSize: 12, color: Colors.white60)),
                            const SizedBox(height: 2),
                            Text(formatVnd(nextUnpaid.principal), style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Tiền lãi (${nextUnpaid.rate}%)', style: const TextStyle(fontSize: 12, color: Colors.white60)),
                            const SizedBox(height: 2),
                            Text(formatVnd(nextUnpaid.interest), style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24, height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tổng tiền cần trả',
                          style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          formatVnd(nextUnpaid.principal + nextUnpaid.interest),
                          style: const TextStyle(fontSize: 16, color: Colors.amberAccent, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF0F172A),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: () => _payBankLoanPeriod(nextUnpaid.monthIndex),
                            child: Text('Thanh toán kỳ này', style: GoogleFonts.roboto(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: () => _openBankLoanPaymentPopup(monthIndex: nextUnpaid.monthIndex, isPrepayment: true),
                            child: Text('Trả gốc trước hạn', style: GoogleFonts.roboto(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'LỊCH TRẢ NỢ CHI TIẾT',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.black54, letterSpacing: 0.5),
                  ),
                  Text(
                    'Kỳ hạn: ${bankLoan.totalMonths} tháng',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black45),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scheduleScrollController,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 40),
                itemCount: bankLoan.schedule.length,
                itemBuilder: (context, index) {
                  final item = bankLoan.schedule[index];
                  final isNext = !item.isPaid && (index == 0 || bankLoan.schedule[index - 1].isPaid);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: item.isPaid ? const Color(0xFFF0FDF4) : (isNext ? const Color(0xFFFFFBEB) : Colors.white),
                      border: Border.all(
                        color: item.isPaid
                            ? const Color(0xFFDCFCE7)
                            : (isNext ? const Color(0xFFFEF3C7) : AppColors.border),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Tháng thứ ${item.monthIndex}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: item.isPaid ? const Color(0xFF166534) : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '(${item.rate}%/năm)',
                                    style: const TextStyle(fontSize: 11, color: Colors.black45),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Hạn trả: ${formatDate(item.dueDate)}',
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                              if (item.isPaid && item.paidDate != null)
                                Text(
                                  'Đã trả ngày: ${formatDate(item.paidDate!)}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF15803D), fontWeight: FontWeight.w500),
                                ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text('Gốc: ${formatVnd(item.principal)}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                  const SizedBox(width: 12),
                                  Text('Lãi: ${formatVnd(item.interest)}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                ],
                              ),
                              if (item.earlyPrincipal > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Trả thêm gốc: ${formatVnd(item.earlyPrincipal)} (Phạt: ${formatVnd(item.penaltyFee)})',
                                    style: GoogleFonts.roboto(fontSize: 11, color: const Color(0xFFB45309), fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (item.isPaid) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Đã trả',
                                  style: TextStyle(color: Color(0xFF166534), fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 4),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                tooltip: 'Hủy thanh toán',
                                onPressed: () => _confirmDeleteBankLoanPayment(item.monthIndex),
                              ),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isNext ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isNext ? 'Đến hạn' : 'Chưa trả',
                                  style: TextStyle(
                                    color: isNext ? const Color(0xFF92400E) : Colors.black45,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (isNext) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.payment, color: Color(0xFF0F172A), size: 20),
                                      tooltip: 'Thanh toán',
                                      onPressed: () => _payBankLoanPeriod(item.monthIndex),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_card, color: Colors.orange, size: 20),
                                      tooltip: 'Trả gốc trước hạn',
                                      onPressed: () => _openBankLoanPaymentPopup(monthIndex: item.monthIndex, isPrepayment: true),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _payBankLoanPeriod(int monthIndex) async {
    final defaultWalletId = _defaultWalletId;
    if (defaultWalletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có ví mặc định để thực hiện thanh toán.')),
      );
      return;
    }

    try {
      await _runMutation(() async {
        await _debtService.payBankLoanMonth(
          coupleId: widget.coupleId,
          debtId: widget.debtId,
          monthIndex: monthIndex,
          walletId: defaultWalletId,
          paymentDate: DateTime.now(),
          recordExpense: true,
          extraPrincipal: 0.0,
          penaltyFee: 0.0,
          note: 'Trả gốc & lãi kỳ $monthIndex cho ${_debt!.name}',
        );
      });
      await _load(showLoader: false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _openBankLoanPaymentPopup({
    required int monthIndex,
    required bool isPrepayment,
  }) async {
    final wallets = await _walletService.getWallets(widget.coupleId);
    if (!mounted) return;
    if (wallets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có ví để thực hiện thanh toán.')),
      );
      return;
    }

    wallets.sort((a, b) {
      if (a.isDefault == b.isDefault) return 0;
      return a.isDefault ? -1 : 1;
    });
    String selectedWalletId = wallets.first.id;

    final scheduleItem = _debt!.bankLoanInfo!.schedule.firstWhere((e) => e.monthIndex == monthIndex);
    final double standardPrincipal = scheduleItem.principal;
    final double standardInterest = scheduleItem.interest;

    final extraPrincipalCtrl = TextEditingController();
    final penaltyFeeCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();
    bool isSubmitting = false;

    if (isPrepayment) {
      noteCtrl.text = 'Trả gốc trước hạn kỳ $monthIndex cho ${_debt!.name}';
    } else {
      noteCtrl.text = 'Trả gốc & lãi kỳ $monthIndex cho ${_debt!.name}';
    }

    final saved = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, anim1, anim2) {
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
                      isPrepayment
                          ? 'Trả gốc trước hạn kỳ $monthIndex'
                          : 'Thanh toán kỳ thứ $monthIndex',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.roboto(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!isPrepayment) ...[
                              Text('Tiền gốc: ${formatVnd(standardPrincipal)}', style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 4),
                              Text('Tiền lãi: ${formatVnd(standardInterest)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 4),
                              Text(
                                'Tổng cộng: ${formatVnd(standardPrincipal + standardInterest)}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                              ),
                              const Divider(height: 24),
                              TextField(
                                controller: extraPrincipalCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  ThousandsSeparatorInputFormatter(),
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Trả thêm gốc (tùy chọn)',
                                  hintText: 'Ví dụ: 10,000,000',
                                ),
                              ),
                            ] else ...[
                              TextField(
                                controller: extraPrincipalCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  ThousandsSeparatorInputFormatter(),
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Số tiền gốc trả trước',
                                  hintText: 'Nhập số tiền gốc muốn trả',
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            TextField(
                              controller: penaltyFeeCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                ThousandsSeparatorInputFormatter(),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Phí phạt trả trước gốc (nếu có)',
                                hintText: 'Ví dụ: 500,000',
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: noteCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Ghi chú',
                              ),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: dialogContext,
                                  initialDate: selectedDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  setDialogState(() => selectedDate = picked);
                                }
                              },
                              icon: const Icon(Icons.calendar_month_outlined),
                              label: Text('Ngày thanh toán: ${formatDate(selectedDate)}'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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

                              final double extraPrincipal = parseAmountInput(extraPrincipalCtrl.text.trim()) ?? 0.0;
                              final double penaltyFee = parseAmountInput(penaltyFeeCtrl.text.trim()) ?? 0.0;

                              if (isPrepayment && extraPrincipal <= 0) {
                                ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  const SnackBar(content: Text('Vui lòng nhập số tiền gốc trả trước.')),
                                );
                                return;
                              }

                              setDialogState(() => isSubmitting = true);
                              try {
                                await _debtService.payBankLoanMonth(
                                  coupleId: widget.coupleId,
                                  debtId: widget.debtId,
                                  monthIndex: monthIndex,
                                  walletId: selectedWalletId,
                                  paymentDate: selectedDate,
                                  recordExpense: false,
                                  extraPrincipal: extraPrincipal,
                                  penaltyFee: penaltyFee,
                                  note: noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : null,
                                );

                                if (dialogContext.mounted) {
                                  Navigator.pop(dialogContext, true);
                                }
                              } catch (e) {
                                if (dialogContext.mounted) {
                                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                                    SnackBar(content: Text('Lỗi: $e')),
                                  );
                                }
                              } finally {
                                if (dialogContext.mounted) {
                                  setDialogState(() => isSubmitting = false);
                                }
                              }
                            },
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Thanh toán'),
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

  Future<void> _confirmDeleteBankLoanPayment(int monthIndex) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Hủy thanh toán kỳ thứ $monthIndex'),
        content: const Text('Xác nhận hủy đợt thanh toán kỳ hạn này? Hệ thống sẽ xóa các giao dịch thanh toán và chi tiêu liên kết, đồng thời tự động tính toán lại lịch trình trả nợ.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy bỏ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _runMutation(() async {
        await _debtService.deleteBankLoanPayment(
          debtId: widget.debtId,
          monthIndex: monthIndex,
        );
        await _load(showLoader: false);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã hủy thanh toán kỳ nợ.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<void> _openEditInterestRulesPopup(BankLoanInfo bankLoan) async {
    final rules = <Map<String, dynamic>>[];
    for (final rule in bankLoan.interestRules) {
      rules.add({
        'from': rule.fromMonth,
        'to': rule.toMonth,
        'rateCtrl': TextEditingController(text: rule.rate.toString()),
      });
    }

    void updateRulesSequencing() {
      for (var i = 0; i < rules.length; i++) {
        if (i == 0) {
          rules[i]['from'] = 1;
        } else {
          rules[i]['from'] = (rules[i - 1]['to'] as int) + 1;
        }
        final fromVal = rules[i]['from'] as int;
        if (i == rules.length - 1) {
          rules[i]['to'] = bankLoan.totalMonths;
        } else {
          final currentTo = rules[i]['to'] as int?;
          if (currentTo == null || currentTo <= fromVal) {
            rules[i]['to'] = fromVal + 12;
          }
        }
      }
    }

    bool isSubmitting = false;

    final saved = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, anim1, anim2) {
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
                    const Text(
                      'Điều chỉnh lãi suất vay ngân hàng',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: rules.length,
                              itemBuilder: (dialogContext, index) {
                                final rule = rules[index];
                                final from = rule['from'] as int;
                                final to = rule['to'] as int;
                                final isLast = index == rules.length - 1;
                                final toCtrl = TextEditingController(text: isLast ? 'Hết hạn' : to.toString());
                                final rateCtrl = rule['rateCtrl'] as TextEditingController;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    border: Border.all(color: Colors.grey.shade200),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Tháng $from',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 3,
                                        child: TextField(
                                          controller: toCtrl,
                                          enabled: !isLast,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                            labelText: 'Đến tháng',
                                            isDense: true,
                                          ),
                                          onChanged: (val) {
                                            final valInt = int.tryParse(val);
                                            if (valInt != null) {
                                              rule['to'] = valInt;
                                              setDialogState(() {
                                                updateRulesSequencing();
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 3,
                                        child: TextField(
                                          controller: rateCtrl,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          decoration: const InputDecoration(
                                            labelText: 'Lãi suất %/năm',
                                            isDense: true,
                                          ),
                                        ),
                                      ),
                                      if (rules.length > 1)
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                          onPressed: () {
                                            setDialogState(() {
                                              rules.removeAt(index);
                                              updateRulesSequencing();
                                            });
                                          },
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () {
                                final lastTo = rules.isNotEmpty
                                    ? (rules.last['to'] as int)
                                    : 0;
                                if (lastTo >= bankLoan.totalMonths) {
                                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                                    const SnackBar(content: Text('Khoảng lãi suất đã bao phủ toàn bộ kỳ hạn vay.')),
                                  );
                                  return;
                                }
                                setDialogState(() {
                                  rules.add({
                                    'from': lastTo + 1,
                                    'to': bankLoan.totalMonths,
                                    'rateCtrl': TextEditingController(text: '10.0'),
                                  });
                                  updateRulesSequencing();
                                });
                              },
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Thêm khoảng lãi suất', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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

                              final newRules = <InterestRateRule>[];
                              for (var i = 0; i < rules.length; i++) {
                                final from = rules[i]['from'] as int;
                                var to = rules[i]['to'] as int;
                                final rateStr = (rules[i]['rateCtrl'] as TextEditingController).text.trim();
                                final rate = double.tryParse(rateStr) ?? 10.0;

                                if (to < from) {
                                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                                    SnackBar(content: Text('Kỳ hạn thứ ${i + 1} không hợp lệ (Tháng đến < Tháng từ).')),
                                  );
                                  return;
                                }

                                if (i == rules.length - 1 && to < bankLoan.totalMonths) {
                                  to = bankLoan.totalMonths;
                                }

                                newRules.add(InterestRateRule(
                                  fromMonth: from,
                                  toMonth: to,
                                  rate: rate,
                                ));
                              }

                              setDialogState(() => isSubmitting = true);
                              try {
                                await _debtService.updateBankLoanInterestRules(
                                  debtId: widget.debtId,
                                  newRules: newRules,
                                );

                                if (dialogContext.mounted) {
                                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                                    const SnackBar(content: Text('Đã cập nhật lãi suất thành công.')),
                                  );
                                  Navigator.pop(dialogContext, true);
                                }
                              } catch (e) {
                                if (dialogContext.mounted) {
                                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                                    SnackBar(content: Text('Lỗi: $e')),
                                  );
                                }
                              } finally {
                                if (dialogContext.mounted) {
                                  setDialogState(() => isSubmitting = false);
                                }
                              }
                            },
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
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
}

class DebtHistoryItem {
  final String id;
  final double amount;
  final DateTime date;
  final DateTime createdAt;
  final String? note;
  final String? updatedBy;
  final bool isIncrement;
  final int index;
  final String? linkedIncomeId;
  final String? linkedExpenseId;
  final bool hasTime;

  DebtHistoryItem({
    required this.id,
    required this.amount,
    required this.date,
    required this.createdAt,
    this.note,
    this.updatedBy,
    required this.isIncrement,
    required this.index,
    this.linkedIncomeId,
    this.linkedExpenseId,
    required this.hasTime,
  });
}
