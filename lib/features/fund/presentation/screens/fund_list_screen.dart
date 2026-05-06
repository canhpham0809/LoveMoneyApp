import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_app_demo/core/utils/amount_input.dart';
import 'package:flutter_app_demo/core/theme/app_colors.dart';
import 'package:flutter_app_demo/core/widgets/amount_suggestion_chips.dart';
import 'package:flutter_app_demo/core/widgets/busy_overlay.dart';
import 'package:flutter_app_demo/core/utils/formatters.dart';
import 'package:flutter_app_demo/features/fund/data/models/fund_model.dart';
import 'package:flutter_app_demo/features/fund/data/services/fund_service.dart';
import 'package:flutter_app_demo/features/fund/presentation/screens/fund_detail_screen.dart';

class FundListScreen extends StatefulWidget {
  final String coupleId;
  final ValueListenable<int>? refreshSignal;
  final VoidCallback? onDataChanged;

  const FundListScreen({
    super.key,
    required this.coupleId,
    this.refreshSignal,
    this.onDataChanged,
  });

  @override
  State<FundListScreen> createState() => _FundListScreenState();
}

class _FundListScreenState extends State<FundListScreen> {
  static const int _pageSize = 50;

  final _service = FundService();
  final ScrollController _scrollController = ScrollController();
  List<FundModel> _items = [];
  Map<String, String> _memberNameById = {};
  List<String> _manualOrderIds = [];
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

  String _normalizeUserId(String userId) => userId.trim().toLowerCase();

  String _resolveMemberName(String userId) {
    final name = _memberNameById[_normalizeUserId(userId)]?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Thành viên';
  }

  Future<Map<String, String>> _loadMemberNamesByIds(Set<String> userIds) async {
    if (userIds.isEmpty) return {};
    final users = List<Map<String, dynamic>>.from(
      await Supabase.instance.client
          .from('users')
          .select('id, display_name, email')
          .inFilter('id', userIds.toList()),
    );
    return {
      for (final u in users)
        _normalizeUserId(
          u['id'] as String,
        ): ((u['display_name'] as String?)?.trim().isNotEmpty == true
            ? (u['display_name'] as String).trim()
            : ((u['email'] as String?) ?? 'Thành viên')),
    };
  }

