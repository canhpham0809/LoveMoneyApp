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

  const DebtListScreen({
    super.key,
    required this.coupleId,
    this.refreshSignal,
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
        const SnackBar(content: Text('Chua co loai no. Vui long tao loai no truoc.')),
      );
      return;
    }
    final selectedDebtTypeId = ValueNotifier<String>(
      existing?.debtTypeId ?? (debtTypes.first['id'] as String),
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
                    builder: (_, value, __) => DropdownButtonFormField<String>(
                      value: value,
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
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chu (tuy chon)',
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
                          ? 'Chon han thanh toan (tuy chon)'
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
                  if (personCtrl.text.trim().isEmpty || amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Nhap du thong tin hop le.')),
                    );
                    return;
                  }
                  final uid = Supabase.instance.client.auth.currentUser?.id;
                  if (uid == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Khong tim thay phien dang nhap.')),
                    );
                    return;
                  }
                  if (existing == null) {
                    await _service.createDebt(
                      coupleId: widget.coupleId,
                      userId: uid,
                      debtTypeId: selectedDebtTypeId.value,
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

    if (saved == true) {
      await _load();
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
      await _service.deleteDebt(item.id);
      if (mounted) {
        setState(() {
          _items.removeWhere((d) => d.id == item.id);
        });
      }
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
        title: const Text('Khoản nợ'),
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
                      }
                    },
                    onLongPress: () => _showDebtActions(item),
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: item.isClosed
                            ? Colors.green
                            : Colors.orange,
                        child: Icon(
                          item.isClosed ? Icons.check : Icons.credit_card,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(item.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.creditorName),
                          LinearProgressIndicator(
                            value: pct.clamp(0.0, 1.0),
                            backgroundColor: Colors.grey[200],
                            color: item.isClosed ? Colors.green : Colors.orange,
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
