import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_app_demo/core/utils/amount_input.dart';
import 'package:flutter_app_demo/core/theme/app_colors.dart';
import 'package:flutter_app_demo/core/utils/category_visuals.dart';
import 'package:flutter_app_demo/core/widgets/amount_suggestion_chips.dart';
import 'package:flutter_app_demo/core/widgets/busy_overlay.dart';
import 'package:flutter_app_demo/core/utils/formatters.dart';
import 'package:flutter_app_demo/features/income/data/models/income_model.dart';
import 'package:flutter_app_demo/features/income/data/models/income_source_model.dart';
import 'package:flutter_app_demo/features/income/data/services/income_service.dart';
import 'package:flutter_app_demo/features/income/presentation/screens/income_search_filter_screen.dart';
import 'package:flutter_app_demo/features/wallet/data/services/wallet_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class IncomeListScreen extends StatefulWidget {
  final String coupleId;
  final String viewerUserId;
  final String currentUserId;
  final String viewerLabel;
  final String? partnerUserId;
  final VoidCallback? onToggleViewer;
  final ValueListenable<int>? refreshSignal;
  final VoidCallback? onDataChanged;

  const IncomeListScreen({
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
  State<IncomeListScreen> createState() => _IncomeListScreenState();
}

class _IncomeFormResult {
  final double amount;
  final String incomeSourceId;
  final String? description;
  final DateTime date;

  const _IncomeFormResult({
    required this.amount,
    required this.incomeSourceId,
    required this.description,
    required this.date,
  });
}

enum _IncomeFeedKind {
  income,
  fundWithdrawal,
  debtCollection,
  transferReceived,
}

class _IncomeFeedItem {
  final String id;
  final _IncomeFeedKind kind;
  final double amount;
  final String title;
  final DateTime date;
  final DateTime createdAt;
  final IncomeModel? editableIncome;

  const _IncomeFeedItem({
    required this.id,
    required this.kind,
    required this.amount,
    required this.title,
    required this.date,
    required this.createdAt,
    this.editableIncome,
  });
}

class _IncomeExternalLoadResult {
  final List<_IncomeFeedItem> items;
  final Set<String> linkedIncomeIds;

  const _IncomeExternalLoadResult({
    required this.items,
    required this.linkedIncomeIds,
  });
}

class _IncomeListScreenState extends State<IncomeListScreen> {
  static const int _pageSize = 50;

  final _service = IncomeService();
  final _walletService = WalletService();
  final ScrollController _scrollController = ScrollController();
  List<IncomeModel> _items = [];
  List<_IncomeFeedItem> _externalItems = [];
  Map<String, IncomeSourceModel> _sourceById = {};
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

  int _compareBySelectedDateDesc(_IncomeFeedItem a, _IncomeFeedItem b) {
    final dateCompare = b.date.compareTo(a.date);
    if (dateCompare != 0) return dateCompare;
    return b.createdAt.compareTo(a.createdAt);
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
  void didUpdateWidget(covariant IncomeListScreen oldWidget) {
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
      final results = await Future.wait<dynamic>([
        _service.getIncomes(
          widget.coupleId,
          createdByUserId: widget.viewerUserId,
          limit: _pageSize,
          offset: 0,
        ),
        _service.getIncomeSources(widget.coupleId),
        _loadExternalIncomeItems(),
      ]);
      var items = List<IncomeModel>.from(results[0] as List);
      final sources = List<IncomeSourceModel>.from(results[1] as List);
      final external = results[2] as _IncomeExternalLoadResult;

      items = items.where((income) => !income.isFromTransfer).toList();

      if (external.linkedIncomeIds.isNotEmpty) {
        items = items
            .where((income) => !external.linkedIncomeIds.contains(income.id))
            .toList();
      }

      items.sort((a, b) {
        final dateCompare = b.date.compareTo(a.date);
        if (dateCompare != 0) return dateCompare;
        return b.createdAt.compareTo(a.createdAt);
      });
      if (mounted) {
        setState(() {
          _items = items;
          _externalItems = external.items;
          _sourceById = {for (final s in sources) s.id: s};
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
      var nextItems = await _service.getIncomes(
        widget.coupleId,
        createdByUserId: widget.viewerUserId,
        limit: _pageSize,
        offset: _currentOffset,
      );

      nextItems = nextItems.where((income) => !income.isFromTransfer).toList();
      if (!mounted) return;

      if (nextItems.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoadingMore = false;
        });
        return;
      }

      nextItems.sort((a, b) {
        final dateCompare = b.date.compareTo(a.date);
        if (dateCompare != 0) return dateCompare;
        return b.createdAt.compareTo(a.createdAt);
      });

      setState(() {
        _items = [..._items, ...nextItems];
        _currentOffset = _items.length;
        _hasMore = nextItems.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<_IncomeExternalLoadResult> _loadExternalIncomeItems() async {
    final db = Supabase.instance.client;

    var fundsQuery = db
        .from('fund_contributions')
        .select(
          'id, amount, date, created_at, note, fund_id, linked_income_id, user_id',
        )
        .eq('couple_id', widget.coupleId)
        .eq('contribution_type', 'withdrawal')
        .eq('is_deleted', false);
    var debtQuery = db
        .from('debt_payments')
        .select(
          'id, amount, date, created_at, note, debt_id, linked_income_id, updated_by',
        )
        .eq('couple_id', widget.coupleId)
        .eq('is_deleted', false);
    var transferQuery = db
        .from('transfers')
        .select(
          'id, amount, date, created_at, note, from_user_id, to_user_id, linked_income_id',
        )
        .eq('couple_id', widget.coupleId)
        .eq('is_deleted', false);

    if (widget.viewerUserId.isNotEmpty) {
      fundsQuery = fundsQuery.eq('user_id', widget.viewerUserId);
      debtQuery = debtQuery.eq('updated_by', widget.viewerUserId);
      transferQuery = transferQuery.eq('to_user_id', widget.viewerUserId);
    }

    final futures = await Future.wait<dynamic>([
      fundsQuery.order('created_at', ascending: false),
      debtQuery.order('created_at', ascending: false),
      transferQuery.order('created_at', ascending: false),
      db.from('funds').select('id, name').eq('couple_id', widget.coupleId),
      db
          .from('debts')
          .select('id, name')
          .eq('couple_id', widget.coupleId)
          .eq('is_deleted', false),
    ]);

    final funds = List<Map<String, dynamic>>.from(futures[0] as List);
    final payments = List<Map<String, dynamic>>.from(futures[1] as List);
    final transfers = List<Map<String, dynamic>>.from(futures[2] as List);
    final fundNameById = {
      for (final row in List<Map<String, dynamic>>.from(futures[3] as List))
        row['id'] as String: row['name'] as String,
    };
    final debtNameById = {
      for (final row in List<Map<String, dynamic>>.from(futures[4] as List))
        row['id'] as String: row['name'] as String,
    };

    final userIds = <String>{
      ...funds.map((row) => row['user_id']).whereType<String>(),
      ...payments.map((row) => row['updated_by']).whereType<String>(),
      ...transfers.map((row) => row['from_user_id']).whereType<String>(),
      ...transfers.map((row) => row['to_user_id']).whereType<String>(),
    };
    final users = userIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await db
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

    final linkedIncomeIds = <String>{};
    final items = <_IncomeFeedItem>[];

    for (final row in funds) {
      final note = (row['note'] as String?)?.trim();
      bool recordAsIncome = true;
      if (note != null) {
        if (note.startsWith('[GOLD]')) {
          try {
            final decoded = jsonDecode(note.substring(6));
            if (decoded is Map) {
              final incVal = decoded['record_as_income'] ?? decoded['recordAsIncome'];
              if (incVal is bool) {
                recordAsIncome = incVal;
              }
            }
          } catch (_) {}
        } else if (note.startsWith('[WITHDRAWAL]')) {
          try {
            final decoded = jsonDecode(note.substring(12));
            if (decoded is Map) {
              final incVal = decoded['record_as_income'] ?? decoded['recordAsIncome'];
              if (incVal is bool) {
                recordAsIncome = incVal;
              }
            }
          } catch (_) {}
        }
      }

      if (!recordAsIncome) {
        continue; // Skip withdrawals that shouldn't be recorded as income!
      }

      final linkedIncomeId = row['linked_income_id'] as String?;
      if (linkedIncomeId != null) {
        linkedIncomeIds.add(linkedIncomeId);
      }
      final fundId = row['fund_id'] as String?;
      final fundName =
          (fundId != null ? fundNameById[fundId] : null) ?? 'Quỹ tiết kiệm';

      String formattedTitle = 'Rút quỹ: $fundName';
      if (note != null && note.isNotEmpty) {
        if (note.startsWith('[GOLD]')) {
          try {
            final decoded = jsonDecode(note.substring(6));
            if (decoded is Map) {
              final qty = decoded['quantity'] ?? decoded['goldQuantity'] ?? decoded['gold_quantity'] ?? '0';
              final store = (decoded['store'] ?? decoded['shop'] ?? decoded['goldStore'] ?? decoded['gold_store'])?.toString();
              final userNote = (decoded['note'] ?? decoded['cleanNote'] ?? decoded['clean_note'])?.toString();
              formattedTitle = 'Rút $qty chỉ vàng';
              if (store != null && store.trim().isNotEmpty) {
                formattedTitle += ' tại ${store.trim()}';
              }
              if (userNote != null && userNote.trim().isNotEmpty) {
                formattedTitle += ' ($userNote)';
              }
            } else {
              formattedTitle = note;
            }
          } catch (_) {
            formattedTitle = note;
          }
        } else if (note.startsWith('[WITHDRAWAL]')) {
          try {
            final decoded = jsonDecode(note.substring(12));
            if (decoded is Map) {
              final userNote = (decoded['note'] ?? decoded['cleanNote'] ?? decoded['clean_note'])?.toString();
              formattedTitle = (userNote != null && userNote.trim().isNotEmpty)
                  ? userNote.trim()
                  : 'Rút quỹ: $fundName';
            } else {
              formattedTitle = note;
            }
          } catch (_) {
            formattedTitle = note;
          }
        } else {
          formattedTitle = note;
        }
      }

      items.add(
        _IncomeFeedItem(
          id: 'fund-${row['id']}',
          kind: _IncomeFeedKind.fundWithdrawal,
          amount: (row['amount'] as num).toDouble(),
          title: formattedTitle,
          date: DateTime.parse(row['date'] as String),
          createdAt: DateTime.parse(row['created_at'] as String),
        ),
      );
    }

    for (final row in payments) {
      final linkedIncomeId = row['linked_income_id'] as String?;
      if (linkedIncomeId == null) {
        continue;
      }
      linkedIncomeIds.add(linkedIncomeId);
      final debtId = row['debt_id'] as String?;
      final debtName = (debtId != null ? debtNameById[debtId] : null) ?? 'Nợ';
      final note = (row['note'] as String?)?.trim();
      items.add(
        _IncomeFeedItem(
          id: 'debt-${row['id']}',
          kind: _IncomeFeedKind.debtCollection,
          amount: (row['amount'] as num).toDouble(),
          title: (note != null && note.isNotEmpty)
              ? note
              : 'Thu hồi nợ: $debtName',
          date: DateTime.parse(row['date'] as String),
          createdAt: DateTime.parse(row['created_at'] as String),
        ),
      );
    }

    for (final row in transfers) {
      final linkedIncomeId = row['linked_income_id'] as String?;
      if (linkedIncomeId != null) {
        linkedIncomeIds.add(linkedIncomeId);
      }
      final fromUserId = row['from_user_id'] as String?;
      final partnerName =
          (fromUserId != null ? userNameById[fromUserId] : null) ?? 'Người kia';
      final note = (row['note'] as String?)?.trim();
      items.add(
        _IncomeFeedItem(
          id: 'transfer-${row['id']}',
          kind: _IncomeFeedKind.transferReceived,
          amount: (row['amount'] as num).toDouble(),
          title: (note != null && note.isNotEmpty)
              ? note
              : 'Nhận từ $partnerName',
          date: DateTime.parse(row['date'] as String),
          createdAt: DateTime.parse(row['created_at'] as String),
        ),
      );
    }

    items.sort(_compareBySelectedDateDesc);
    return _IncomeExternalLoadResult(
      items: items,
      linkedIncomeIds: linkedIncomeIds,
    );
  }

  Future<void> _delete(IncomeModel item) async {
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
      await _service.deleteIncome(item.id);
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

  Future<void> _createIncomeOptimistic({
    required String walletId,
    required _IncomeFormResult payload,
  }) async {
    final uid = Supabase.instance.client.auth.currentUser!.id;
    final now = DateTime.now();
    final tempId = 'temp-income-${now.microsecondsSinceEpoch}';
    final optimistic = IncomeModel(
      id: tempId,
      coupleId: widget.coupleId,
      userId: uid,
      walletId: walletId,
      incomeSourceId: payload.incomeSourceId,
      amount: payload.amount,
      description: payload.description,
      isFromTransfer: false,
      linkedTransferId: null,
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
        () => _service.createIncome(
          coupleId: widget.coupleId,
          userId: uid,
          walletId: walletId,
          incomeSourceId: payload.incomeSourceId,
          amount: payload.amount,
          description: payload.description,
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

  Future<bool> _confirmDeleteIncome(IncomeModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận xóa thu nhập'),
        content: Text(
          'Nếu xác nhận xóa, số dư ví sẽ bị trừ lại ${formatVnd(item.amount)}. Không phát sinh giao dịch bù trừ mới.',
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

  Future<String?> _resolveDefaultWalletId() async {
    final wallets = await _walletService.getWallets(widget.coupleId);
    if (wallets.isEmpty) return null;
    wallets.sort((a, b) {
      if (a.isDefault == b.isDefault) return 0;
      return a.isDefault ? -1 : 1;
    });
    return wallets.first.id;
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

  Future<void> _openIncomePopup({IncomeModel? existing}) async {
    final payload = await showGeneralDialog<_IncomeFormResult>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, anim1, anim2) => _IncomeFormDialog(
        coupleId: widget.coupleId,
        existing: existing,
      ),
    );

    if (payload == null || !mounted) return;

    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    final walletId = await _resolveDefaultWalletId();
    if (!mounted) return;
    if (walletId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Chưa có ví để ghi nhận.')));
      return;
    }

    if (existing == null) {
      await _createIncomeOptimistic(walletId: walletId, payload: payload);
      return;
    }

    try {
      await _runMutation(() async {
        await _service.updateIncome(
          incomeId: existing.id,
          walletId: walletId,
          incomeSourceId: payload.incomeSourceId,
          amount: payload.amount,
          description: payload.description,
          date: payload.date,
        );
        widget.onDataChanged?.call();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi lưu: $e')));
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
      if (widget.viewerUserId != widget.currentUserId) {
        final confirmed = await _confirmPartnerAction(context, widget.viewerLabel);
        if (!confirmed) return;
      }
      await _openIncomePopup(existing: item);
      return;
    }
    if (action == 'delete') {
      if (widget.viewerUserId != widget.currentUserId) {
        final confirmed = await _confirmPartnerAction(context, widget.viewerLabel);
        if (!confirmed) return;
      }
      final confirmed = await _confirmDeleteIncome(item);
      if (!confirmed) return;
      await _delete(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mergedItems = <_IncomeFeedItem>[
      ..._items.map(
        (income) => _IncomeFeedItem(
          id: income.id,
          kind: _IncomeFeedKind.income,
          amount: income.amount,
          title:
              (income.description != null &&
                  income.description!.trim().isNotEmpty)
              ? income.description!
              : (_sourceById[income.incomeSourceId ?? '']?.name ?? 'Giao dịch'),
          date: income.date,
          createdAt: income.createdAt,
          editableIncome: income,
        ),
      ),
      ..._externalItems,
    ]..sort(_compareBySelectedDateDesc);

    final grouped = <String, Map<String, List<_IncomeFeedItem>>>{};
    for (final item in mergedItems) {
      final monthKey =
          '${item.date.year}-${item.date.month.toString().padLeft(2, '0')}';
      final dayKey = '$monthKey-${item.date.day.toString().padLeft(2, '0')}';
      final byDay = grouped.putIfAbsent(
        monthKey,
        () => <String, List<_IncomeFeedItem>>{},
      );
      byDay.putIfAbsent(dayKey, () => <_IncomeFeedItem>[]).add(item);
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Thu nhập'),
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
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      IncomeSearchFilterScreen(coupleId: widget.coupleId),
                ),
              );
            },
            icon: const Icon(Icons.search),
            tooltip: 'Search & Filter',
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
            : mergedItems.isEmpty
            ? Center(
                child: Text('Chưa có thu nhập nào của ${widget.viewerLabel}.'),
              )
            : ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 90),
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
                        final monthTotal = entry.value.values
                            .expand((rows) => rows)
                            .fold<double>(0, (sum, row) => sum + row.amount);
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(0, 8, 0, 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Tháng ${entry.key.split('-')[1]}/${entry.key.split('-')[0]}',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Text(
                                formatVnd(monthTotal),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    for (final dayEntry in entry.value.entries) ...[
                      Builder(
                        builder: (context) {
                          final dayItems = dayEntry.value;
                          final dayDate = DateTime.parse(dayEntry.key);
                          final dayTotal = dayItems.fold<double>(
                            0,
                            (sum, row) => sum + row.amount,
                          );
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(0, 4, 0, 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    formatDate(dayDate),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Text(
                                  formatVnd(dayTotal),
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      ...dayEntry.value.map((item) {
                        if (item.kind != _IncomeFeedKind.income ||
                            item.editableIncome == null) {
                          final icon = switch (item.kind) {
                            _IncomeFeedKind.fundWithdrawal =>
                              Icons.savings_outlined,
                            _IncomeFeedKind.debtCollection =>
                              Icons.account_balance_wallet_outlined,
                            _IncomeFeedKind.transferReceived =>
                              Icons.move_to_inbox_rounded,
                            _IncomeFeedKind.income => Icons.payments_outlined,
                          };
                          return Container(
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
                                backgroundColor: AppColors.successSoft,
                                child: Icon(
                                  icon,
                                  color: AppColors.success,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                item.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${formatDate(item.date)} · ${formatTimeUtcPlus7(item.createdAt)}',
                              ),
                              trailing: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '+${formatVnd(item.amount)}',
                                    style: const TextStyle(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final income = item.editableIncome!;
                        final source = _sourceById[income.incomeSourceId ?? ''];
                        final iconKey =
                            (source?.icon.trim().isNotEmpty ?? false)
                            ? source!.icon
                            : 'payments';
                        return Container(
                          key: ValueKey(income.id),
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
                              backgroundColor: AppColors.successSoft,
                              child: Icon(
                                iconFromKey(iconKey),
                                color: AppColors.success,
                                size: 20,
                              ),
                            ),
                            onTap: () => _showItemActions(income),
                            title: Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${formatDate(item.date)} · ${formatTimeUtcPlus7(item.createdAt)}',
                            ),
                            trailing: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '+${formatVnd(item.amount)}',
                                  style: const TextStyle(
                                    color: AppColors.success,
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
                await _openIncomePopup();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Thêm thu nhập',
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
              await _openIncomePopup();
            },
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }
}

class _IncomeFormDialog extends StatefulWidget {
  final String coupleId;
  final IncomeModel? existing;

  const _IncomeFormDialog({
    required this.coupleId,
    this.existing,
  });

  @override
  State<_IncomeFormDialog> createState() => _IncomeFormDialogState();
}

class _IncomeFormDialogState extends State<_IncomeFormDialog> {
  final _service = IncomeService();
  bool _isLoading = true;
  String? _error;
  List<IncomeSourceModel> _sources = [];

  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String? _selectedSourceId;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _amountCtrl.text = formatAmountInput(widget.existing!.amount.toStringAsFixed(0));
      _noteCtrl.text = widget.existing!.description ?? '';
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
      final srcs = await _service.getIncomeFormSources(widget.coupleId);
      if (!mounted) return;
      if (srcs.isEmpty) {
        setState(() {
          _error = 'Chưa có nguồn thu nhập.';
          _isLoading = false;
        });
        return;
      }
      setState(() {
        _sources = srcs;
        _selectedSourceId = widget.existing?.incomeSourceId ?? srcs.first.id;
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

    return Dialog(
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
                widget.existing == null ? 'Thêm thu nhập' : 'Sửa thu nhập',
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
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          ThousandsSeparatorInputFormatter(),
                        ],
                        decoration: const InputDecoration(hintText: 'Số tiền'),
                      ),
                      const SizedBox(height: 10),
                      AmountSuggestionChips(
                        controller: _amountCtrl,
                        onSelected: (value) {
                          _amountCtrl.text = formatAmountInput(value.toString());
                        },
                      ),
                      const SizedBox(height: 8),
                      if (_isLoading)
                        const SizedBox(
                          height: 60,
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_error != null || _sources.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            _error ?? 'Chưa có nguồn thu nhập.',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            const spacing = 6.0;
                            final tileWidth =
                                (constraints.maxWidth - (spacing * 4)) / 5;
                            return Wrap(
                              spacing: spacing,
                              runSpacing: spacing,
                              children: _sources.map((s) {
                                final selected = _selectedSourceId == s.id;
                                return SizedBox(
                                  width: tileWidth,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () {
                                        setState(() {
                                          _selectedSourceId = s.id;
                                        });
                                      },
                                      child: Ink(
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? AppColors.successSoft.withValues(
                                                  alpha: 0.6,
                                                )
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: selected
                                                ? AppColors.success
                                                : AppColors.border,
                                            width: selected ? 1.5 : 1,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 2,
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                iconFromKey(
                                                  s.icon.trim().isNotEmpty
                                                      ? s.icon
                                                      : 'payments',
                                                ),
                                                color: selected
                                                    ? AppColors.success
                                                    : Colors.black45,
                                                size: 14,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                s.name,
                                                maxLines: 1,
                                                textAlign: TextAlign.center,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: selected
                                                      ? FontWeight.w700
                                                      : FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      const SizedBox(height: 8),
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
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: (_isLoading || _error != null || _sources.isEmpty)
                          ? null
                          : () async {
                              final amount = parseAmountInput(
                                _amountCtrl.text.trim(),
                              );
                              if (amount == null || amount <= 0) {
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(
                                  const SnackBar(
                                    content: Text('Số tiền không hợp lệ.'),
                                  ),
                                );
                                return;
                              }
                              if (context.mounted) {
                                Navigator.of(context).maybePop(
                                  _IncomeFormResult(
                                    amount: amount,
                                    incomeSourceId: _selectedSourceId!,
                                    description: _noteCtrl.text.trim().isEmpty
                                        ? null
                                        : _noteCtrl.text.trim(),
                                    date: _selectedDate,
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
