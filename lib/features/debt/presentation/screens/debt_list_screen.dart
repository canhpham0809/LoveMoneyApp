import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_app_demo/core/theme/app_colors.dart';
import 'package:flutter_app_demo/core/utils/amount_input.dart';
import 'package:flutter_app_demo/core/widgets/amount_suggestion_chips.dart';
import 'package:flutter_app_demo/core/widgets/busy_overlay.dart';
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

class _DebtFormPayload {
  final String debtTypeId;
  final String debtKind;
  final bool recordToIncome;
  final bool recordToExpense;
  final String name;
  final double originalAmount;
  final String creditorName;
  final DateTime startDate;
  final DateTime? dueDate;
  final String? note;

  const _DebtFormPayload({
    required this.debtTypeId,
    required this.debtKind,
    required this.recordToIncome,
    required this.recordToExpense,
    required this.name,
    required this.originalAmount,
    required this.creditorName,
    required this.startDate,
    required this.dueDate,
    required this.note,
  });
}

class _DebtListScreenState extends State<DebtListScreen> {
  static const int _pageSize = 50;

  final _service = DebtService();
  final ScrollController _scrollController = ScrollController();
  List<DebtModel> _items = [];
  List<String> _manualOrderIds = [];
  Map<String, String> _memberNameById = {};
  String _selectedDebtKind = 'debt';
  int _currentOffset = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool _isLoading = true;
  bool _isMutating = false;
  String? _error;

  Future<T> _runMutation<T>(Future<T> Function() action) async {
    if (mounted) {
      setState(() => _isMutating = true);
    }
    try {
      return await action();
    } finally {
      if (mounted) {
        setState(() => _isMutating = false);
      }
    }
  }

  List<DebtModel> get _filteredItems =>
      _items.where((item) => item.debtKind == _selectedDebtKind).toList();

  String _resolveMemberName(String? userId) {
    if (userId == null || userId.isEmpty) return 'Không rõ';
    return _memberNameById[userId] ?? userId;
  }

  void _sortDebtsByDueDate(List<DebtModel> items) {
    items.sort((a, b) {
      if (a.dueDate == null && b.dueDate == null) return 0;
      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;
      return a.dueDate!.compareTo(b.dueDate!);
    });
  }

  List<DebtModel> _applyDebtOrder(List<DebtModel> items) {
    final nextItems = List<DebtModel>.from(items);
    if (_manualOrderIds.isEmpty) {
      _sortDebtsByDueDate(nextItems);
      _manualOrderIds = nextItems.map((e) => e.id).toList();
      return nextItems;
    }

    final byId = {for (final item in nextItems) item.id: item};
    final ordered = <DebtModel>[];
    for (final id in _manualOrderIds) {
      final item = byId.remove(id);
      if (item != null) {
        ordered.add(item);
      }
    }
    final rest = byId.values.toList();
    _sortDebtsByDueDate(rest);
    ordered.addAll(rest);
    _manualOrderIds = ordered.map((e) => e.id).toList();
    return ordered;
  }

  void _onReorder(int oldIndex, int newIndex) {
    final visibleItems = _filteredItems;
    if (visibleItems.length < 2) return;

    final previousOrder = List<String>.from(_manualOrderIds);
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }

      final visibleIds = visibleItems.map((e) => e.id).toList();
      final movedId = visibleIds.removeAt(oldIndex);
      visibleIds.insert(newIndex, movedId);

      final reorderedVisibleItems = visibleIds
          .map((id) => visibleItems.firstWhere((item) => item.id == id))
          .toList();

      var visibleIndex = 0;
      _items = _items.map((item) {
        if (item.debtKind == _selectedDebtKind) {
          return reorderedVisibleItems[visibleIndex++];
        }
        return item;
      }).toList();

