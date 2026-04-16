import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_app_demo/core/utils/amount_input.dart';
import 'package:flutter_app_demo/core/widgets/amount_suggestion_chips.dart';
import 'package:flutter_app_demo/core/utils/formatters.dart';
import 'package:flutter_app_demo/features/transfer/data/models/transfer_model.dart';
import 'package:flutter_app_demo/features/transfer/data/services/transfer_service.dart';
import 'package:flutter_app_demo/features/wallet/data/services/wallet_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TransferListScreen extends StatefulWidget {
  final String coupleId;
  final ValueListenable<int>? refreshSignal;
  final VoidCallback? onDataChanged;

  const TransferListScreen({
    super.key,
    required this.coupleId,
    this.refreshSignal,
    this.onDataChanged,
  });

  @override
  State<TransferListScreen> createState() => _TransferListScreenState();
}

class _TransferListScreenState extends State<TransferListScreen> {
  final _service = TransferService();
  final _walletService = WalletService();
  List<TransferModel> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.refreshSignal?.addListener(_onExternalRefresh);
    _load();
  }

  @override
  void didUpdateWidget(covariant TransferListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      oldWidget.refreshSignal?.removeListener(_onExternalRefresh);
      widget.refreshSignal?.addListener(_onExternalRefresh);
    }
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_onExternalRefresh);
    super.dispose();
  }

  void _onExternalRefresh() {
    if (!mounted) return;
    _load(showLoader: false);
  }

  Future<void> _load({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else if (mounted) {
      setState(() => _error = null);
    }
    try {
      final items = await _service.getTransfers(widget.coupleId);
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (showLoader && mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete(TransferModel item) async {
    try {
      await _service.deleteTransfer(item.id);
      if (mounted) {
        setState(() {
          _items.removeWhere((e) => e.id == item.id);
        });
      }
      widget.onDataChanged?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Da xoa giao dich chuyen tien')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi xóa: $e')));
      }
    }
  }

  Future<void> _openTransferPopup({TransferModel? existing}) async {
    final members = await _service.getCoupleMembers(widget.coupleId);
    final wallets = await _walletService.getWallets(widget.coupleId);
    final uid = Supabase.instance.client.auth.currentUser!.id;

    final recipients = members
        .map((m) => m['user_id'] as String)
        .where((id) => id != uid)
        .toList();

    if (!mounted) return;

    if (recipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chua co partner trong couple.')),
      );
      return;
    }
    if (wallets.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Can it nhat 2 vi de chuyen tien.')),
      );
      return;
    }

    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String selectedRecipientId = existing?.toUserId ?? recipients.first;
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
            title: Text(existing == null ? 'Them chuyen tien' : 'Sua chuyen tien'),
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
                  DropdownButtonFormField<String>(
                    value: selectedRecipientId,
                    decoration: const InputDecoration(
                      labelText: 'Nguoi nhan',
                      border: OutlineInputBorder(),
                    ),
                    items: recipients
                        .map(
                          (id) => DropdownMenuItem(
                            value: id,
                            child: Text('Partner'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() => selectedRecipientId = v);
                      }
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

                  wallets.sort((a, b) {
                    if (a.isDefault == b.isDefault) return 0;
                    return a.isDefault ? -1 : 1;
                  });
                  final fromWalletId = existing?.fromWalletId ?? wallets[0].id;
                  final toWalletId = existing?.toWalletId ?? wallets[1].id;

                  if (existing == null) {
                    await _service.createTransfer(
                      coupleId: widget.coupleId,
                      fromUserId: uid,
                      toUserId: selectedRecipientId,
                      fromWalletId: fromWalletId,
                      toWalletId: toWalletId,
                      amount: amount,
                      note: noteCtrl.text.trim().isEmpty
                          ? null
                          : noteCtrl.text.trim(),
                      date: selectedDate,
                    );
                  } else {
                    await _service.updateTransfer(
                      transferId: existing.id,
                      fromUserId: uid,
                      toUserId: selectedRecipientId,
                      fromWalletId: fromWalletId,
                      toWalletId: toWalletId,
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
      widget.onDataChanged?.call();
    }
  }

  Future<void> _showItemActions(TransferModel item) async {
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
      await _openTransferPopup(existing: item);
      return;
    }
    if (action == 'delete') {
      await _delete(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chuyển tiền'),
        actions: [
          IconButton(onPressed: () => _load(), icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => _load(),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            )
          : _items.isEmpty
          ? const Center(child: Text('Chưa có lệnh chuyển tiền nào.'))
          : ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return Dismissible(
                  key: ValueKey(item.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => _delete(item),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.swap_horiz)),
                    onLongPress: () => _showItemActions(item),
                    title: Text(item.note ?? 'Chuyển tiền'),
                    subtitle: Text(
                      '${formatDate(item.date)} · ${formatDateTime(item.createdAt).split(' ').last}',
                    ),
                    trailing: Text(
                      formatVnd(item.amount),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _openTransferPopup();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
