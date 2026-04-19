import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_app_demo/core/utils/amount_input.dart';
import 'package:flutter_app_demo/core/widgets/amount_suggestion_chips.dart';
import 'package:flutter_app_demo/core/utils/formatters.dart';
import 'package:flutter_app_demo/features/transfer/data/models/transfer_model.dart';
import 'package:flutter_app_demo/features/transfer/data/services/transfer_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TransferListScreen extends StatefulWidget {
  final String coupleId;
  final String viewerUserId;
  final String currentUserId;
  final String viewerLabel;
  final String? partnerUserId;
  final VoidCallback? onToggleViewer;
  final ValueListenable<int>? refreshSignal;
  final VoidCallback? onDataChanged;

  const TransferListScreen({
    super.key,
    required this.coupleId,
    required this.viewerUserId,
    required this.currentUserId,
    required this.viewerLabel,
    this.partnerUserId,
    this.onToggleViewer,
    this.refreshSignal,
    this.onDataChanged,
  });

  @override
  State<TransferListScreen> createState() => _TransferListScreenState();
}

class _TransferFormResult {
  final double amount;
  final String toUserId;
  final String? note;
  final DateTime date;

  const _TransferFormResult({
    required this.amount,
    required this.toUserId,
    required this.note,
    required this.date,
  });
}

class _TransferListScreenState extends State<TransferListScreen> {
  final _service = TransferService();
  List<TransferModel> _items = [];
  Map<String, String> _userNameById = {};
  bool _isLoading = true;
  bool _isDeleting = false;
  String? _error;

  DateTime _toUtcPlus7(DateTime value) {
    final utcValue = value.isUtc ? value : value.toUtc();
    return utcValue.add(const Duration(hours: 7));
  }

  String _formatCreatedTimeUtcPlus7(DateTime value) {
    return formatDateTime(_toUtcPlus7(value)).split(' ').last;
  }

