import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_app_demo/core/utils/amount_input.dart';
import 'package:flutter_app_demo/core/widgets/amount_suggestion_chips.dart';
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
    if (existing != null) {
      amountCtrl.text = existing.amount.toStringAsFixed(0);
      noteCtrl.text = existing.note ?? '';
    }

    final isWithdrawalTx =
        isWithdrawal || existing?.contributionType == 'withdrawal';

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: Text(
              existing == null
                  ? (isWithdrawalTx ? 'Rút quỹ' : 'Góp quỹ')
                  : (isWithdrawalTx ? 'Sửa đợt rút' : 'Sửa đợt góp'),
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
                onPressed: () {
                  if (isClosingDialog) return;
                  isClosingDialog = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).maybePop(false);
                  });
                },
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () async {
                  if (isClosingDialog) return;
                  final amount = parseAmountInput(amountCtrl.text.trim());
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Số tiền không hợp lệ.')),
                    );
                    return;
                  }
                  if (existing == null) {
                    final uid = Supabase.instance.client.auth.currentUser!.id;
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
                  isClosingDialog = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).maybePop(true);
                  });
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

      await _fundService.deleteContribution(
        contributionId: item.id,
        fundId: widget.fundId,
      );
      await _load(showLoader: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fund = _fund;
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết Quỹ')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : fund == null
          ? const Center(child: Text('Không tìm thấy quỹ.'))
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
                          fund.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Đã góp: ${formatVnd(fund.currentAmount)}'),
                        if (fund.targetAmount != null)
                          Text('Mục tiêu: ${formatVnd(fund.targetAmount!)}'),
                        if (fund.creatorUserId != null)
                          Text(
                            'Người tạo: ${_resolveMemberName(fund.creatorUserId!)}',
                          ),
                      ],
                    ),
                  ),
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
                          itemCount: _contributions.length,
                          itemBuilder: (context, index) {
                            final c = _contributions[index];
                            final isWithdrawal =
                                c.contributionType == 'withdrawal';
                            return ListTile(
                              leading: Icon(
                                isWithdrawal
                                    ? Icons.south_west_rounded
                                    : Icons.north_east_rounded,
                                color: isWithdrawal
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              onLongPress: () => _showContributionActions(c),
                              title: Text(
                                '${isWithdrawal ? '+' : '-'}${formatVnd(c.amount)}',
                                style: TextStyle(
                                  color: isWithdrawal
                                      ? Colors.green
                                      : Colors.orange,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                '${isWithdrawal ? 'Rút quỹ' : 'Góp quỹ'} · ${formatDate(c.date)} · ${formatTimeUtcPlus7(c.createdAt)} · ${_memberNameById[c.userId] ?? c.userId}${c.note != null ? ' · ${c.note}' : ''}',
                              ),
                            );
                          },
                        ),
                ),
              ],
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
