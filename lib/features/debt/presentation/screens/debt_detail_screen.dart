import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_app_demo/core/utils/amount_input.dart';
import 'package:flutter_app_demo/core/widgets/amount_suggestion_chips.dart';
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
  bool _isLoading = true;

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

      if (!mounted) return;
      setState(() {
        _debt = debt;
        _payments = payments;
        _memberNameById = memberNameById;
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
    if (existing != null) {
      amountCtrl.text = existing.amount.toStringAsFixed(0);
      noteCtrl.text = existing.note ?? '';
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final isLend = _debt?.debtKind == 'lend';
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: Text(
              existing == null
                  ? (isLend ? 'Thu hoi no' : 'Tra no')
                  : (isLend ? 'Sửa đợt thu hồi' : 'Sửa đợt trả nợ'),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      ThousandsSeparatorInputFormatter(),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Số tiền',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  AmountSuggestionChips(
                    controller: amountCtrl,
                    onSelected: (value) {
                      amountCtrl.text = formatAmountInput(value.toString());
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                    icon: const Icon(Icons.calendar_today),
                    label: Text('Ngày: ${formatDate(selectedDate)}'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () async {
                  final amount = parseAmountInput(amountCtrl.text.trim());
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Số tiền không hợp lệ.')),
                    );
                    return;
                  }
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
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, true);
                  }
                },
                child: const Text('Lưu'),
              ),
            ],
          ),
        );
      },
    );

    if (saved == true) {
      await _load(showLoader: false);
    }
  }

  Future<void> _showPaymentActions(DebtPaymentModel item) async {
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
        await _debtService.deletePayment(
          paymentId: item.id,
          debtId: widget.debtId,
        );
        await _load(showLoader: false);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi xóa: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final debt = _debt;
    final isLend = debt?.debtKind == 'lend';
    return Scaffold(
      appBar: AppBar(title: Text(isLend ? 'Chi tiết Cho mượn' : 'Chi tiết Nợ')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : debt == null
          ? const Center(child: Text('Không tìm thấy khoản nợ.'))
          : Column(
              children: [
                Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          debt.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Tổng nợ: ${formatVnd(debt.originalAmount)}'),
                        Text(
                          '${isLend ? 'Còn phải thu' : 'Còn lại'}: ${formatVnd(debt.remainingAmount)}',
                        ),
                        Text('Người nợ: ${debt.creditorName}'),
                        Text('Người tạo: ${_resolveMemberName(debt.userId)}'),
                      ],
                    ),
                  ),
                ),
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
                          itemCount: _payments.length,
                          itemBuilder: (context, index) {
                            final p = _payments[index];
                            return ListTile(
                              leading: const Icon(Icons.timeline),
                              onLongPress: () => _showPaymentActions(p),
                              title: Text(formatVnd(p.amount)),
                              subtitle: Text(
                                '${formatDate(p.date)} · ${formatTimeUtcPlus7(p.createdAt)} · ${p.updatedBy != null ? (_memberNameById[p.updatedBy!] ?? p.updatedBy!) : 'Không rõ'}${p.note != null ? ' · ${p.note}' : ''}',
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openPaymentPopup,
        child: const Icon(Icons.add),
      ),
    );
  }
}