  Future<void> _showSwitchBackToSelfAlert() async {
    final viewingLabel = widget.viewerLabel;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Không thể thêm khi đang xem $viewingLabel'),
        content: Text(
          'Bạn đang ở view $viewingLabel. Vui lòng quay về view của tài khoản đăng nhập để thêm giao dịch.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).maybePop(),
            child: const Text('Đóng'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).maybePop();
              widget.onToggleViewer?.call();
            },
            child: const Text('Chuyển về tôi'),
          ),
        ],
      ),
    );
  }

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
    if (oldWidget.viewerUserId != widget.viewerUserId) {
      _load(showLoader: false);
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
      final items = await _service.getTransfers(
        widget.coupleId,
        viewerUserId: widget.viewerUserId,
        partnerUserId: widget.partnerUserId,
      );
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final userIds = <String>{
        ...items.map((item) => item.fromUserId),
        ...items.map((item) => item.toUserId),
      };
      final users = userIds.isEmpty
          ? <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              await Supabase.instance.client
                  .from('users')
                  .select('id, display_name, email')
                  .inFilter('id', userIds.toList()),
            );
      final userNameById = {
        for (final row in users)
          row['id'] as String:
              ((row['display_name'] as String?)?.trim().isNotEmpty == true
              ? (row['display_name'] as String).trim()
              : ((row['email'] as String?) ?? 'Người kia')),
      };

      if (mounted) {
        setState(() {
          _items = items;
          _userNameById = userNameById;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (showLoader && mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete(TransferModel item) async {
    if (_isDeleting) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dang xoa giao dich truoc, vui long cho.'),
          ),
        );
      }
      return;
    }
    if (mounted) {
      setState(() {
        _isDeleting = true;
      });
    } else {
      _isDeleting = true;
    }

    final removedIndex = _items.indexWhere((e) => e.id == item.id);
    final removedItem = removedIndex >= 0 ? _items[removedIndex] : item;
    if (removedIndex >= 0 && mounted) {
      setState(() {
        _items.removeAt(removedIndex);
      });
    }

    try {
      await _service.deleteTransfer(item.id);
      widget.onDataChanged?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Da xoa giao dich chuyen tien')),
      );
    } catch (e) {
      if (mounted && removedIndex >= 0) {
        setState(() {
          final insertAt = removedIndex.clamp(0, _items.length);
          _items.insert(insertAt, removedItem);
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi xóa: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      } else {
        _isDeleting = false;
      }
    }
  }

  Future<void> _createTransferOptimistic(_TransferFormResult payload) async {
    final uid = Supabase.instance.client.auth.currentUser!.id;
    final now = DateTime.now().toUtc();
    final tempId = 'temp-transfer-${now.microsecondsSinceEpoch}';
    final optimistic = TransferModel(
      id: tempId,
      coupleId: widget.coupleId,
      fromUserId: uid,
      toUserId: payload.toUserId,
      fromWalletId: null,
      toWalletId: null,
      amount: payload.amount,
      note: payload.note,
      linkedIncomeId: null,
      date: payload.date,
      createdAt: now,
      updatedAt: now,
      updatedBy: uid,
      isDeleted: false,
      deletedAt: null,
    );

    if (mounted) {
      setState(() {
        _items.insert(0, optimistic);
      });
    }

    try {
      final created = await _service.createTransfer(
        coupleId: widget.coupleId,
        fromUserId: uid,
        toUserId: payload.toUserId,
        amount: payload.amount,
        note: payload.note,
        date: payload.date,
      );
      if (!mounted) return;
      setState(() {
        final index = _items.indexWhere((e) => e.id == tempId);
        if (index >= 0) {
          _items[index] = created;
        } else {
          _items.insert(0, created);
        }
        _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      });
      widget.onDataChanged?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items.removeWhere((e) => e.id == tempId);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Loi luu: $e')));
    }
  }

  Future<bool> _confirmDeleteTransfer(TransferModel item) async {
    final impact = await _service.previewDeleteTransferImpact(item.id);
    if (!mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xac nhan xoa giao dich chuyen tien'),
        content: Text(
          'Neu xac nhan xoa, ban se duoc hoan lai ${formatVnd(impact)} vao so du vi. He thong dong thoi huy giao dich thu nhap lien ket cua nguoi nhan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).maybePop(false),
            child: const Text('Huy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).maybePop(true),
            child: const Text('Xoa'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _openTransferPopup({TransferModel? existing}) async {
    final members = await _service.getCoupleMembers(widget.coupleId);
    final uid = Supabase.instance.client.auth.currentUser!.id;
    final memberIds = members.map((m) => m['user_id'] as String).toList();
    final users = memberIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await Supabase.instance.client
                .from('users')
                .select('id, display_name, email')
                .inFilter('id', memberIds),
          );
    final memberLabelById = {
      for (final user in users)
        user['id'] as String:
            ((user['display_name'] as String?)?.trim().isNotEmpty == true
            ? (user['display_name'] as String).trim()
            : ((user['email'] as String?) ?? 'User')),
    };

    final recipients = members
        .map((m) => m['user_id'] as String)
        .where((id) => id != uid)
        .toList();

    if (!mounted) return;

    if (recipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chua co nguoi kia trong couple.')),
      );
      return;
    }

    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String selectedRecipientId = existing?.toUserId ?? recipients.first;
    DateTime selectedDate = existing?.date ?? DateTime.now();
    var isClosingDialog = false;
    if (existing != null) {
      amountCtrl.text = existing.amount.toStringAsFixed(0);
      noteCtrl.text = existing.note ?? '';
    }

    final payload = await showDialog<_TransferFormResult>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: Text(
              existing == null ? 'Them chuyen tien' : 'Sua chuyen tien',
            ),
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
                    initialValue: selectedRecipientId,
                    decoration: const InputDecoration(
                      labelText: 'Nguoi nhan',
                      border: OutlineInputBorder(),
                    ),
                    items: recipients
                        .map(
                          (id) => DropdownMenuItem(
                            value: id,
                            child: Text(memberLabelById[id] ?? 'Người kia'),
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
                onPressed: () {
                  if (isClosingDialog) return;
                  isClosingDialog = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).maybePop();
                  });
                },
                child: const Text('Huy'),
              ),
              FilledButton(
                onPressed: () async {
                  if (isClosingDialog) return;
                  final amount = parseAmountInput(amountCtrl.text.trim());
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('So tien khong hop le.')),
                    );
                    return;
                  }
                  isClosingDialog = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!dialogContext.mounted) return;
                    Navigator.of(dialogContext).maybePop(
                      _TransferFormResult(
                        amount: amount,
                        toUserId: selectedRecipientId,
                        note: noteCtrl.text.trim().isEmpty
                            ? null
                            : noteCtrl.text.trim(),
                        date: selectedDate,
                      ),
                    );
                  });
                },
                child: const Text('Luu'),
              ),
            ],
          ),
        );
      },
    );

    if (payload == null) return;

    if (existing == null) {
      await _createTransferOptimistic(payload);
      return;
    }

    try {
      await _service.updateTransfer(
        transferId: existing.id,
        fromUserId: uid,
        toUserId: payload.toUserId,
        amount: payload.amount,
        note: payload.note,
        date: payload.date,
      );
      await _load(showLoader: false);
      widget.onDataChanged?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _showItemActions(TransferModel item) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final canEdit = currentUserId != null && item.fromUserId == currentUserId;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canEdit)
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
      final confirmed = await _confirmDeleteTransfer(item);
      if (!confirmed) return;
      await _delete(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalSent = _items
        .where((item) => item.fromUserId == widget.viewerUserId)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final totalReceived = _items
        .where((item) => item.toUserId == widget.viewerUserId)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final grouped = <String, List<TransferModel>>{};
    for (final item in _items) {
      final key =
          '${item.date.year}-${item.date.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => <TransferModel>[]).add(item);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chuyển tiền'),
        actions: [
          if (widget.partnerUserId != null)
            IconButton(
              onPressed: widget.onToggleViewer,
              icon: Icon(
                widget.viewerUserId == widget.currentUserId
                    ? Icons.person
                    : Icons.people_alt_outlined,
              ),
              tooltip: 'Đang xem: ${widget.viewerLabel}. Chạm để đổi.',
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
          ? Center(
              child: Text(
                'Chưa có giao dịch chuyển tiền nào của ${widget.viewerLabel}.',
              ),
            )
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Tổng tiền đã chuyển',
                                  style: TextStyle(fontSize: 12),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  formatVnd(totalSent),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Tổng tiền đã nhận',
                                  style: TextStyle(fontSize: 12),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  formatVnd(totalReceived),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                for (final entry in grouped.entries) ...[
                  Builder(
                    builder: (context) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'Tháng ${entry.key.split('-')[1]}/${entry.key.split('-')[0]}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
                  ...entry.value.map((item) {
                    final isIncoming = item.toUserId == widget.viewerUserId;
                    final counterpartyId = isIncoming
                        ? item.fromUserId
                        : item.toUserId;
                    final partnerName =
                        _userNameById[counterpartyId] ?? 'Người kia';
                    final directionLabel = isIncoming
                        ? 'Nhận từ'
                        : 'Chuyển cho';
                    final amountColor = isIncoming
                        ? Colors.green[700]
                        : Theme.of(context).colorScheme.error;
                    return ListTile(
                      key: ValueKey(item.id),
                      leading: CircleAvatar(
                        backgroundColor: (amountColor ?? Colors.grey)
                            .withOpacity(0.12),
                        child: Icon(
                          isIncoming
                              ? Icons.south_west_rounded
                              : Icons.north_east_rounded,
                          color: amountColor,
                        ),
                      ),
                      onLongPress: () => _showItemActions(item),
                      title: Text(item.note ?? '$directionLabel $partnerName'),
                      subtitle: Text(
                        '${formatDate(item.date)} · ${_formatCreatedTimeUtcPlus7(item.createdAt)}',
                      ),
                      trailing: Text(
                        '${isIncoming ? '+' : '-'} ${formatVnd(item.amount)}',
                        style: TextStyle(
                          color: amountColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (widget.viewerUserId != widget.currentUserId) {
            await _showSwitchBackToSelfAlert();
            return;
          }
          await _openTransferPopup();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
