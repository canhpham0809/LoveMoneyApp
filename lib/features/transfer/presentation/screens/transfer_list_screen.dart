import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_app_demo/core/theme/app_colors.dart';

import 'package:flutter_app_demo/core/utils/amount_input.dart';
import 'package:flutter_app_demo/core/widgets/amount_suggestion_chips.dart';
import 'package:flutter_app_demo/core/widgets/busy_overlay.dart';
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
  static const int _pageSize = 50;

  final _service = TransferService();
  final ScrollController _scrollController = ScrollController();
  List<TransferModel> _items = [];
  Map<String, String> _userNameById = {};
  int _currentOffset = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool _isLoading = true;
  bool _isDeleting = false;
  bool _isMutating = false;
  bool _isRefreshingContent = false;
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
    _scrollController.addListener(_onScroll);
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
    _load(showLoader: false, showRefreshOverlay: false);
  }

  Future<void> _load({
    bool showLoader = true,
    bool showRefreshOverlay = true,
  }) async {
    if (showLoader) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else if (showRefreshOverlay && mounted) {
      setState(() {
        _error = null;
        _isRefreshingContent = true;
      });
    }
    try {
      final items = await _service.getTransfers(
        widget.coupleId,
        viewerUserId: widget.viewerUserId,
        partnerUserId: widget.partnerUserId,
        limit: _pageSize,
        offset: 0,
      );
      items.sort((a, b) {
        final dateCompare = b.date.compareTo(a.date);
        if (dateCompare != 0) return dateCompare;
        return b.createdAt.compareTo(a.createdAt);
      });
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
          _currentOffset = items.length;
          _hasMore = items.length == _pageSize;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          if (showLoader) {
            _isLoading = false;
          } else {
            _isRefreshingContent = false;
          }
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);
    try {
      final nextItems = await _service.getTransfers(
        widget.coupleId,
        viewerUserId: widget.viewerUserId,
        partnerUserId: widget.partnerUserId,
        limit: _pageSize,
        offset: _currentOffset,
      );
      if (nextItems.isEmpty) {
        if (mounted) {
          setState(() {
            _hasMore = false;
            _isLoadingMore = false;
          });
        }
        return;
      }

      nextItems.sort((a, b) {
        final dateCompare = b.date.compareTo(a.date);
        if (dateCompare != 0) return dateCompare;
        return b.createdAt.compareTo(a.createdAt);
      });
      final combined = [..._items, ...nextItems];
      combined.sort((a, b) {
        final dateCompare = b.date.compareTo(a.date);
        if (dateCompare != 0) return dateCompare;
        return b.createdAt.compareTo(a.createdAt);
      });

      final userIds = <String>{
        ...combined.map((item) => item.fromUserId),
        ...combined.map((item) => item.toUserId),
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
          _items = combined;
          _userNameById = userNameById;
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

  Future<void> _delete(TransferModel item) async {
    if (_isDeleting) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đang xóa giao dịch trước, vui lòng chờ.'),
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
      final created = await _runMutation(
        () => _service.createTransfer(
          coupleId: widget.coupleId,
          fromUserId: uid,
          toUserId: payload.toUserId,
          amount: payload.amount,
          note: payload.note,
          date: payload.date,
        ),
      );
      if (!mounted) return;
      setState(() {
        final index = _items.indexWhere((e) => e.id == tempId);
        if (index >= 0) {
          _items[index] = created;
        } else {
          _items.insert(0, created);
        }
        _items.sort((a, b) {
          final dateCompare = b.date.compareTo(a.date);
          if (dateCompare != 0) return dateCompare;
          return b.createdAt.compareTo(a.createdAt);
        });
      });
      widget.onDataChanged?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items.removeWhere((e) => e.id == tempId);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi lưu: $e')));
    }
  }

  Future<bool> _confirmPartnerAction(BuildContext context, String partnerName) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Xác nhận thao tác'),
            content: Text(
              'Bạn đang thao tác trên giao dịch của "$partnerName". Bạn có chắc chắn muốn thực hiện?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.amber[800],
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Tiếp tục'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _confirmDeleteTransfer(TransferModel item) async {
    final impact = await _service.previewDeleteTransferImpact(item.id);
    if (!mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận xóa giao dịch chuyển tiền'),
        content: Text(
          'Nếu xác nhận xóa, bạn sẽ được hoàn lại ${formatVnd(impact)} vào số dư ví. Hệ thống đồng thời hủy giao dịch thu nhập liên kết của người nhận.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).maybePop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).maybePop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _openTransferPopup({TransferModel? existing}) async {
    final payload = await showGeneralDialog<_TransferFormResult>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, anim1, anim2) => _TransferFormDialog(
        coupleId: widget.coupleId,
        viewerUserId: widget.viewerUserId,
        existing: existing,
      ),
    );

    if (payload == null || !mounted) return;

    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    final uid = Supabase.instance.client.auth.currentUser!.id;

    if (existing == null) {
      await _createTransferOptimistic(payload);
      return;
    }

    try {
      await _runMutation(() async {
        await _service.updateTransfer(
          transferId: existing.id,
          fromUserId: uid,
          toUserId: payload.toUserId,
          amount: payload.amount,
          note: payload.note,
          date: payload.date,
        );
        widget.onDataChanged?.call();
      });
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
      if (widget.viewerUserId != widget.currentUserId) {
        final confirmed = await _confirmPartnerAction(context, widget.viewerLabel);
        if (!confirmed) return;
      }
      await _openTransferPopup(existing: item);
      return;
    }
    if (action == 'delete') {
      if (widget.viewerUserId != widget.currentUserId) {
        final confirmed = await _confirmPartnerAction(context, widget.viewerLabel);
        if (!confirmed) return;
      }
      final confirmed = await _confirmDeleteTransfer(item);
      if (!confirmed) return;
      await _delete(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<TransferModel>>{};
    for (final item in _items) {
      final key =
          '${item.date.year}-${item.date.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => <TransferModel>[]).add(item);
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
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
      body: BusyOverlay(
        isVisible: _isMutating || _isDeleting || _isRefreshingContent,
        message: _isDeleting
            ? 'Đang xóa...'
            : (_isRefreshingContent
                  ? 'Đang tải dữ liệu...'
                  : 'Đang lưu dữ liệu...'),
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
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                children: [
                  if (widget.partnerUserId != null) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.tealSoft.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Đang xem: ${widget.viewerLabel}',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: AppColors.tealDeep,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  for (final entry in grouped.entries) ...[
                    Builder(
                      builder: (context) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(0, 8, 0, 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 4,
                                  bottom: 8,
                                ),
                                child: Text(
                                  'Tháng ${entry.key.split('-')[1]}/${entry.key.split('-')[0]}',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
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
                      return Container(
                        key: ValueKey(item.id),
                        margin: const EdgeInsets.only(bottom: 8),
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
                        child: ListTile(
                          minVerticalPadding: 6,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundColor: (amountColor ?? Colors.grey)
                                .withValues(alpha: 0.12),
                            child: Icon(
                              isIncoming
                                  ? Icons.move_to_inbox_rounded
                                  : Icons.send_rounded,
                              color: amountColor,
                              size: 20,
                            ),
                          ),
                          onTap: () => _showItemActions(item),
                          title: Text(
                            item.note ?? '$directionLabel $partnerName',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${formatDate(item.date)} · ${_formatCreatedTimeUtcPlus7(item.createdAt)}',
                          ),
                          trailing: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${isIncoming ? '+' : '-'}${formatVnd(item.amount)}',
                                style: TextStyle(
                                  color: amountColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                  if (_isLoadingMore)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (!_hasMore)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
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
      floatingActionButton: LayoutBuilder(
        builder: (context, constraints) {
          final isLarge = MediaQuery.sizeOf(context).width > 800;
          if (isLarge) {
            return FloatingActionButton.extended(
              onPressed: () async {
                if (widget.viewerUserId != widget.currentUserId) {
                  await _showSwitchBackToSelfAlert();
                  return;
                }
                await _openTransferPopup();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Thêm chuyển khoản',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              backgroundColor: AppColors.tealDeep,
              foregroundColor: Colors.white,
            );
          }
          return FloatingActionButton(
            onPressed: () async {
              if (widget.viewerUserId != widget.currentUserId) {
                await _showSwitchBackToSelfAlert();
                return;
              }
              await _openTransferPopup();
            },
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }
}

class _TransferFormDialog extends StatefulWidget {
  final String coupleId;
  final String viewerUserId;
  final TransferModel? existing;

  const _TransferFormDialog({
    required this.coupleId,
    required this.viewerUserId,
    this.existing,
  });

  @override
  State<_TransferFormDialog> createState() => _TransferFormDialogState();
}

class _TransferFormDialogState extends State<_TransferFormDialog> {
  final _service = TransferService();
  bool _isLoading = true;
  String? _error;
  List<String> _recipients = [];
  Map<String, String> _memberLabelById = {};

  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String? _selectedRecipientId;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _amountCtrl.text = formatAmountInput(widget.existing!.amount.toStringAsFixed(0));
      _noteCtrl.text = widget.existing!.note ?? '';
      _selectedDate = widget.existing!.date;
    }
    _loadData();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final members = await _service.getCoupleMembers(widget.coupleId);
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
          .where((id) => id != widget.viewerUserId)
          .toList();

      if (!mounted) return;
      if (recipients.isEmpty) {
        setState(() {
          _error = 'Chưa có người kia trong couple.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _recipients = recipients;
        _memberLabelById = memberLabelById;
        _selectedRecipientId = widget.existing?.toUserId ?? recipients.first;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);

    return MediaQuery.removeViewInsets(
      context: context,
      removeBottom: true,
      child: Dialog(
        alignment: Alignment.center,
        insetAnimationDuration: Duration.zero,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: media.height * 0.8,
          ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null
                    ? 'Thêm chuyển tiền'
                    : 'Sửa chuyển tiền',
                textAlign: TextAlign.center,
                style: const TextStyle(
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
                      TextField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          ThousandsSeparatorInputFormatter(),
                        ],
                        decoration: const InputDecoration(hintText: 'Số tiền'),
                      ),
                      AmountSuggestionChips(
                        controller: _amountCtrl,
                        onSelected: (value) {
                          _amountCtrl.text = formatAmountInput(value.toString());
                        },
                      ),
                      const SizedBox(height: 10),
                      if (_isLoading)
                        const SizedBox(
                          height: 60,
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_error != null || _recipients.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            _error ?? 'Chưa có người kia trong couple.',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          value: _selectedRecipientId,
                          decoration: const InputDecoration(
                            hintText: 'Người nhận',
                          ),
                          items: _recipients
                              .map(
                                (id) => DropdownMenuItem(
                                  value: id,
                                  child: Text(_memberLabelById[id] ?? 'Người kia'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _selectedRecipientId = v);
                            }
                          },
                        ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _noteCtrl,
                        decoration: const InputDecoration(hintText: 'Ghi chú'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => _selectedDate = picked);
                          }
                        },
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text('Ngày: ${formatDate(_selectedDate)}'),
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
                      onPressed: (_isLoading || _error != null || _recipients.isEmpty)
                          ? null
                          : () {
                              final amount = parseAmountInput(
                                _amountCtrl.text.trim(),
                              );
                              if (amount == null || amount <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Số tiền không hợp lệ.'),
                                  ),
                                );
                                return;
                              }
                              Navigator.of(context).maybePop(
                                _TransferFormResult(
                                  amount: amount,
                                  toUserId: _selectedRecipientId!,
                                  note: _noteCtrl.text.trim().isEmpty
                                      ? null
                                      : _noteCtrl.text.trim(),
                                  date: _selectedDate,
                                ),
                              );
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
  );
}
}
