import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_app_demo/core/utils/amount_input.dart';
import 'package:flutter_app_demo/core/widgets/amount_suggestion_chips.dart';
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
  final _service = FundService();
  List<FundModel> _items = [];
  Map<String, String> _memberNameById = {};
  List<String> _manualOrderIds = [];
  bool _isLoading = true;
  String? _error;

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
      await _service.updateFundOrder(_items.map((e) => e.id).toList());
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
    widget.refreshSignal?.removeListener(_onExternalRefresh);
    super.dispose();
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
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: Text(existing == null ? 'Thêm quỹ' : 'Sửa quỹ'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tên quỹ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: targetCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      ThousandsSeparatorInputFormatter(),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Mục tiêu',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  AmountSuggestionChips(
                    controller: targetCtrl,
                    onSelected: (value) {
                      targetCtrl.text = formatAmountInput(value.toString());
                    },
                  ),
                  const SizedBox(height: 12),
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
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      deadline == null
                          ? 'Chon han'
                          : 'Hạn: ${formatDate(deadline!)}',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (isClosingDialog) return;
                  isClosingDialog = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).maybePop();
                  });
                },
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () async {
                  if (isClosingDialog) return;
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('Nhập tên quỹ.')),
                    );
                    return;
                  }
                  final targetAmount = targetCtrl.text.trim().isEmpty
                      ? null
                      : parseAmountInput(targetCtrl.text.trim());
                  isClosingDialog = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
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
            ],
          ),
        );
      },
    );

    if (payload == null) return;

    final name = payload['name'] as String;
    final targetAmount = payload['targetAmount'] as double?;
    final selectedDeadline = payload['deadline'] as DateTime?;

    try {
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

        final amount = await _service.previewDeleteFundSettlement(item.id);
        if (!mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Xác nhận xóa quỹ'),
            content: Text(
              amount > 0
                  ? 'Nếu xác nhận xóa quỹ, hệ thống sẽ cộng vào thu nhập ${formatVnd(amount)}.'
                  : 'Nếu xác nhận xóa quỹ, hệ thống không phát sinh giao dịch tiền.',
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

        await _service.deleteFund(item.id);
        if (mounted) {
          setState(() {
            _items.removeWhere((f) => f.id == item.id);
            _manualOrderIds.remove(item.id);
          });
        }
        widget.onDataChanged?.call();
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
      final items = await _service.getFunds(widget.coupleId);
      final creatorIds = items
          .map((item) => item.creatorUserId)
          .whereType<String>()
          .toSet();
      final memberNameById = await _loadMemberNamesByIds(creatorIds);
      if (mounted) {
        setState(() {
          _items = _applyFundOrder(items);
          _memberNameById = memberNameById;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                  child: Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.savings_outlined),
                      ),
                      title: const Text('Tổng tiền đã góp quỹ'),
                      trailing: Text(
                        formatVnd(totalFundAmount),
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_items.isEmpty)
                  const Expanded(child: Center(child: Text('Chưa có quỹ nào.')))
                else
                  Expanded(
                    child: ReorderableListView.builder(
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: _items.length,
                      onReorder: _onReorder,
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
                            horizontal: 12,
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
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.savings_outlined),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          item.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        formatVnd(item.currentAmount),
                                        style: TextStyle(
                                          color: Colors.green[700],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
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
                                      backgroundColor: Colors.grey[200],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${(progress * 100).toStringAsFixed(0)}%',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        Text(
                                          'Mục tiêu: ${formatVnd(item.targetAmount!)}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (item.deadline != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        'Hạn: ${formatDate(item.deadline!)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  if (item.creatorUserId != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: Text(
                                        'Người tạo: ${_resolveMemberName(item.creatorUserId!)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
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
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openFundPopup,
        child: const Icon(Icons.add),
      ),
    );
  }
}
