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
      if (!mounted) return;
      setState(() {
        _fund = fund;
        _contributions = contributions;
      });
    } finally {
      if (showLoader && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openContributionPopup({FundContributionModel? existing}) async {
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

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: Text(existing == null ? 'Gop quy' : 'Sua dot gop'),
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
                      labelText: 'So tien gop',
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
      await _openContributionPopup(existing: item);
      return;
    }
    if (action == 'delete') {
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
                      'Timeline dot gop quy',
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
                            return ListTile(
                              leading: const Icon(Icons.timeline),
                              onLongPress: () => _showContributionActions(c),
                              title: Text(formatVnd(c.amount)),
                              subtitle: Text(
                                '${formatDate(c.date)} · ${formatDateTime(c.createdAt).split(' ').last}${c.note != null ? ' · ${c.note}' : ''}',
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openContributionPopup,
        child: const Icon(Icons.add),
      ),
    );
  }
}