      _manualOrderIds = _items.map((e) => e.id).toList();
    });
    unawaited(_persistDebtOrder(previousOrder));
  }

  Future<void> _persistDebtOrder(List<String> previousOrder) async {
    try {
      await _runMutation(
        () => _service.updateDebtOrder(_items.map((e) => e.id).toList()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _manualOrderIds = previousOrder;
        _items = _applyDebtOrder(_items);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Khong luu duoc thu tu no: $e')));
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    widget.refreshSignal?.removeListener(_onExternalRefresh);
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMore) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 220) {
      _loadMore();
    }
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
      existing?.debtKind ?? _selectedDebtKind,
    );
    final shouldRecordToIncome = ValueNotifier<bool>(
      existing?.recordToIncome ?? false,
    );
    final shouldRecordToExpense = ValueNotifier<bool>(
      existing?.linkedExpenseId != null,
    );
    DateTime startDate = existing?.startDate ?? DateTime.now();
    DateTime? dueDate = existing?.dueDate;
    var isClosingDialog = false;
    if (existing != null) {
      personCtrl.text = existing.name;
      amountCtrl.text = formatAmountInput(
        existing.originalAmount.toStringAsFixed(0),
      );
      noteCtrl.text = existing.note ?? '';
    }

    final payload = await showDialog<_DebtFormPayload>(
      context: context,
      builder: (dialogContext) {
        final media = MediaQuery.of(dialogContext).size;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 20,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 520,
                maxHeight: media.height * 0.85,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        existing == null ? 'Thêm nợ' : 'Sửa nợ',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: personCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Người liên quan',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          ThousandsSeparatorInputFormatter(),
                        ],
                        decoration: const InputDecoration(hintText: 'Số tiền'),
                      ),
                      AmountSuggestionChips(
                        controller: amountCtrl,
                        onSelected: (value) {
                          amountCtrl.text = formatAmountInput(value.toString());
                        },
                      ),
                      const SizedBox(height: 8),
                      ValueListenableBuilder<String>(
                        valueListenable: selectedDebtTypeId,
                        builder: (_, value, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Loại nợ'),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: debtTypes
                                  .map(
                                    (item) => ChoiceChip(
                                      label: Text(
                                        item['name'] as String,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 0,
                                      ),
                                      visualDensity: const VisualDensity(
                                        horizontal: -4,
                                        vertical: -4,
                                      ),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      showCheckmark: false,
                                      selected: value == item['id'] as String,
                                      onSelected: (_) {
                                        selectedDebtTypeId.value =
                                            item['id'] as String;
                                      },
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ValueListenableBuilder<String>(
                        valueListenable: selectedDebtKind,
                        builder: (_, value, _) => Row(
                          children: [
                            GestureDetector(
                              onTap: () => selectedDebtKind.value = 'debt',
                              child: Row(
                                children: [
                                  Radio<String>(
                                    value: 'debt',
                                    groupValue: value,
                                    visualDensity: const VisualDensity(
                                      horizontal: -4,
                                      vertical: -4,
                                    ),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    onChanged: (v) {
                                      if (v != null) selectedDebtKind.value = v;
                                    },
                                  ),
                                  const Text('Nợ'),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: () => selectedDebtKind.value = 'lend',
                              child: Row(
                                children: [
                                  Radio<String>(
                                    value: 'lend',
                                    groupValue: value,
                                    visualDensity: const VisualDensity(
                                      horizontal: -4,
                                      vertical: -4,
                                    ),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    onChanged: (v) {
                                      if (v != null) selectedDebtKind.value = v;
                                    },
                                  ),
                                  const Text('Cho mượn'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ValueListenableBuilder<String>(
                        valueListenable: selectedDebtKind,
                        builder: (_, debtKind, child) {
                          if (debtKind == 'lend') {
                            return ValueListenableBuilder<bool>(
                              valueListenable: shouldRecordToExpense,
                              builder: (_, value, child) => CheckboxListTile(
                                dense: true,
                                visualDensity: const VisualDensity(
                                  horizontal: -2,
                                  vertical: -2,
                                ),
                                contentPadding: EdgeInsets.zero,
                                value: value,
                                onChanged: (v) {
                                  shouldRecordToExpense.value = v ?? false;
                                },
                                title: const Text('Ghi nhan vao Chi'),
                              ),
                            );
                          }
                          return ValueListenableBuilder<bool>(
                            valueListenable: shouldRecordToIncome,
                            builder: (_, value, child) => CheckboxListTile(
                              dense: true,
                              visualDensity: const VisualDensity(
                                horizontal: -2,
                                vertical: -2,
                              ),
                              contentPadding: EdgeInsets.zero,
                              value: value,
                              onChanged: (v) {
                                shouldRecordToIncome.value = v ?? false;
                              },
                              title: const Text('Ghi nhan vao Thu'),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: noteCtrl,
                        maxLines: 2,
                        minLines: 2,
                        decoration: const InputDecoration(hintText: 'Ghi chú'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate: startDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setDialogState(() => startDate = picked);
                          }
                        },
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text('Ngày phát sinh: ${formatDate(startDate)}'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate: dueDate ?? startDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setDialogState(() => dueDate = picked);
                          }
                        },
                        icon: const Icon(Icons.event_outlined),
                        label: Text(
                          dueDate == null
                              ? 'Chọn hạn thanh toán'
                              : 'Hạn: ${formatDate(dueDate!)}',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                if (isClosingDialog) return;
                                isClosingDialog = true;
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (!dialogContext.mounted) return;
                                  Navigator.of(dialogContext).maybePop();
                                });
                              },
                              child: const Text('Hủy'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: () async {
                                if (isClosingDialog) return;
                                final amount = parseAmountInput(
                                  amountCtrl.text.trim(),
                                );
                                if (personCtrl.text.trim().isEmpty ||
                                    amount == null ||
                                    amount <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Nhập đủ thông tin hợp lệ.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                final uid = Supabase
                                    .instance
                                    .client
                                    .auth
                                    .currentUser
                                    ?.id;
                                if (uid == null) {
                                  ScaffoldMessenger.of(
                                    dialogContext,
                                  ).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Không tìm thấy phiên đăng nhập.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                isClosingDialog = true;
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (!dialogContext.mounted) return;
                                  Navigator.of(dialogContext).maybePop(
                                    _DebtFormPayload(
                                      debtTypeId: selectedDebtTypeId.value,
                                      debtKind: selectedDebtKind.value,
                                      recordToIncome:
                                          selectedDebtKind.value == 'debt'
                                          ? shouldRecordToIncome.value
                                          : false,
                                      recordToExpense:
                                          selectedDebtKind.value == 'lend'
                                          ? shouldRecordToExpense.value
                                          : false,
                                      name: personCtrl.text.trim(),
                                      originalAmount: amount,
                                      creditorName: personCtrl.text.trim(),
                                      startDate: startDate,
                                      dueDate: dueDate,
                                      note: noteCtrl.text.trim().isEmpty
                                          ? null
                                          : noteCtrl.text.trim(),
                                    ),
                                  );
                                });
                              },
                              child: const Text('Lưu'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    selectedDebtTypeId.dispose();
    selectedDebtKind.dispose();
    shouldRecordToIncome.dispose();
    shouldRecordToExpense.dispose();

    if (payload == null) return;

    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy phiên đăng nhập.')),
      );
      return;
    }

    try {
      await _runMutation(() async {
        if (existing == null) {
          final created = await _service.createDebt(
            coupleId: widget.coupleId,
            userId: uid,
            debtTypeId: payload.debtTypeId,
            debtKind: payload.debtKind,
            recordToIncome: payload.recordToIncome,
            recordToExpense: payload.recordToExpense,
            name: payload.name,
            originalAmount: payload.originalAmount,
            creditorName: payload.creditorName,
            startDate: payload.startDate,
            dueDate: payload.dueDate,
            note: payload.note,
          );
          if (!mounted) return;
          setState(() {
            _items.insert(0, created);
            _manualOrderIds.remove(created.id);
            _manualOrderIds.insert(0, created.id);
            _items = _applyDebtOrder(_items);
          });
        } else {
          await _service.updateDebt(
            debtId: existing.id,
            debtTypeId: payload.debtTypeId,
            debtKind: payload.debtKind,
            recordToIncome: payload.recordToIncome,
            recordToExpense: payload.recordToExpense,
            name: payload.name,
            originalAmount: payload.originalAmount,
            creditorName: payload.creditorName,
            startDate: payload.startDate,
            dueDate: payload.dueDate,
            note: payload.note,
          );
          final refreshed = await _service.getDebtById(existing.id);
          if (!mounted) return;
          setState(() {
            final idx = _items.indexWhere((e) => e.id == existing.id);
            if (idx >= 0) {
              _items[idx] = refreshed;
            }
            _items = _applyDebtOrder(_items);
          });
        }
        widget.onDataChanged?.call();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi lưu: $e')));
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
              dense: true,
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Chỉnh sửa'),
              onTap: () => Navigator.pop(sheetContext, 'edit'),
            ),
            ListTile(
              dense: true,
              visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Xóa'),
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
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Xác nhận xóa khoản nợ'),
          content: const Text(
            'Nếu thực hiện xóa khoản Nợ này, tất cả các giao dịch đã phát sinh trước đó đều sẽ bị xóa.',
          ),
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

      await _runMutation(() async {
        await _service.deleteDebt(item.id);
        if (mounted) {
          setState(() {
            _items.removeWhere((d) => d.id == item.id);
            _manualOrderIds.remove(item.id);
          });
        }
        widget.onDataChanged?.call();
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await _service.getDebts(
        widget.coupleId,
        limit: _pageSize,
        offset: 0,
      );
      final userIds = items.map((item) => item.userId).toSet().toList();
      final userNameById = <String, String>{};
      if (userIds.isNotEmpty) {
        final rows = List<Map<String, dynamic>>.from(
          await Supabase.instance.client
              .from('users')
              .select('id, display_name, email')
              .inFilter('id', userIds),
        );
        for (final row in rows) {
          final id = row['id'] as String?;
          if (id == null || id.isEmpty) continue;
          final displayName = (row['display_name'] as String?)?.trim();
          final email = (row['email'] as String?)?.trim();
          userNameById[id] = (displayName != null && displayName.isNotEmpty)
              ? displayName
              : ((email != null && email.isNotEmpty) ? email : id);
        }
      }
      if (mounted) {
        setState(() {
          _items = _applyDebtOrder(items);
          _memberNameById = userNameById;
          _currentOffset = items.length;
          _hasMore = items.length == _pageSize;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);
    try {
      final nextItems = await _service.getDebts(
        widget.coupleId,
        limit: _pageSize,
        offset: _currentOffset,
      );
      if (!mounted) return;

      if (nextItems.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoadingMore = false;
        });
        return;
      }

      final merged = _applyDebtOrder([..._items, ...nextItems]);
      final userIds = merged.map((item) => item.userId).toSet().toList();
      final userNameById = <String, String>{};
      if (userIds.isNotEmpty) {
        final rows = List<Map<String, dynamic>>.from(
          await Supabase.instance.client
              .from('users')
              .select('id, display_name, email')
              .inFilter('id', userIds),
        );
        for (final row in rows) {
          final id = row['id'] as String?;
          if (id == null || id.isEmpty) continue;
          final displayName = (row['display_name'] as String?)?.trim();
          final email = (row['email'] as String?)?.trim();
          userNameById[id] = (displayName != null && displayName.isNotEmpty)
              ? displayName
              : ((email != null && email.isNotEmpty) ? email : id);
        }
      }

      if (mounted) {
        setState(() {
          _items = merged;
          _memberNameById = userNameById;
          _currentOffset = _items.length;
          _hasMore = nextItems.length == _pageSize;
          _isLoadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _filteredItems;
    final totalDebtOwed = _items
        .where((item) => item.debtKind == 'debt')
        .fold<double>(0, (sum, item) => sum + item.remainingAmount);
    final totalLentOut = _items
        .where((item) => item.debtKind == 'lend')
        .fold<double>(0, (sum, item) => sum + item.remainingAmount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Khoản nợ và cho mượn'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: BusyOverlay(
        isVisible: _isMutating,
        message: 'Đang xử lý...',
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _load,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: _DebtSummaryCard(
                            title: 'Tổng tiền đang nợ',
                            amountText: formatVnd(totalDebtOwed),
                            selected: _selectedDebtKind == 'debt',
                            onTap: () {
                              setState(() => _selectedDebtKind = 'debt');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _DebtSummaryCard(
                            title: 'Tổng tiền cho nợ',
                            amountText: formatVnd(totalLentOut),
                            selected: _selectedDebtKind == 'lend',
                            onTap: () {
                              setState(() => _selectedDebtKind = 'lend');
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (visibleItems.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          _selectedDebtKind == 'debt'
                              ? 'Chưa có khoản đang nợ nào.'
                              : 'Chưa có khoản cho nợ nào.',
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ReorderableListView.builder(
                        scrollController: _scrollController,
                        padding: const EdgeInsets.fromLTRB(0, 4, 0, 80),
                        itemCount: visibleItems.length,
                        onReorder: _hasMore ? (_, _) {} : _onReorder,
                        buildDefaultDragHandles: false,
                        itemBuilder: (context, index) {
                          final item = visibleItems[index];
                          final isLend = item.debtKind == 'lend';
                          final pct = item.originalAmount > 0
                              ? 1 - (item.remainingAmount / item.originalAmount)
                              : 1.0;
                          final accentColor = item.isClosed
                              ? AppColors.success
                              : (isLend
                                    ? AppColors.tealDeep
                                    : AppColors.danger);
                          final accentSoft = item.isClosed
                              ? AppColors.successSoft
                              : (isLend
                                    ? AppColors.tealSoft
                                    : AppColors.dangerSoft);
                          final leadingIcon = item.isClosed
                              ? Icons.check_circle_outline
                              : (isLend
                                    ? Icons.account_balance_wallet_outlined
                                    : Icons.credit_card_outlined);
                          return Container(
                            key: ValueKey(item.id),
                            margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
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
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            height: 56,
                                            width: 56,
                                            decoration: BoxDecoration(
                                              color: accentSoft,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Icon(
                                              leadingIcon,
                                              color: accentColor,
                                              size: 26,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Text(
                                              item.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 18,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            formatVnd(item.originalAmount),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                              color: accentColor,
                                            ),
                                          ),
                                          if (!_hasMore)
                                            ReorderableDragStartListener(
                                              index: index,
                                              child: const Padding(
                                                padding: EdgeInsets.only(
                                                  left: 8,
                                                ),
                                                child: Icon(
                                                  Icons.drag_indicator,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        child: LinearProgressIndicator(
                                          value: pct.clamp(0.0, 1.0),
                                          minHeight: 10,
                                          backgroundColor: accentSoft,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                accentColor,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Tiến độ: ${(pct.clamp(0.0, 1.0) * 100).toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: accentColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Còn lại: ${formatVnd(item.remainingAmount)}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (item.dueDate != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: Text(
                                            'Hạn: ${formatDate(item.dueDate!)}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(
                                          'Người tạo: ${_resolveMemberName(item.userId)}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  if (_isLoadingMore)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (!_hasMore)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Center(
                        child: Text(
                          'Đã tải hết trang.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                    ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openDebtPopup,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _DebtSummaryCard extends StatelessWidget {
  final String title;
  final String amountText;
  final bool selected;
  final VoidCallback onTap;

  const _DebtSummaryCard({
    required this.title,
    required this.amountText,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: selected
            ? AppColors.tealSoft.withValues(alpha: 0.32)
            : Colors.white,
        border: Border.all(
          color: selected ? AppColors.tealDeep : AppColors.border,
          width: selected ? 1.6 : 1,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: selected ? AppColors.tealDeep : Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  amountText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: selected ? AppColors.tealDeep : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
