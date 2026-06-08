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
import 'package:flutter_app_demo/features/expense/data/models/category_model.dart';
import 'package:flutter_app_demo/features/expense/data/models/expense_model.dart';
import 'package:flutter_app_demo/features/expense/data/services/expense_service.dart';
import 'package:flutter_app_demo/features/expense/presentation/screens/expense_search_filter_screen.dart';
import 'package:flutter_app_demo/features/wallet/data/services/wallet_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_app_demo/features/settings/data/models/event_model.dart';
import 'package:flutter_app_demo/features/settings/data/services/event_service.dart';

class ExpenseListScreen extends StatefulWidget {
  final String coupleId;
  final String viewerUserId;
  final String currentUserId;
  final String viewerLabel;
  final String? partnerUserId;
  final VoidCallback? onToggleViewer;
  final ValueListenable<int>? refreshSignal;
  final VoidCallback? onDataChanged;

  const ExpenseListScreen({
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
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseFormResult {
  final double amount;
  final String categoryId;
  final String? description;
  final DateTime date;
  final String? eventId;

  const _ExpenseFormResult({
    required this.amount,
    required this.categoryId,
    required this.description,
    required this.date,
    this.eventId,
  });
}

enum _ExpenseFeedKind { expense, fundContribution, debtPayment, transferSent }

class _ExpenseFeedItem {
  final String id;
  final _ExpenseFeedKind kind;
  final double amount;
  final String title;
  final DateTime date;
  final DateTime createdAt;
  final ExpenseModel? editableExpense;

  const _ExpenseFeedItem({
    required this.id,
    required this.kind,
    required this.amount,
    required this.title,
    required this.date,
    required this.createdAt,
    this.editableExpense,
  });
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  static const int _pageSize = 50;

  final _service = ExpenseService();
  final _walletService = WalletService();
  final ScrollController _scrollController = ScrollController();
  List<ExpenseModel> _items = [];
  List<_ExpenseFeedItem> _externalItems = [];
  Map<String, CategoryModel> _categoryById = {};
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

  int _compareBySelectedDateDesc(_ExpenseFeedItem a, _ExpenseFeedItem b) {
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
  void didUpdateWidget(covariant ExpenseListScreen oldWidget) {
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
        _service.getCategories(widget.coupleId),
        _service.getExpenses(
          widget.coupleId,
          createdByUserId: widget.viewerUserId,
          limit: _pageSize,
          offset: 0,
        ),
        _loadExternalExpenseItems(),
      ]);
      final categories = List<CategoryModel>.from(results[0] as List);
      final items = List<ExpenseModel>.from(results[1] as List);
      final externalItems = results[2] as List<_ExpenseFeedItem>;
      items.sort((a, b) {
        final dateCompare = b.date.compareTo(a.date);
        if (dateCompare != 0) return dateCompare;
        return b.createdAt.compareTo(a.createdAt);
      });
      if (mounted) {
        setState(() {
          _items = items;
          _externalItems = externalItems;
          _categoryById = {for (final c in categories) c.id: c};
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
      final nextItems = await _service.getExpenses(
        widget.coupleId,
        createdByUserId: widget.viewerUserId,
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

  Future<List<_ExpenseFeedItem>> _loadExternalExpenseItems() async {
    final db = Supabase.instance.client;

    var fundsQuery = db
        .from('fund_contributions')
        .select('id, amount, date, created_at, note, fund_id, user_id')
        .eq('couple_id', widget.coupleId)
        .eq('contribution_type', 'contribution')
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
        .select('id, amount, date, created_at, note, from_user_id, to_user_id')
        .eq('couple_id', widget.coupleId)
        .eq('is_deleted', false);

    if (widget.viewerUserId.isNotEmpty) {
      fundsQuery = fundsQuery.eq('user_id', widget.viewerUserId);
      debtQuery = debtQuery.eq('updated_by', widget.viewerUserId);
      transferQuery = transferQuery.eq('from_user_id', widget.viewerUserId);
    }

    final futures = await Future.wait<dynamic>([
      fundsQuery.order('created_at', ascending: false),
      debtQuery.order('created_at', ascending: false),
      transferQuery.order('created_at', ascending: false),
      db.from('funds').select('id, name').eq('couple_id', widget.coupleId),
      db
          .from('debts')
          .select('id, name, note')
          .eq('couple_id', widget.coupleId)
          .eq('is_deleted', false),
    ]);

    final funds = List<Map<String, dynamic>>.from(futures[0] as List);
    final payments = List<Map<String, dynamic>>.from(futures[1] as List);
    final transfers = List<Map<String, dynamic>>.from(futures[2] as List);
    String cleanFundName(String rawName) {
      if (rawName.startsWith('[GOLD]')) {
        final sepIndex = rawName.indexOf('|');
        if (sepIndex != -1) {
          return rawName.substring(6, sepIndex);
        }
        return rawName.substring(6);
      }
      return rawName;
    }
    final fundNameById = {
      for (final row in List<Map<String, dynamic>>.from(futures[3] as List))
        row['id'] as String: cleanFundName(row['name'] as String),
    };
    final debtsList = List<Map<String, dynamic>>.from(futures[4] as List);
    final debtNameById = {
      for (final row in debtsList)
        row['id'] as String: row['name'] as String,
    };
    final bankLoanDebtIds = debtsList
        .where((d) {
          final note = d['note'] as String?;
          if (note == null || !note.trim().startsWith('{')) return false;
          try {
            final data = jsonDecode(note);
            return data['is_bank_loan'] == true;
          } catch (_) {
            return false;
          }
        })
        .map((d) => d['id'] as String)
        .toSet();

    final userIds = <String>{
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

    final externalItems = <_ExpenseFeedItem>[];

    for (final row in funds) {
      final note = (row['note'] as String?)?.trim();
      if (note != null && note.startsWith('[GOLD]')) {
        try {
          final decoded = jsonDecode(note.substring(6));
          if (decoded is Map) {
            final expVal = decoded['record_as_expense'] ?? decoded['recordAsExpense'];
            if (expVal == false) {
              continue; // Skip this contribution!
            }
          }
        } catch (_) {}
      }

      final fundId = row['fund_id'] as String?;
      final fundName =
          (fundId != null ? fundNameById[fundId] : null) ?? 'Quỹ tiết kiệm';
      
      String formattedTitle = 'Đóng góp quỹ: $fundName';
      if (note != null && note.isNotEmpty) {
        if (note.startsWith('[GOLD]')) {
          try {
            final decoded = jsonDecode(note.substring(6));
            if (decoded is Map) {
              final qty = decoded['quantity'] ?? decoded['goldQuantity'] ?? decoded['gold_quantity'] ?? '0';
              final store = (decoded['store'] ?? decoded['shop'] ?? decoded['goldStore'] ?? decoded['gold_store'])?.toString();
              final userNote = (decoded['note'] ?? decoded['cleanNote'] ?? decoded['clean_note'])?.toString();
              formattedTitle = 'Góp $qty chỉ vàng';
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
        } else {
          formattedTitle = note;
        }
      }

      externalItems.add(
        _ExpenseFeedItem(
          id: 'fund-${row['id']}',
          kind: _ExpenseFeedKind.fundContribution,
          amount: (row['amount'] as num).toDouble(),
          title: formattedTitle,
          date: DateTime.parse(row['date'] as String),
          createdAt: DateTime.parse(row['created_at'] as String),
        ),
      );
    }

    for (final row in payments) {
      if (row['linked_income_id'] != null) {
        continue;
      }
      final debtId = row['debt_id'] as String?;
      if (debtId != null && bankLoanDebtIds.contains(debtId)) {
        continue;
      }
      final debtName = (debtId != null ? debtNameById[debtId] : null) ?? 'Nợ';
      final note = (row['note'] as String?)?.trim();
      externalItems.add(
        _ExpenseFeedItem(
          id: 'debt-${row['id']}',
          kind: _ExpenseFeedKind.debtPayment,
          amount: (row['amount'] as num).toDouble(),
          title: (note != null && note.isNotEmpty) ? note : 'Trả nợ: $debtName',
          date: DateTime.parse(row['date'] as String),
          createdAt: DateTime.parse(row['created_at'] as String),
        ),
      );
    }

    for (final row in transfers) {
      final toUserId = row['to_user_id'] as String?;
      final partnerName =
          (toUserId != null ? userNameById[toUserId] : null) ?? 'Người kia';
      final note = (row['note'] as String?)?.trim();
      externalItems.add(
        _ExpenseFeedItem(
          id: 'transfer-${row['id']}',
          kind: _ExpenseFeedKind.transferSent,
          amount: (row['amount'] as num).toDouble(),
          title: (note != null && note.isNotEmpty)
              ? note
              : 'Chuyển cho $partnerName',
          date: DateTime.parse(row['date'] as String),
          createdAt: DateTime.parse(row['created_at'] as String),
        ),
      );
    }

    externalItems.sort(_compareBySelectedDateDesc);
    return externalItems;
  }

  Future<void> _delete(ExpenseModel item) async {
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
      await _service.deleteExpense(item.id);
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

  Future<void> _createExpenseOptimistic({
    required String walletId,
    required _ExpenseFormResult payload,
  }) async {
    final uid = Supabase.instance.client.auth.currentUser!.id;
    final now = DateTime.now();
    final tempId = 'temp-expense-${now.microsecondsSinceEpoch}';
    final optimistic = ExpenseModel(
      id: tempId,
      coupleId: widget.coupleId,
      userId: uid,
      walletId: walletId,
      categoryId: payload.categoryId,
      categoryName: _categoryById[payload.categoryId]?.name,
      categoryIcon: null,
      amount: payload.amount,
      description: payload.description,
      date: payload.date,
      createdAt: now,
      updatedAt: now,
      updatedBy: uid,
      isDeleted: false,
      deletedAt: null,
      eventId: payload.eventId,
    );

    if (mounted) {
      setState(() {
        _items.insert(0, optimistic);
      });
    }

    try {
      final created = await _service.createExpense(
        coupleId: widget.coupleId,
        userId: uid,
        walletId: walletId,
        categoryId: payload.categoryId,
        amount: payload.amount,
        description: payload.description,
        date: payload.date,
        eventId: payload.eventId,
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

  Future<bool> _confirmDeleteExpense(ExpenseModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận xóa chi tiêu'),
        content: Text(
          'Nếu xác nhận xóa, bạn sẽ được hoàn lại ${formatVnd(item.amount)} vào số dư ví. Không phát sinh giao dịch bổ trợ mới.',
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

  Future<void> _openExpensePopup({ExpenseModel? existing}) async {
    final payload = await showGeneralDialog<_ExpenseFormResult>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: Duration.zero,
      pageBuilder: (dialogContext, anim1, anim2) => _ExpenseFormDialog(
        coupleId: widget.coupleId,
        existing: existing,
      ),
    );

    if (payload == null) return;

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
      await _createExpenseOptimistic(walletId: walletId, payload: payload);
      return;
    }

    try {
      await _runMutation(() async {
        await _service.updateExpense(
          expenseId: existing.id,
          walletId: walletId,
          categoryId: payload.categoryId,
          amount: payload.amount,
          description: payload.description,
          date: payload.date,
          eventId: payload.eventId,
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
      if (widget.viewerUserId != widget.currentUserId) {
        final confirmed = await _confirmPartnerAction(context, widget.viewerLabel);
        if (!confirmed) return;
      }
      await _openExpensePopup(existing: item);
      return;
    }
    if (action == 'delete') {
      if (widget.viewerUserId != widget.currentUserId) {
        final confirmed = await _confirmPartnerAction(context, widget.viewerLabel);
        if (!confirmed) return;
      }
      final confirmed = await _confirmDeleteExpense(item);
      if (!confirmed) return;
      await _delete(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mergedItems = <_ExpenseFeedItem>[
      ..._items.map(
        (expense) => _ExpenseFeedItem(
          id: expense.id,
          kind: _ExpenseFeedKind.expense,
          amount: expense.amount,
          title:
              (expense.description != null &&
                  expense.description!.trim().isNotEmpty)
              ? expense.description!
              : (_categoryById[expense.categoryId]?.name ??
                    expense.categoryName ??
                    'Giao dịch'),
          date: expense.date,
          createdAt: expense.createdAt,
          editableExpense: expense,
        ),
      ),
      ..._externalItems,
    ]..sort(_compareBySelectedDateDesc);

    final grouped = <String, Map<String, List<_ExpenseFeedItem>>>{};
    for (final item in mergedItems) {
      final monthKey =
          '${item.date.year}-${item.date.month.toString().padLeft(2, '0')}';
      final dayKey = '$monthKey-${item.date.day.toString().padLeft(2, '0')}';
      final byDay = grouped.putIfAbsent(
        monthKey,
        () => <String, List<_ExpenseFeedItem>>{},
      );
      byDay.putIfAbsent(dayKey, () => <_ExpenseFeedItem>[]).add(item);
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Chi tiêu'),
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
                      ExpenseSearchFilterScreen(coupleId: widget.coupleId),
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
                child: Text('Chưa có chi tiêu nào của ${widget.viewerLabel}.'),
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
                        if (item.kind != _ExpenseFeedKind.expense ||
                            item.editableExpense == null) {
                          final icon = switch (item.kind) {
                            _ExpenseFeedKind.fundContribution =>
                              Icons.savings_outlined,
                            _ExpenseFeedKind.debtPayment => Icons.credit_card,
                            _ExpenseFeedKind.transferSent => Icons.send_rounded,
                            _ExpenseFeedKind.expense =>
                              Icons.shopping_bag_outlined,
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
                                backgroundColor: AppColors.dangerSoft,
                                child: Icon(
                                  icon,
                                  color: AppColors.danger,
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
                              trailing: Text(
                                '-${formatVnd(item.amount)}',
                                style: const TextStyle(
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        }

                        final expense = item.editableExpense!;
                        final category = _categoryById[expense.categoryId];
                        final iconKey =
                            (category?.icon.trim().isNotEmpty ?? false)
                            ? category!.icon
                            : ((expense.categoryIcon?.trim().isNotEmpty ??
                                      false)
                                  ? expense.categoryIcon!
                                  : 'shopping_bag');
                        return Container(
                          key: ValueKey(expense.id),
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
                              backgroundColor: AppColors.dangerSoft,
                              child: Icon(
                                iconFromKey(iconKey),
                                color: AppColors.danger,
                                size: 20,
                              ),
                            ),
                            onTap: () => _showItemActions(expense),
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
                                  '-${formatVnd(item.amount)}',
                                  style: const TextStyle(
                                    color: AppColors.danger,
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
                await _openExpensePopup();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Thêm chi tiêu',
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
              await _openExpensePopup();
            },
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }
}

class _ExpenseFormDialog extends StatefulWidget {
  final String coupleId;
  final ExpenseModel? existing;

  const _ExpenseFormDialog({
    required this.coupleId,
    this.existing,
  });

  @override
  State<_ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<_ExpenseFormDialog> {
  final _service = ExpenseService();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  List<CategoryModel> _categories = [];
  List<EventModel> _allEvents = [];
  bool _isLoading = true;

  late String _selectedCategoryId;
  late DateTime _selectedDate;
  String? _selectedEventId;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.existing?.date ?? DateTime.now();
    _selectedEventId = widget.existing?.eventId;

    if (widget.existing != null) {
      _amountCtrl.text = formatAmountInput(widget.existing!.amount.toStringAsFixed(0));
      _noteCtrl.text = widget.existing!.description ?? '';
    }

    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _service.getExpenseFormCategories(widget.coupleId),
        EventService().getEvents(widget.coupleId),
      ]);
      if (mounted) {
        setState(() {
          _categories = List<CategoryModel>.from(results[0] as List<CategoryModel>);
          _allEvents = List<EventModel>.from(results[1] as List<EventModel>);
          _selectedCategoryId = widget.existing?.categoryId ?? (_categories.isNotEmpty ? _categories.first.id : '');
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải dữ liệu: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
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
          maxHeight: media.height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null ? 'Thêm chi tiêu' : 'Sửa chi tiêu',
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
                        decoration: const InputDecoration(
                          hintText: 'Số tiền',
                        ),
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
                      else if (_categories.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Chưa có danh mục chi tiêu.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        )
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            const spacing = 6.0;
                            final tileWidth = (constraints.maxWidth - (spacing * 4)) / 5;
                            return Wrap(
                              spacing: spacing,
                              runSpacing: spacing,
                              children: _categories.map((c) {
                                final selected = _selectedCategoryId == c.id;
                                final icon = iconFromKey(c.icon);
                                return SizedBox(
                                  width: tileWidth,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () {
                                        setState(() {
                                          _selectedCategoryId = c.id;
                                        });
                                      },
                                      child: Ink(
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? AppColors.tealSoft.withValues(
                                                  alpha: 0.24,
                                                )
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: selected
                                                ? AppColors.tealDeep
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
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                icon,
                                                color: selected
                                                    ? AppColors.tealDeep
                                                    : Colors.black45,
                                                size: 14,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                c.name,
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
                        decoration: const InputDecoration(
                          hintText: 'Ghi chú',
                        ),
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
                            setState(() {
                              _selectedDate = picked;
                              if (_selectedEventId != null && _allEvents.isNotEmpty) {
                                final ev = _allEvents.firstWhere(
                                  (e) => e.id == _selectedEventId,
                                  orElse: () => _allEvents.first,
                                );
                                final dateOnly = DateTime(picked.year, picked.month, picked.day);
                                final startOnly = DateTime(ev.startDate.year, ev.startDate.month, ev.startDate.day);
                                final endOnly = DateTime(ev.endDate.year, ev.endDate.month, ev.endDate.day);
                                final isValid = !dateOnly.isBefore(startOnly) && !dateOnly.isAfter(endOnly);
                                if (!isValid && _selectedEventId != widget.existing?.eventId) {
                                  _selectedEventId = null;
                                }
                              }
                            });
                          }
                        },
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text('Ngày: ${formatDate(_selectedDate)}'),
                      ),
                      if (!_isLoading && _allEvents.isNotEmpty) ...[
                        Builder(
                          builder: (context) {
                            final dateOnly = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
                            final matchingEvents = _allEvents.where((e) {
                              if (_selectedEventId == e.id) return true;
                              final startOnly = DateTime(e.startDate.year, e.startDate.month, e.startDate.day);
                              final endOnly = DateTime(e.endDate.year, e.endDate.month, e.endDate.day);
                              return !dateOnly.isBefore(startOnly) && !dateOnly.isAfter(endOnly);
                            }).toList();

                            if (matchingEvents.isEmpty) return const SizedBox();
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 14),
                                const Text(
                                    'Sự kiện diễn ra trong ngày này:',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: matchingEvents.map((event) {
                                      final isSelected = _selectedEventId == event.id;
                                      return ChoiceChip(
                                        label: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.event_note,
                                              size: 14,
                                              color: isSelected ? Colors.white : AppColors.tealDeep,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(event.name),
                                          ],
                                        ),
                                        selected: isSelected,
                                        selectedColor: AppColors.tealDeep,
                                        labelStyle: TextStyle(
                                          color: isSelected ? Colors.white : Colors.black87,
                                          fontSize: 12,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                        onSelected: (bool selected) {
                                          setState(() {
                                            if (selected) {
                                              _selectedEventId = event.id;
                                            } else {
                                              _selectedEventId = null;
                                            }
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                              ],
                            );
                          }
                        ),
                      ],
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
                      onPressed: _isLoading ? null : () {
                        final amount = parseAmountInput(_amountCtrl.text.trim());
                        if (amount == null || amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Số tiền không hợp lệ.'),
                            ),
                          );
                          return;
                        }
                        Navigator.of(context).maybePop(
                          _ExpenseFormResult(
                            amount: amount,
                            categoryId: _selectedCategoryId,
                            description: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
                            date: _selectedDate,
                            eventId: _selectedEventId,
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
    );
  }
}

