import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_app_demo/core/utils/amount_input.dart';
import 'package:flutter_app_demo/core/widgets/amount_suggestion_chips.dart';
import 'package:flutter_app_demo/core/utils/formatters.dart';
import 'package:flutter_app_demo/features/income/data/models/income_model.dart';
import 'package:flutter_app_demo/features/income/data/services/income_service.dart';
import 'package:flutter_app_demo/features/income/presentation/screens/income_search_filter_screen.dart';
import 'package:flutter_app_demo/features/wallet/data/services/wallet_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class IncomeListScreen extends StatefulWidget {
  final String coupleId;
  final ValueListenable<int>? refreshSignal;
  final VoidCallback? onDataChanged;

  const IncomeListScreen({
    super.key,
    required this.coupleId,
    this.refreshSignal,
    this.onDataChanged,
  });

  @override
  State<IncomeListScreen> createState() => _IncomeListScreenState();
}

class _IncomeListScreenState extends State<IncomeListScreen> {
  final _service = IncomeService();
  final _walletService = WalletService();
  List<IncomeModel> _items = [];
  Map<String, String> _sourceNameById = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.refreshSignal?.addListener(_onExternalRefresh);
    _load();
  }

  @override
  void didUpdateWidget(covariant IncomeListScreen oldWidget) {
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
      final items = await _service.getIncomes(widget.coupleId);
      final sources = await _service.getIncomeSources(widget.coupleId);
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) {
        setState(() {
          _items = items;
          _sourceNameById = {
            for (final s in sources) s.id: s.name,
          };
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (showLoader && mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete(IncomeModel item) async {
    try {
      await _service.deleteIncome(item.id);
      if (mounted) {
        setState(() {
          _items.removeWhere((e) => e.id == item.id);
        });
      }
      widget.onDataChanged?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Loi xoa: $e')));
      }
    }
  }

  Future<String?> _resolveDefaultWalletId() async {
    final wallets = await _walletService.getWallets(widget.coupleId);
    if (wallets.isEmpty) return null;
    wallets.sort((a, b) {
      if (a.isDefault == b.isDefault) return 0;
      return a.isDefault ? -1 : 1;
    });
    return wallets.first.id;
  }

  Future<void> _openIncomePopup({IncomeModel? existing}) async {
    final sources = await _service.getIncomeSources(widget.coupleId);
    if (!mounted) return;
    if (sources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chua co nguon thu nhap.')),
      );
      return;
    }
    final walletId = await _resolveDefaultWalletId();
    if (!mounted) return;
    if (walletId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Chua co vi de ghi nhan.')));
      return;
    }

    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String selectedSourceId = existing?.incomeSourceId ?? sources.first.id;
    DateTime selectedDate = existing?.date ?? DateTime.now();
    if (existing != null) {
      amountCtrl.text = existing.amount.toStringAsFixed(0);
      noteCtrl.text = existing.description ?? '';
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: Text(existing == null ? 'Them thu nhap' : 'Sua thu nhap'),
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
                    value: selectedSourceId,
                    decoration: const InputDecoration(
                      labelText: 'Nguon thu',
                      border: OutlineInputBorder(),
                    ),
                    items: sources
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() => selectedSourceId = v);
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

                  final uid = Supabase.instance.client.auth.currentUser!.id;
                  if (existing == null) {
                    await _service.createIncome(
                      coupleId: widget.coupleId,
                      userId: uid,
                      walletId: walletId,
                      incomeSourceId: selectedSourceId,
                      amount: amount,
                      description: noteCtrl.text.trim().isEmpty
                          ? null
                          : noteCtrl.text.trim(),
                      date: selectedDate,
                    );
                  } else {
                    await _service.updateIncome(
                      incomeId: existing.id,
                      walletId: walletId,
                      incomeSourceId: selectedSourceId,
                      amount: amount,
                      description: noteCtrl.text.trim().isEmpty
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

  Future<void> _showItemActions(IncomeModel item) async {
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
      await _openIncomePopup(existing: item);
      return;
    }
    if (action == 'delete') {
      await _delete(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<IncomeModel>>{};
    for (final item in _items) {
      final key = '${item.date.year}-${item.date.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => <IncomeModel>[]).add(item);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thu nhập'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => IncomeSearchFilterScreen(
                    coupleId: widget.coupleId,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.search),
            tooltip: 'Search & Filter',
          ),
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
          ? const Center(child: Text('Chưa có thu nhập nào.'))
          : ListView(
              children: [
                for (final entry in grouped.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Thang ${entry.key.split('-')[1]}/${entry.key.split('-')[0]}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ...entry.value.map((item) {
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
                        leading: const CircleAvatar(
                          child: Icon(Icons.attach_money),
                        ),
                        onLongPress: () => _showItemActions(item),
                        title: Text(
                          (item.description != null &&
                                  item.description!.trim().isNotEmpty)
                              ? item.description!
                              : (_sourceNameById[item.incomeSourceId] ??
                                    'Giao dich'),
                        ),
                        subtitle: Text(
                          '${formatDate(item.date)} · ${formatDateTime(item.createdAt).split(' ').last}',
                        ),
                        trailing: Text(
                          formatVnd(item.amount),
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _openIncomePopup();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
