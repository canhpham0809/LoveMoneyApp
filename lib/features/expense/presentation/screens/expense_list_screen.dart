import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_app_demo/core/utils/amount_input.dart';
import 'package:flutter_app_demo/core/widgets/amount_suggestion_chips.dart';
import 'package:flutter_app_demo/core/utils/formatters.dart';
import 'package:flutter_app_demo/features/expense/data/models/expense_model.dart';
import 'package:flutter_app_demo/features/expense/data/services/expense_service.dart';
import 'package:flutter_app_demo/features/expense/presentation/screens/expense_search_filter_screen.dart';
import 'package:flutter_app_demo/features/wallet/data/services/wallet_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExpenseListScreen extends StatefulWidget {
  final String coupleId;
  final ValueListenable<int>? refreshSignal;
  final VoidCallback? onDataChanged;

  const ExpenseListScreen({
    super.key,
    required this.coupleId,
    this.refreshSignal,
    this.onDataChanged,
  });

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  final _service = ExpenseService();
  final _walletService = WalletService();
  List<ExpenseModel> _items = [];
  Map<String, String> _categoryNameById = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.refreshSignal?.addListener(_onExternalRefresh);
    _load();
  }

  @override
  void didUpdateWidget(covariant ExpenseListScreen oldWidget) {
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
      final categories = await _service.getCategories(widget.coupleId);
      final items = await _service.getExpenses(widget.coupleId);
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) {
        setState(() {
          _items = items;
          _categoryNameById = {for (final c in categories) c.id: c.name};
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (showLoader && mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete(ExpenseModel item) async {
    try {
      await _service.deleteExpense(item.id);
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
        ).showSnackBar(SnackBar(content: Text('Lỗi xóa: $e')));
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

  Future<void> _openExpensePopup({ExpenseModel? existing}) async {
    final categories = await _service.getCategories(widget.coupleId);
    if (!mounted) return;
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chua co danh muc chi tieu.')),
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
    String selectedCategoryId = existing?.categoryId ?? categories.first.id;
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
            title: Text(existing == null ? 'Them chi tieu' : 'Sua chi tieu'),
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
                    value: selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Danh muc',
                      border: OutlineInputBorder(),
                    ),
                    items: categories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setDialogState(() => selectedCategoryId = v);
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
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('So tien khong hop le.')),
                    );
                    return;
                  }

                  final uid = Supabase.instance.client.auth.currentUser!.id;
                  if (existing == null) {
                    await _service.createExpense(
                      coupleId: widget.coupleId,
                      userId: uid,
                      walletId: walletId,
                      categoryId: selectedCategoryId,
                      amount: amount,
                      description: noteCtrl.text.trim().isEmpty
                          ? null
                          : noteCtrl.text.trim(),
                      date: selectedDate,
                    );
                  } else {
                    await _service.updateExpense(
                      expenseId: existing.id,
                      walletId: walletId,
                      categoryId: selectedCategoryId,
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

  Future<void> _showItemActions(ExpenseModel item) async {
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
      await _openExpensePopup(existing: item);
      return;
    }
    if (action == 'delete') {
      await _delete(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<ExpenseModel>>{};
    for (final item in _items) {
      final key = '${item.date.year}-${item.date.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => <ExpenseModel>[]).add(item);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiêu'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ExpenseSearchFilterScreen(
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
          ? const Center(child: Text('Chưa có chi tiêu nào.'))
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
                          child: Icon(Icons.shopping_bag_outlined),
                        ),
                        onLongPress: () => _showItemActions(item),
                        title: Text(
                          (item.description != null &&
                                  item.description!.trim().isNotEmpty)
                              ? item.description!
                              : (_categoryNameById[item.categoryId] ??
                                    item.categoryName ??
                                    'Giao dich'),
                        ),
                        subtitle: Text(
                          '${formatDate(item.date)} · ${formatDateTime(item.createdAt).split(' ').last}',
                        ),
                        trailing: Text(
                          formatVnd(item.amount),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
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
          await _openExpensePopup();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
