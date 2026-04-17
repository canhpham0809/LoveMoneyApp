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
      final members = await Supabase.instance.client
          .from('couple_members')
          .select('user_id')
          .eq('couple_id', widget.coupleId)
          .eq('is_deleted', false);
      final memberIds = members
          .map((m) => m['user_id'] as String)
          .toSet()
          .toList();

      final users = memberIds.isEmpty
          ? <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              await Supabase.instance.client
                  .from('users')
                  .select('id, display_name, email')
                  .inFilter('id', memberIds),
            );
      final memberNameById = {
        for (final u in users)
          u['id'] as String:
              ((u['display_name'] as String?)?.trim().isNotEmpty == true
              ? (u['display_name'] as String).trim()
              : ((u['email'] as String?) ?? 'User')),
      };

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
      ).showSnackBar(const SnackBar(content: Text('Chua co vi de gop quy.')));
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
                  ? (isWithdrawalTx ? 'Rut quy' : 'Gop quy')
                  : (isWithdrawalTx ? 'Sua dot rut' : 'Sua dot gop'),
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
                      labelText: 'So tien',
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
                      labelText: 'Ghi chu',
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
                    label: Text('Ngay: ${formatDate(selectedDate)}'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Huy'),
              ),
              FilledButton(
                onPressed: () async {
                  final amount = parseAmountInput(amountCtrl.text.trim());
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('So tien khong hop le.')),
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
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext, true);
                  }
                },
                child: const Text('Luu'),
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
            'Neu xac nhan xoa giao dich nay, so du vi se bi tru lai ${formatVnd(impact.abs())}. He thong dong thoi huy giao dich thu nhap lien ket.';
      } else if (impact > 0) {
        message =
            'Neu xac nhan xoa giao dich nay, ban se duoc cong them ${formatVnd(impact)}.';
      } else {
        message =
            'Neu xac nhan xoa giao dich nay, he thong khong phat sinh giao dich bu tru moi.';
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Xac nhan xoa giao dich quy'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Huy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Xoa'),
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
      appBar: AppBar(title: const Text('Chi tiet Quy')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : fund == null
          ? const Center(child: Text('Khong tim thay quy.'))
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
                        Text('Da gop: ${formatVnd(fund.currentAmount)}'),
                        if (fund.targetAmount != null)
                          Text('Muc tieu: ${formatVnd(fund.targetAmount!)}'),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Lich su giao dich quy',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _contributions.isEmpty
                      ? const Center(child: Text('Chua co dot gop nao.'))
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
                                '${isWithdrawal ? 'Rut quy' : 'Gop quy'} · ${formatDate(c.date)} · ${formatDateTime(c.createdAt).split(' ').last} · ${_memberNameById[c.userId] ?? c.userId}${c.note != null ? ' · ${c.note}' : ''}',
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
