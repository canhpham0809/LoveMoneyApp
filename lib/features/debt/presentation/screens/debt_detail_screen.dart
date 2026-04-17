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
      ).showSnackBar(const SnackBar(content: Text('Chua co vi de tra no.')));
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
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: Text(existing == null ? 'Tra no' : 'Sua dot tra no'),
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
                      labelText: 'So tien tra no',
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
      await _debtService.deletePayment(
        paymentId: item.id,
        debtId: widget.debtId,
      );
      await _load(showLoader: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final debt = _debt;
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiet No')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : debt == null
          ? const Center(child: Text('Khong tim thay khoan no.'))
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
                        Text('Tong no: ${formatVnd(debt.originalAmount)}'),
                        Text('Con lai: ${formatVnd(debt.remainingAmount)}'),
                        Text('Chu no: ${debt.creditorName}'),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Timeline dot tra no',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _payments.isEmpty
                      ? const Center(child: Text('Chua co dot tra no nao.'))
                      : ListView.builder(
                          itemCount: _payments.length,
                          itemBuilder: (context, index) {
                            final p = _payments[index];
                            return ListTile(
                              leading: const Icon(Icons.timeline),
                              onLongPress: () => _showPaymentActions(p),
                              title: Text(formatVnd(p.amount)),
                              subtitle: Text(
                                '${formatDate(p.date)} · ${formatDateTime(p.createdAt).split(' ').last} · ${p.updatedBy != null ? (_memberNameById[p.updatedBy!] ?? p.updatedBy!) : 'Không rõ'}${p.note != null ? ' · ${p.note}' : ''}',
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
