import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_app_demo/core/utils/amount_input.dart';
import 'package:flutter_app_demo/core/widgets/amount_suggestion_chips.dart';
import 'package:flutter_app_demo/core/utils/formatters.dart';
import 'package:flutter_app_demo/features/debt/data/models/debt_model.dart';
import 'package:flutter_app_demo/features/debt/data/services/debt_service.dart';
import 'package:flutter_app_demo/features/debt/presentation/screens/debt_detail_screen.dart';

class DebtListScreen extends StatefulWidget {
  final String coupleId;
  final ValueListenable<int>? refreshSignal;
  final VoidCallback? onDataChanged;

  const DebtListScreen({
    super.key,
    required this.coupleId,
    this.refreshSignal,
    this.onDataChanged,
  });

  @override
  State<DebtListScreen> createState() => _DebtListScreenState();
}

class _DebtListScreenState extends State<DebtListScreen> {
  final _service = DebtService();
  List<DebtModel> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.refreshSignal?.addListener(_onExternalRefresh);
    _load();
  }

  @override
  void didUpdateWidget(covariant DebtListScreen oldWidget) {
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
    _load();
  }

  Future<void> _openDebtPopup({DebtModel? existing}) async {
    final personCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final debtTypes = await _service.getDebtTypes(widget.coupleId);
    if (!mounted) return;
    if (debtTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chua co loai no. Vui long tao loai no truoc.'),
        ),
      );
      return;
    }
    final selectedDebtTypeId = ValueNotifier<String>(
      existing?.debtTypeId ?? (debtTypes.first['id'] as String),
    );
    final selectedDebtKind = ValueNotifier<String>(
      existing?.debtKind ?? 'debt',
    );
    final shouldRecordToIncome = ValueNotifier<bool>(
      existing?.recordToIncome ?? false,
    );
    DateTime? dueDate = existing?.dueDate;
    if (existing != null) {
      personCtrl.text = existing.name;
      amountCtrl.text = formatAmountInput(
        existing.originalAmount.toStringAsFixed(0),
      );
      noteCtrl.text = existing.note ?? '';
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: Text(existing == null ? 'Them no' : 'Sua no'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: personCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nguoi lien quan',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                  ValueListenableBuilder<String>(
                    valueListenable: selectedDebtTypeId,
                    builder: (_, value, _) => DropdownButtonFormField<String>(
                      initialValue: value,
                      decoration: const InputDecoration(
                        labelText: 'Loai no',
                        border: OutlineInputBorder(),
                      ),
                      items: debtTypes
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item['id'] as String,
                              child: Text(item['name'] as String),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) selectedDebtTypeId.value = v;
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<String>(
                    valueListenable: selectedDebtKind,
                    builder: (_, value, child) =>
                        DropdownButtonFormField<String>(
                          initialValue: value,
                          decoration: const InputDecoration(
                            labelText: 'Phan loai',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'debt',
                              child: Text('No (ban dang no)'),
                            ),
                            DropdownMenuItem(
                              value: 'lend',
                              child: Text('Cho muon no'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) selectedDebtKind.value = v;
                          },
                        ),
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<String>(
                    valueListenable: selectedDebtKind,
                    builder: (_, debtKind, child) {
                      if (debtKind != 'debt') {
                        return const ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.info_outline),
                          title: Text(
                            'Cho muon se phat sinh giao dich chi tieu.',
                          ),
                        );
                      }
                      return ValueListenableBuilder<bool>(
                        valueListenable: shouldRecordToIncome,
                        builder: (_, value, child) => CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: value,
                          onChanged: (v) {
                            shouldRecordToIncome.value = v ?? false;
                          },
                          title: const Text(
                            'Ghi nhan vao thu nhap khi khoi tao',
                          ),
                          subtitle: const Text(
                            'Bat khi khoan no la tien thuc nhan. Tat neu la tai san khac.',
                          ),
                        ),
                      );
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
                        initialDate: dueDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() => dueDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      dueDate == null
                          ? 'Chon han thanh toan'
                          : 'Han: ${formatDate(dueDate!)}',
                    ),
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
                  if (personCtrl.text.trim().isEmpty ||
                      amount == null ||
                      amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Nhap du thong tin hop le.'),
                      ),
                    );
                    return;
                  }
                  final uid = Supabase.instance.client.auth.currentUser?.id;
                  if (uid == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Khong tim thay phien dang nhap.'),
                      ),
                    );
                    return;
                  }
                  if (existing == null) {
                    await _service.createDebt(
                      coupleId: widget.coupleId,
                      userId: uid,
                      debtTypeId: selectedDebtTypeId.value,
                      debtKind: selectedDebtKind.value,
                      recordToIncome: selectedDebtKind.value == 'debt'
                          ? shouldRecordToIncome.value
                          : false,
                      name: personCtrl.text.trim(),
                      originalAmount: amount,
                      creditorName: personCtrl.text.trim(),
                      startDate: DateTime.now(),
                      dueDate: dueDate,
                      note: noteCtrl.text.trim().isEmpty
                          ? null
                          : noteCtrl.text.trim(),
                    );
                  } else {
                    await _service.updateDebt(
                      debtId: existing.id,
                      debtTypeId: selectedDebtTypeId.value,
                      debtKind: selectedDebtKind.value,
                      recordToIncome: selectedDebtKind.value == 'debt'
                          ? shouldRecordToIncome.value
                          : false,
                      name: personCtrl.text.trim(),
                      originalAmount: amount,
                      creditorName: personCtrl.text.trim(),
                      startDate: existing.startDate,
                      dueDate: dueDate,
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

    selectedDebtTypeId.dispose();
    selectedDebtKind.dispose();
    shouldRecordToIncome.dispose();

    if (saved == true) {
      await _load();
      widget.onDataChanged?.call();
    }
  }

  Future<void> _showDebtActions(DebtModel item) async {
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
      await _openDebtPopup(existing: item);
      return;
    }
    if (action == 'delete') {
      final impact = await _service.previewDeleteDebtImpact(item.id);
      if (!mounted) return;
      String message;
      if (impact < 0) {
        message =
            'Neu xac nhan xoa khoan no, ban se bi tru lai ${formatVnd(impact.abs())}.';
      } else if (impact > 0) {
        message =
            'Neu xac nhan xoa khoan no, ban se duoc cong them ${formatVnd(impact)}.';
      } else {
        message =
            'Neu xac nhan xoa khoan no, he thong khong phat sinh giao dich tien.';
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Xac nhan xoa khoan no'),
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

      await _service.deleteDebt(item.id);
      if (mounted) {
        setState(() {
          _items.removeWhere((d) => d.id == item.id);
        });
      }
      widget.onDataChanged?.call();
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await _service.getDebts(widget.coupleId);
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Khoan no va cho muon'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
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
                  FilledButton(onPressed: _load, child: const Text('Thử lại')),
                ],
              ),
            )
          : _items.isEmpty
          ? const Center(child: Text('Chưa có khoản nợ nào.'))
          : ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final isLend = item.debtKind == 'lend';
                final pct = item.originalAmount > 0
                    ? 1 - (item.remainingAmount / item.originalAmount)
                    : 1.0;
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: InkWell(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DebtDetailScreen(
                            coupleId: widget.coupleId,
                            debtId: item.id,
                          ),
                        ),
                      );
                      if (mounted) {
                        await _load();
                        widget.onDataChanged?.call();
                      }
                    },
                    onLongPress: () => _showDebtActions(item),
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: item.isClosed
                            ? Colors.green
                            : (isLend ? Colors.blue : Colors.orange),
                        child: Icon(
                          item.isClosed
                              ? Icons.check
                              : (isLend
                                    ? Icons.account_balance_wallet
                                    : Icons.credit_card),
                          color: Colors.white,
                        ),
                      ),
                      title: Text(item.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isLend ? 'Loai: Cho muon no' : 'Loai: Khoan no',
                            style: TextStyle(
                              color: isLend ? Colors.blue : Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(item.creditorName),
                          LinearProgressIndicator(
                            value: pct.clamp(0.0, 1.0),
                            backgroundColor: Colors.grey[200],
                            color: item.isClosed
                                ? Colors.green
                                : (isLend ? Colors.blue : Colors.orange),
                          ),
                          Text(
                            'Con lai: ${formatVnd(item.remainingAmount)}'
                            '${item.dueDate != null ? '\nHan: ${formatDate(item.dueDate!)}' : ''}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      trailing: Text(
                        formatVnd(item.originalAmount),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      isThreeLine: true,
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openDebtPopup,
        child: const Icon(Icons.add),
      ),
    );
  }
}