  void _sortFundsByName(List<FundModel> items) {
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  List<FundModel> _applyFundOrder(List<FundModel> items) {
    final nextItems = List<FundModel>.from(items);
    if (_manualOrderIds.isEmpty) {
      _sortFundsByName(nextItems);
      _manualOrderIds = nextItems.map((e) => e.id).toList();
      return nextItems;
    }

    final byId = {for (final item in nextItems) item.id: item};
    final ordered = <FundModel>[];
    for (final id in _manualOrderIds) {
      final item = byId.remove(id);
      if (item != null) {
        ordered.add(item);
      }
    }
    final rest = byId.values.toList();
    _sortFundsByName(rest);
    ordered.addAll(rest);
    _manualOrderIds = ordered.map((e) => e.id).toList();
    return ordered;
  }

  void _onReorder(int oldIndex, int newIndex) {
    final previousOrder = List<String>.from(_manualOrderIds);
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final moved = _items.removeAt(oldIndex);
      _items.insert(newIndex, moved);
      _manualOrderIds = _items.map((e) => e.id).toList();
    });
    unawaited(_persistFundOrder(previousOrder));
  }

  Future<void> _persistFundOrder(List<String> previousOrder) async {
    try {
      await _runMutation(
        () => _service.updateFundOrder(_items.map((e) => e.id).toList()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _manualOrderIds = previousOrder;
        _items = _applyFundOrder(_items);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không lưu được thứ tự quỹ: $e')));
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
  void didUpdateWidget(covariant FundListScreen oldWidget) {
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

  Future<void> _openFundPopup({FundModel? existing}) async {
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    DateTime? deadline = existing?.deadline;
    var isClosingDialog = false;
    if (existing != null) {
      nameCtrl.text = existing.name;
      if (existing.targetAmount != null) {
        targetCtrl.text = formatAmountInput(
          existing.targetAmount!.toStringAsFixed(0),
        );
      }
    }

    final payload = await showDialog<Map<String, dynamic>>(
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
                maxHeight: media.height * 0.8,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        existing == null ? 'Thêm quỹ' : 'Sửa quỹ',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(hintText: 'Tên quỹ'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: targetCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          ThousandsSeparatorInputFormatter(),
                        ],
                        decoration: const InputDecoration(
                          hintText: 'Mục tiêu (tuỳ chọn)',
                        ),
                      ),
                      const SizedBox(height: 6),
                      AmountSuggestionChips(
                        controller: targetCtrl,
                        onSelected: (value) {
                          targetCtrl.text = formatAmountInput(value.toString());
                        },
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate: deadline ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setDialogState(() => deadline = picked);
                          }
                        },
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text(
                          deadline == null
                              ? 'Chọn hạn'
                              : 'Hạn: ${formatDate(deadline!)}',
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
                              onPressed: () {
                                if (isClosingDialog) return;
                                final name = nameCtrl.text.trim();
                                if (name.isEmpty) {
                                  ScaffoldMessenger.of(
                                    dialogContext,
                                  ).showSnackBar(
                                    const SnackBar(
                                      content: Text('Nhập tên quỹ.'),
                                    ),
                                  );
                                  return;
                                }
                                final targetAmount =
                                    targetCtrl.text.trim().isEmpty
                                    ? null
                                    : parseAmountInput(targetCtrl.text.trim());
                                isClosingDialog = true;
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (!dialogContext.mounted) return;
                                  Navigator.of(dialogContext).maybePop({
                                    'name': name,
                                    'targetAmount': targetAmount,
                                    'deadline': deadline,
                                  });
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

    if (payload == null) return;

    final name = payload['name'] as String;
    final targetAmount = payload['targetAmount'] as double?;
    final selectedDeadline = payload['deadline'] as DateTime?;

    try {
      await _runMutation(() async {
        if (existing == null) {
          final created = await _service.createFund(
            coupleId: widget.coupleId,
            name: name,
            targetAmount: targetAmount,
            deadline: selectedDeadline,
          );
          if (!mounted) return;
          setState(() {
            _items.insert(0, created);
            _manualOrderIds.remove(created.id);
            _manualOrderIds.insert(0, created.id);
            _items = _applyFundOrder(_items);
          });
        } else {
          await _service.updateFund(
            fundId: existing.id,
            name: name,
            targetAmount: targetAmount,
            deadline: selectedDeadline,
          );
          final refreshed = await _service.getFundById(existing.id);
          if (!mounted) return;
          setState(() {
            final idx = _items.indexWhere((e) => e.id == existing.id);
            if (idx >= 0) {
              _items[idx] = refreshed;
            }
            _items = _applyFundOrder(_items);
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

  Future<void> _showFundActions(FundModel item) async {
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
      await _openFundPopup(existing: item);
      return;
    }
    if (action == 'delete') {
      try {
        final currentUserId = Supabase.instance.client.auth.currentUser?.id;
        if (currentUserId == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không tìm thấy phiên đăng nhập.')),
          );
          return;
        }
        final creatorUserId = item.creatorUserId;
        if (creatorUserId != null && creatorUserId != currentUserId) {
          if (!mounted) return;
          await showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Không có quyền xóa'),
              content: const Text('Chỉ người tạo quỹ mới có quyền xóa.'),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Đã hiểu'),
                ),
              ],
            ),
          );
          return;
        }
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Xác nhận xóa quỹ'),
            content: const Text(
              'Nếu thực hiện xóa khoản Quỹ này, tất cả các giao dịch đã phát sinh trước đó đều sẽ bị xóa.',
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
          await _service.deleteFund(item.id);
          if (mounted) {
            setState(() {
              _items.removeWhere((f) => f.id == item.id);
              _manualOrderIds.remove(item.id);
            });
          }
          widget.onDataChanged?.call();
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể xóa: $e')));
      }
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await _service.getFunds(
        widget.coupleId,
        limit: _pageSize,
        offset: 0,
      );
      final creatorIds = items
          .map((item) => item.creatorUserId)
          .whereType<String>()
          .toSet();
      final memberNameById = await _loadMemberNamesByIds(creatorIds);
      if (mounted) {
        setState(() {
          _items = _applyFundOrder(items);
          _memberNameById = memberNameById;
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
      final nextItems = await _service.getFunds(
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

      final merged = _applyFundOrder([..._items, ...nextItems]);
      final creatorIds = merged
          .map((item) => item.creatorUserId)
          .whereType<String>()
          .toSet();
      final memberNameById = await _loadMemberNamesByIds(creatorIds);

      if (mounted) {
        setState(() {
          _items = merged;
          _memberNameById = memberNameById;
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
    final totalFundAmount = _items.fold<double>(
      0,
      (sum, item) => sum + item.currentAmount,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quỹ tiết kiệm'),
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
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _load,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.savings_outlined,
                          color: AppColors.success,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Tổng tiền đã góp quỹ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          formatVnd(totalFundAmount),
                          style: const TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_items.isEmpty)
                    const Expanded(
                      child: Center(child: Text('Chưa có quỹ nào.')),
                    )
                  else
                    Expanded(
                      child: ReorderableListView.builder(
                        scrollController: _scrollController,
                        padding: const EdgeInsets.only(bottom: 12),
                        itemCount: _items.length,
                        onReorder: _hasMore ? (_, _) {} : _onReorder,
                        buildDefaultDragHandles: false,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final progress =
                              (item.targetAmount != null &&
                                  item.targetAmount! > 0)
                              ? (item.currentAmount / item.targetAmount!).clamp(
                                  0.0,
                                  1.0,
                                )
                              : 0.0;
                          return Card(
                            key: ValueKey(item.id),
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            child: InkWell(
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FundDetailScreen(
                                      coupleId: widget.coupleId,
                                      fundId: item.id,
                                    ),
                                  ),
                                );
                                if (mounted) {
                                  await _load();
                                  widget.onDataChanged?.call();
                                }
                              },
                              onLongPress: () => _showFundActions(item),
                              borderRadius: BorderRadius.circular(18),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          height: 56,
                                          width: 56,
                                          decoration: BoxDecoration(
                                            color: AppColors.tealSoft
                                                .withValues(alpha: 0.45),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.savings_outlined,
                                            color: AppColors.tealDeep,
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
                                        Text(
                                          formatVnd(item.currentAmount),
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                        ),
                                        if (!_hasMore)
                                          ReorderableDragStartListener(
                                            index: index,
                                            child: const Padding(
                                              padding: EdgeInsets.only(left: 8),
                                              child: Icon(Icons.drag_indicator),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (item.targetAmount != null) ...[
                                      const SizedBox(height: 8),
                                      LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 12,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                              AppColors.tealDeep,
                                            ),
                                        backgroundColor: Colors.grey[200],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${(progress * 100).toStringAsFixed(0)}%',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppColors.tealDeep,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            'Mục tiêu: ${formatVnd(item.targetAmount!)}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    if (item.deadline != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 4.0,
                                        ),
                                        child: Text(
                                          'Hạn: ${formatDate(item.deadline!)}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ),
                                    if (item.creatorUserId != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 2.0,
                                        ),
                                        child: Text(
                                          'Người tạo: ${_resolveMemberName(item.creatorUserId!)}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textMuted,
                                          ),
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
        onPressed: _openFundPopup,
        child: const Icon(Icons.add, size: 36),
      ),
    );
  }
}
