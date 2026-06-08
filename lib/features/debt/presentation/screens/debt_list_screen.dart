import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final double prePaidPrincipal;

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
    this.prePaidPrincipal = 0.0,
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
  bool _hideCompleted = false;

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

  List<DebtModel> get _filteredItems {
    var list = _items.where((item) => item.debtKind == _selectedDebtKind);
    if (_hideCompleted) {
      list = list.where((item) => !(item.remainingAmount <= 0 || item.isClosed));
    }
    return list.toList();
  }

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

    final incomplete = ordered.where((item) => !(item.remainingAmount <= 0 || item.isClosed)).toList();
    final completed = ordered.where((item) => item.remainingAmount <= 0 || item.isClosed).toList();
    final result = [...incomplete, ...completed];

    _manualOrderIds = result.map((e) => e.id).toList();
    return result;
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
      _items = _applyDebtOrder(_items);
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

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _hideCompleted = prefs.getBool('hide_completed_debts') ?? false;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleHideCompleted(bool value) async {
    setState(() {
      _hideCompleted = value;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hide_completed_debts', value);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    widget.refreshSignal?.addListener(_onExternalRefresh);
    _loadSettings();
    _load();
  }

  @override
  void didUpdateWidget(covariant DebtListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      oldWidget.refreshSignal?.removeListener(_onExternalRefresh);
      widget.refreshSignal?.addListener(_onExternalRefresh);
    }
    _loadSettings();
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
    final payload = await showGeneralDialog<_DebtFormPayload>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, anim1, anim2) => _DebtFormDialog(
        coupleId: widget.coupleId,
        defaultDebtKind: _selectedDebtKind,
        existing: existing,
      ),
    );

    if (payload == null) return;

    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

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
          // Adjust remaining_amount for pre-paid periods
          DebtModel effectiveDebt = created;
          if (payload.prePaidPrincipal > 0) {
            final newRemaining = (payload.originalAmount - payload.prePaidPrincipal).clamp(0.0, payload.originalAmount);
            await Supabase.instance.client
                .from('debts')
                .update({'remaining_amount': newRemaining})
                .eq('id', created.id);
            effectiveDebt = await _service.getDebtById(created.id);
          }
          if (!mounted) return;
          setState(() {
            _items.insert(0, effectiveDebt);
            _manualOrderIds.remove(effectiveDebt.id);
            _manualOrderIds.insert(0, effectiveDebt.id);
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
    if (!mounted) return;
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
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Khoản nợ và cho mượn'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Tùy chọn',
            onSelected: (value) {
              if (value == 'toggle_hide_completed') {
                _toggleHideCompleted(!_hideCompleted);
              }
            },
            itemBuilder: (BuildContext context) => [
              CheckedPopupMenuItem<String>(
                value: 'toggle_hide_completed',
                checked: _hideCompleted,
                child: const Text('Ẩn nợ đã trả hoàn tất'),
              ),
            ],
          ),
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
                        footer: (!_hasMore)
                            ? const Padding(
                                key: ValueKey('footer'),
                                padding: EdgeInsets.only(bottom: 24, top: 12),
                                child: Center(
                                  child: Text(
                                    'Đã tải hết trang.',
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                ),
                              )
                            : null,
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

                                child: Stack(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.isSplitBill
                                                      ? '${item.name} (Chia tiền)'
                                                      : item.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 18,
                                                  ),
                                                ),
                                                if (item.isSplitBill) ...[
                                                  const SizedBox(height: 4),
                                                  Builder(
                                                    builder: (context) {
                                                      final info = item.splitBillInfo!;
                                                      final unpaid = info.shares
                                                          .where((s) => !s.paid)
                                                          .map((s) => s.name)
                                                          .toList();
                                                      if (unpaid.isEmpty) {
                                                        return const Text(
                                                          'Đã trả hết',
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            color: AppColors.success,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        );
                                                      }
                                                      return Text(
                                                        'Chưa trả: ${unpaid.join(", ")}',
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          color: AppColors.danger,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ],
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
                                  Positioned(
                                    bottom: 0,
                                    right: 4,
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 20,
                                        color: Colors.black45,
                                      ),
                                      onPressed: () => _showDebtActions(item),
                                    ),
                                  ),
                                ],
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

                ],
              ),
      ),
      floatingActionButton: LayoutBuilder(
        builder: (context, constraints) {
          final isLarge = MediaQuery.sizeOf(context).width > 800;
          if (isLarge) {
            return FloatingActionButton.extended(
              onPressed: _openDebtPopup,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Thêm nợ',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              backgroundColor: AppColors.tealDeep,
              foregroundColor: Colors.white,
            );
          }
          return FloatingActionButton(
            onPressed: _openDebtPopup,
            child: const Icon(Icons.add),
          );
        },
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

class _DebtFormDialog extends StatefulWidget {
  final String coupleId;
  final String defaultDebtKind;
  final DebtModel? existing;

  const _DebtFormDialog({
    required this.coupleId,
    required this.defaultDebtKind,
    this.existing,
  });

  @override
  State<_DebtFormDialog> createState() => _DebtFormDialogState();
}

class _DebtFormDialogState extends State<_DebtFormDialog> {
  final _service = DebtService();
  final _personCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _peopleCountCtrl = TextEditingController(text: '2');
  List<TextEditingController> _shareNameControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  // Bank loan fields
  bool _isBankLoan = false;
  final _monthsCtrl = TextEditingController(text: '360');
  final _repaymentDayCtrl = TextEditingController(text: '15');
  final _startingPeriodCtrl = TextEditingController(text: '1');
  List<Map<String, dynamic>> _interestPeriods = [];

  List<Map<String, dynamic>> _debtTypes = [];
  bool _isLoading = true;
  String? _selectedDebtTypeId;
  String _selectedDebtKind = 'debt';
  bool _shouldRecordToIncome = false;
  bool _shouldRecordToExpense = false;
  bool _isSplitBill = false;
  late DateTime _startDate;
  DateTime? _dueDate;

  void _updateInterestRulesSequencing() {
    var nextFrom = 1;
    for (var i = 0; i < _interestPeriods.length; i++) {
      _interestPeriods[i]['from'] = nextFrom;
      final to = _interestPeriods[i]['to'] as int? ?? nextFrom + 11;
      if (to < nextFrom) {
        _interestPeriods[i]['to'] = nextFrom + 11;
      }
      nextFrom = (_interestPeriods[i]['to'] as int) + 1;
    }
  }

  @override
  void initState() {
    super.initState();
    _startDate = widget.existing?.startDate ?? DateTime.now();
    _dueDate = widget.existing?.dueDate;
    _selectedDebtKind = widget.existing?.debtKind ?? widget.defaultDebtKind;
    _shouldRecordToIncome = widget.existing?.recordToIncome ?? false;
    _shouldRecordToExpense = widget.existing?.linkedExpenseId != null;

    if (widget.existing != null) {
      final isBank = widget.existing!.isBankLoan;
      _isBankLoan = isBank;
      if (isBank) {
        final info = widget.existing!.bankLoanInfo!;
        _personCtrl.text = widget.existing!.name;
        _amountCtrl.text = formatAmountInput(
          widget.existing!.originalAmount.toStringAsFixed(0),
        );
        _monthsCtrl.text = info.totalMonths.toString();
        _repaymentDayCtrl.text = info.repaymentDay.toString();
        _interestPeriods = info.interestRules.map((rule) {
          return {
            'from': rule.fromMonth,
            'to': rule.toMonth,
            'rateCtrl': TextEditingController(text: rule.rate.toString()),
          };
        }).toList();
        _noteCtrl.text = widget.existing!.displayNote ?? '';
      } else {
        final isSplit = widget.existing!.isSplitBill;
        _isSplitBill = isSplit;
        if (isSplit) {
          final info = widget.existing!.splitBillInfo!;
          _personCtrl.text = widget.existing!.name;
          _amountCtrl.text = formatAmountInput(info.totalBill.toStringAsFixed(0));
          _peopleCountCtrl.text = info.peopleCount.toString();
          _noteCtrl.text = info.userNote ?? '';
          _shareNameControllers = info.shares
              .map((s) => TextEditingController(text: s.name))
              .toList();
        } else {
          _personCtrl.text = widget.existing!.name;
          _amountCtrl.text = formatAmountInput(
            widget.existing!.originalAmount.toStringAsFixed(0),
          );
          _noteCtrl.text = widget.existing!.displayNote ?? '';
        }
      }
    } else {
      _interestPeriods = [
        {'from': 1, 'to': 12, 'rateCtrl': TextEditingController(text: '5.8')},
        {'from': 13, 'to': 24, 'rateCtrl': TextEditingController(text: '6.8')},
        {'from': 25, 'to': 360, 'rateCtrl': TextEditingController(text: '10.0')},
      ];
    }

    _loadData();
  }

  void _onPeopleCountChanged(String value) {
    final count = int.tryParse(value) ?? 0;
    if (count < 1) {
      setState(() {
        _shareNameControllers = [];
      });
      return;
    }
    final needed = count;
    setState(() {
      if (_shareNameControllers.length < needed) {
        while (_shareNameControllers.length < needed) {
          _shareNameControllers.add(TextEditingController());
        }
      } else if (_shareNameControllers.length > needed) {
        while (_shareNameControllers.length > needed) {
          final ctrl = _shareNameControllers.removeLast();
          ctrl.dispose();
        }
      }
    });
  }

  Future<void> _loadData() async {
    try {
      final types = await _service.getDebtTypes(widget.coupleId);
      if (mounted) {
        setState(() {
          _debtTypes = List<Map<String, dynamic>>.from(types);
          if (_debtTypes.isNotEmpty) {
            _selectedDebtTypeId = widget.existing?.debtTypeId ?? (_debtTypes.first['id'] as String);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải loại nợ: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _personCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _peopleCountCtrl.dispose();
    _monthsCtrl.dispose();
    _repaymentDayCtrl.dispose();
    _startingPeriodCtrl.dispose();
    for (final ctrl in _shareNameControllers) {
      ctrl.dispose();
    }
    for (final period in _interestPeriods) {
      (period['rateCtrl'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);

    return Dialog(
      alignment: Alignment.center,
      insetAnimationDuration: Duration.zero,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: media.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null ? 'Thêm nợ' : 'Sửa nợ',
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_selectedDebtKind == 'debt' && widget.existing == null) ...[
                        SwitchListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Vay trả góp ngân hàng'),
                          subtitle: const Text('Tính gốc lãi, phí phạt & lịch trả nợ'),
                          value: _isBankLoan,
                          onChanged: (v) {
                            setState(() {
                              _isBankLoan = v;
                              if (v) {
                                _personCtrl.text = _personCtrl.text.isEmpty ? 'Ngân hàng' : _personCtrl.text;
                                _shouldRecordToIncome = true;
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (_selectedDebtKind == 'lend' && widget.existing == null) ...[
                        SwitchListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Chia tiền (Split bill)'),
                          value: _isSplitBill,
                          onChanged: (v) {
                            setState(() {
                              _isSplitBill = v;
                              if (v) {
                                _personCtrl.text = '';
                                _onPeopleCountChanged(_peopleCountCtrl.text);
                              } else {
                                for (final c in _shareNameControllers) {
                                  c.dispose();
                                }
                                _shareNameControllers = [];
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                      TextField(
                        controller: _personCtrl,
                        decoration: InputDecoration(
                          hintText: _isSplitBill
                              ? 'Tên hoạt động / Sự kiện (Ví dụ: Ăn uống, xem phim)'
                              : 'Người liên quan',
                          labelText: _isSplitBill ? 'Tên hoạt động / Sự kiện' : 'Người liên quan',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _amountCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          ThousandsSeparatorInputFormatter(),
                        ],
                        decoration: InputDecoration(
                          hintText: _isSplitBill ? 'Tổng tiền hóa đơn' : 'Số tiền',
                          labelText: _isSplitBill ? 'Tổng tiền hóa đơn' : 'Số tiền',
                        ),
                      ),
                      AmountSuggestionChips(
                        controller: _amountCtrl,
                        onSelected: (value) {
                          _amountCtrl.text = formatAmountInput(value.toString());
                        },
                      ),
                      if (_isBankLoan) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _monthsCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: const InputDecoration(
                                  labelText: 'Kỳ hạn vay (tháng)',
                                  hintText: 'Ví dụ: 360',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _repaymentDayCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: const InputDecoration(
                                  labelText: 'Ngày thanh toán hàng tháng',
                                  hintText: 'Ví dụ: 15',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _startingPeriodCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            labelText: 'Kỳ hiện tại đang chờ thanh toán',
                            hintText: 'Ví dụ: 1 (nếu chưa trả kỳ nào), hoặc 5 (đã trả 4 kỳ)',
                            helperText: 'Hệ thống sẽ đánh dấu các kỳ trước là đã thanh toán',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Cấu hình Lãi suất theo thời gian:',
                          style: GoogleFonts.roboto(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _interestPeriods.length,
                          itemBuilder: (context, index) {
                            final period = _interestPeriods[index];
                            final from = period['from'] as int;
                            final rateCtrl = period['rateCtrl'] as TextEditingController;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                children: [
                                  Text('Tháng $from - ', style: const TextStyle(fontSize: 13)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      decoration: const InputDecoration(
                                        labelText: 'Đến tháng',
                                        isDense: true,
                                      ),
                                      controller: TextEditingController(text: period['to']?.toString() ?? '')
                                        ..addListener(() {
                                          // Keep value
                                        }),
                                      onChanged: (val) {
                                        final valInt = int.tryParse(val) ?? (period['to'] as int? ?? 0);
                                        period['to'] = valInt;
                                        _updateInterestRulesSequencing();
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: rateCtrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        labelText: 'Lãi suất % / năm',
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  if (_interestPeriods.length > 1)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () {
                                        setState(() {
                                          final removed = _interestPeriods.removeAt(index);
                                          (removed['rateCtrl'] as TextEditingController).dispose();
                                          _updateInterestRulesSequencing();
                                        });
                                      },
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              final lastTo = _interestPeriods.isNotEmpty
                                  ? (_interestPeriods.last['to'] as int? ?? 0)
                                  : 0;
                              final totalMonths = int.tryParse(_monthsCtrl.text) ?? 360;
                              _interestPeriods.add({
                                'from': lastTo + 1,
                                'to': totalMonths,
                                'rateCtrl': TextEditingController(text: '10.0'),
                              });
                            });
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Thêm khoảng lãi suất', style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (_isSplitBill) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: _peopleCountCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onChanged: _onPeopleCountChanged,
                          enabled: widget.existing == null,
                          decoration: const InputDecoration(
                            hintText: 'Số người chia',
                            labelText: 'Số người chia',
                          ),
                        ),
                        Builder(
                          builder: (context) {
                            final total = parseAmountInput(_amountCtrl.text.trim()) ?? 0;
                            final count = int.tryParse(_peopleCountCtrl.text.trim()) ?? 0;
                            final share = count > 0 ? total / count : 0.0;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                              child: Text(
                                'Mỗi người chia: ${formatVnd(share)} (${count > 0 ? "$count người" : ""})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.tealDeep,
                                ),
                              ),
                              );
                            },
                          ),
                        ...List.generate(_shareNameControllers.length, (index) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: TextField(
                              controller: _shareNameControllers[index],
                              enabled: widget.existing == null,
                              decoration: InputDecoration(
                                hintText: 'Tên người thứ ${index + 1}',
                                labelText: 'Người thứ ${index + 1}',
                              ),
                            ),
                          );
                        }),
                      ],
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Loại nợ'),
                      ),
                      const SizedBox(height: 8),
                      if (_isLoading)
                        const SizedBox(
                          height: 60,
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_debtTypes.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Chưa có loại nợ. Vui lòng tạo loại nợ trước.',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _debtTypes.map((item) {
                            final isSelected = _selectedDebtTypeId == item['id'] as String;
                            final theme = Theme.of(context);
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedDebtTypeId = item['id'] as String;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? theme.colorScheme.primaryContainer
                                      : theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Text(
                                  item['name'] as String,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 8),
                      if (_selectedDebtKind == 'lend')
                        CheckboxListTile(
                          dense: true,
                          visualDensity: const VisualDensity(
                            horizontal: -2,
                            vertical: -2,
                          ),
                          contentPadding: EdgeInsets.zero,
                          value: _shouldRecordToExpense,
                          onChanged: (v) {
                            setState(() {
                              _shouldRecordToExpense = v ?? false;
                            });
                          },
                          title: const Text('Ghi nhận vào Chi'),
                        )
                      else
                        CheckboxListTile(
                          dense: true,
                          visualDensity: const VisualDensity(
                            horizontal: -2,
                            vertical: -2,
                          ),
                          contentPadding: EdgeInsets.zero,
                          value: _shouldRecordToIncome,
                          onChanged: (v) {
                            setState(() {
                              _shouldRecordToIncome = v ?? false;
                            });
                          },
                          title: const Text('Ghi nhận vào Thu'),
                        ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _noteCtrl,
                        decoration: const InputDecoration(hintText: 'Ghi chú'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _startDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => _startDate = picked);
                          }
                        },
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text('Ngày phát sinh: ${formatDate(_startDate)}'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dueDate ?? _startDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => _dueDate = picked);
                          }
                        },
                        icon: const Icon(Icons.event_outlined),
                        label: Text(
                          _dueDate == null
                              ? 'Chọn hạn thanh toán'
                              : 'Hạn: ${formatDate(_dueDate!)}',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).maybePop();
                      },
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: (_isLoading || _debtTypes.isEmpty)
                          ? null
                          : () {
                              if (_isSplitBill) {
                                final total = parseAmountInput(_amountCtrl.text.trim());
                                final count = int.tryParse(_peopleCountCtrl.text.trim()) ?? 0;
                                if (_personCtrl.text.trim().isEmpty ||
                                    total == null ||
                                    total <= 0 ||
                                    count < 1) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Nhập đủ thông tin hợp lệ.'),
                                    ),
                                  );
                                  return;
                                }

                                for (var i = 0; i < _shareNameControllers.length; i++) {
                                  if (_shareNameControllers[i].text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Vui lòng nhập tên cho người thứ ${i + 1}.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                }

                                final shareAmount = total / count;
                                final originalAmount = total;
                                final creditorName = _shareNameControllers
                                    .map((c) => c.text.trim())
                                    .join(', ');

                                late String noteString;
                                if (widget.existing != null &&
                                    widget.existing!.isSplitBill) {
                                  final existingInfo = widget.existing!.splitBillInfo!;
                                  final updatedInfo = SplitBillInfo(
                                    totalBill: existingInfo.totalBill,
                                    peopleCount: existingInfo.peopleCount,
                                    shareAmount: existingInfo.shareAmount,
                                    userNote: _noteCtrl.text.trim().isEmpty
                                        ? null
                                        : _noteCtrl.text.trim(),
                                    shares: existingInfo.shares,
                                  );
                                  noteString = jsonEncode(updatedInfo.toJson());
                                } else {
                                  final info = SplitBillInfo(
                                    totalBill: total,
                                    peopleCount: count,
                                    shareAmount: shareAmount,
                                    userNote: _noteCtrl.text.trim().isEmpty
                                        ? null
                                        : _noteCtrl.text.trim(),
                                    shares: _shareNameControllers
                                        .map(
                                          (c) => SplitShare(
                                            name: c.text.trim(),
                                            paid: false,
                                          ),
                                        )
                                        .toList(),
                                  );
                                  noteString = jsonEncode(info.toJson());
                                }

                                Navigator.of(context).maybePop(
                                  _DebtFormPayload(
                                    debtTypeId: _selectedDebtTypeId!,
                                    debtKind: _selectedDebtKind,
                                    recordToIncome: false,
                                    recordToExpense: _selectedDebtKind == 'lend'
                                        ? _shouldRecordToExpense
                                        : false,
                                    name: _personCtrl.text.trim(),
                                    originalAmount: originalAmount,
                                    creditorName: creditorName,
                                    startDate: _startDate,
                                    dueDate: _dueDate,
                                    note: noteString,
                                  ),
                                );
                              } else if (_isBankLoan) {
                                final total = parseAmountInput(_amountCtrl.text.trim());
                                final totalMonths = int.tryParse(_monthsCtrl.text.trim()) ?? 0;
                                final repaymentDay = int.tryParse(_repaymentDayCtrl.text.trim()) ?? 0;

                                if (_personCtrl.text.trim().isEmpty ||
                                    total == null ||
                                    total <= 0 ||
                                    totalMonths <= 0 ||
                                    repaymentDay < 1 ||
                                    repaymentDay > 31) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Vui lòng nhập đầy đủ và hợp lệ các thông tin khoản vay.'),
                                    ),
                                  );
                                  return;
                                }

                                final rules = <InterestRateRule>[];
                                for (var i = 0; i < _interestPeriods.length; i++) {
                                  final from = _interestPeriods[i]['from'] as int;
                                  var to = _interestPeriods[i]['to'] as int? ?? totalMonths;
                                  final rateStr = (_interestPeriods[i]['rateCtrl'] as TextEditingController).text.trim();
                                  final rate = double.tryParse(rateStr) ?? 10.0;

                                  if (to < from) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Khoảng thời gian thứ ${i + 1} không hợp lệ (Tháng đến nhỏ hơn Tháng từ).'),
                                      ),
                                    );
                                    return;
                                  }

                                  if (i == _interestPeriods.length - 1 && to < totalMonths) {
                                    to = totalMonths;
                                  }

                                  rules.add(InterestRateRule(
                                    fromMonth: from,
                                    toMonth: to,
                                    rate: rate,
                                  ));
                                }

                                final startingPeriod = (int.tryParse(_startingPeriodCtrl.text.trim()) ?? 1).clamp(1, totalMonths);

                                var initialSchedule = DebtService.generateInitialSchedule(
                                  originalAmount: total,
                                  totalMonths: totalMonths,
                                  startDate: _startDate,
                                  repaymentDay: repaymentDay,
                                  interestRules: rules,
                                );

                                // Mark periods before startingPeriod as pre-paid
                                if (startingPeriod > 1) {
                                  initialSchedule = initialSchedule.map((item) {
                                    if (item.monthIndex < startingPeriod) {
                                      return item.copyWith(
                                        isPaid: true,
                                        paidAmount: item.principal + item.interest,
                                        paidDate: _startDate,
                                      );
                                    }
                                    return item;
                                  }).toList();
                                  // Recalculate remaining schedule from startingPeriod
                                  initialSchedule = DebtService.recalculateSchedule(
                                    originalAmount: total,
                                    totalMonths: totalMonths,
                                    startDate: _startDate,
                                    repaymentDay: repaymentDay,
                                    interestRules: rules,
                                    existingSchedule: initialSchedule,
                                  );
                                }

                                final bankLoan = BankLoanInfo(
                                  totalMonths: totalMonths,
                                  repaymentDay: repaymentDay,
                                  interestRules: rules,
                                  schedule: initialSchedule,
                                );

                                final noteString = jsonEncode(bankLoan.toJson());

                                // Compute total principal already paid in pre-paid periods
                                final prePaidPrincipal = startingPeriod > 1
                                    ? initialSchedule
                                        .where((item) => item.isPaid)
                                        .fold(0.0, (sum, item) => sum + item.principal)
                                    : 0.0;

                                Navigator.of(context).maybePop(
                                  _DebtFormPayload(
                                    debtTypeId: _selectedDebtTypeId!,
                                    debtKind: _selectedDebtKind,
                                    recordToIncome: _shouldRecordToIncome,
                                    recordToExpense: false,
                                    name: _personCtrl.text.trim(),
                                    originalAmount: total,
                                    creditorName: _personCtrl.text.trim(),
                                    startDate: _startDate,
                                    dueDate: initialSchedule.last.dueDate,
                                    note: noteString,
                                    prePaidPrincipal: prePaidPrincipal,
                                  ),
                                );
                              } else {
                                final amount = parseAmountInput(
                                  _amountCtrl.text.trim(),
                                );
                                if (_personCtrl.text.trim().isEmpty ||
                                    amount == null ||
                                    amount <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Nhập đủ thông tin hợp lệ.'),
                                    ),
                                  );
                                  return;
                                }
                                Navigator.of(context).maybePop(
                                  _DebtFormPayload(
                                    debtTypeId: _selectedDebtTypeId!,
                                    debtKind: _selectedDebtKind,
                                    recordToIncome: _selectedDebtKind == 'debt'
                                        ? _shouldRecordToIncome
                                        : false,
                                    recordToExpense: _selectedDebtKind == 'lend'
                                        ? _shouldRecordToExpense
                                        : false,
                                    name: _personCtrl.text.trim(),
                                    originalAmount: amount,
                                    creditorName: _personCtrl.text.trim(),
                                    startDate: _startDate,
                                    dueDate: _dueDate,
                                    note: _noteCtrl.text.trim().isEmpty
                                        ? null
                                        : _noteCtrl.text.trim(),
                                  ),
                                );
                              }
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
      );
  }
}

