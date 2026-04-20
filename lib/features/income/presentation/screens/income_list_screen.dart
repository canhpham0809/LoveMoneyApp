import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_app_demo/core/utils/amount_input.dart';
import 'package:flutter_app_demo/core/widgets/amount_suggestion_chips.dart';
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
  final _service = IncomeService();
  final _walletService = WalletService();
  List<IncomeModel> _items = [];
  List<_IncomeFeedItem> _externalItems = [];
  Map<String, String> _sourceNameById = {};
  bool _isLoading = true;
  bool _isDeleting = false;
  String? _error;

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
      final results = await Future.wait<dynamic>([
        _service.getIncomes(
          widget.coupleId,
          createdByUserId: widget.viewerUserId,
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

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) {
        setState(() {
          _items = items;
          _externalItems = external.items;
          _sourceNameById = {for (final s in sources) s.id: s.name};
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (showLoader && mounted) setState(() => _isLoading = false);
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
      db
          .from('funds')
          .select('id, name')
          .eq('couple_id', widget.coupleId)
          .eq('is_deleted', false),
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
      final linkedIncomeId = row['linked_income_id'] as String?;
      if (linkedIncomeId != null) {
        linkedIncomeIds.add(linkedIncomeId);
      }
      final fundId = row['fund_id'] as String?;
      final fundName =
          (fundId != null ? fundNameById[fundId] : null) ?? 'Quỹ tiết kiệm';
      final note = (row['note'] as String?)?.trim();
      items.add(
        _IncomeFeedItem(
          id: 'fund-${row['id']}',
          kind: _IncomeFeedKind.fundWithdrawal,
          amount: (row['amount'] as num).toDouble(),
          title: (note != null && note.isNotEmpty) ? note : fundName,
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
          title: (note != null && note.isNotEmpty) ? note : debtName,
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

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
      final created = await _service.createIncome(
        coupleId: widget.coupleId,
        userId: uid,
        walletId: walletId,
        incomeSourceId: payload.incomeSourceId,
        amount: payload.amount,
        description: payload.description,
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

  Future<void> _openIncomePopup({IncomeModel? existing}) async {
    final sources = await _service.getIncomeFormSources(widget.coupleId);
    if (!mounted) return;
    if (sources.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Chưa có nguồn thu nhập.')));
      return;
    }
    final walletId = await _resolveDefaultWalletId();
    if (!mounted) return;
    if (walletId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Chưa có ví để ghi nhận.')));
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

    final payload = await showDialog<_IncomeFormResult>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: Text(existing == null ? 'Thêm thu nhập' : 'Sửa thu nhập'),
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
                      labelText: 'Số tiền',
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: sources
                        .map(
                          (s) => ChoiceChip(
                            label: Text(
                              s.name,
                              style: const TextStyle(
                                fontSize: 10,
                              ), // nhỏ font lại
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 0,
                            ), // giảm padding
                            visualDensity: const VisualDensity(
                              horizontal: -4,
                              vertical: -4,
                            ), // bóp thêm
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            showCheckmark: false,
                            selected: selectedSourceId == s.id,
                            onSelected: (_) {
                              setDialogState(() {
                                selectedSourceId = s.id;
                              });
                            },
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Ghi chú',
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
                    label: Text('Ngày: ${formatDate(selectedDate)}'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).maybePop(),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () async {
                  final amount = parseAmountInput(amountCtrl.text.trim());
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Số tiền không hợp lệ.')),
                    );
                    return;
                  }

                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).maybePop(
                      _IncomeFormResult(
                        amount: amount,
                        incomeSourceId: selectedSourceId,
                        description: noteCtrl.text.trim().isEmpty
                            ? null
                            : noteCtrl.text.trim(),
                        date: selectedDate,
                      ),
                    );
                  }
                },
                child: const Text('Lưu'),
              ),
            ],
          ),
        );
      },
    );

    if (payload == null) return;

    if (existing == null) {
      await _createIncomeOptimistic(walletId: walletId, payload: payload);
      return;
    }

    try {
      await _service.updateIncome(
        incomeId: existing.id,
        walletId: walletId,
        incomeSourceId: payload.incomeSourceId,
        amount: payload.amount,
        description: payload.description,
        date: payload.date,
      );
      await _load(showLoader: false);
      widget.onDataChanged?.call();
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
      await _openIncomePopup(existing: item);
      return;
    }
    if (action == 'delete') {
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
              : (_sourceNameById[income.incomeSourceId ?? ''] ?? 'Giao dịch'),
          date: income.date,
          createdAt: income.createdAt,
          editableIncome: income,
        ),
      ),
      ..._externalItems,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final grouped = <String, List<_IncomeFeedItem>>{};
    for (final item in mergedItems) {
      final key =
          '${item.date.year}-${item.date.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => <_IncomeFeedItem>[]).add(item);
    }

    return Scaffold(
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
          : mergedItems.isEmpty
          ? Center(
              child: Text('Chưa có thu nhập nào của ${widget.viewerLabel}.'),
            )
          : ListView(
              children: [
                for (final entry in grouped.entries) ...[
                  Builder(
                    builder: (context) {
                      final monthTotal = entry.value.fold<double>(
                        0,
                        (sum, row) => sum + row.amount,
                      );
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  ...entry.value.map((item) {
                    if (item.kind != _IncomeFeedKind.income ||
                        item.editableIncome == null) {
                      final icon = switch (item.kind) {
                        _IncomeFeedKind.fundWithdrawal =>
                          Icons.south_west_rounded,
                        _IncomeFeedKind.debtCollection =>
                          Icons.account_balance_wallet_outlined,
                        _IncomeFeedKind.transferReceived => Icons.swap_horiz,
                        _IncomeFeedKind.income => Icons.attach_money,
                      };
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.withOpacity(0.12),
                          child: Icon(icon, color: Colors.green[700]),
                        ),
                        title: Text(item.title),
                        subtitle: Text(
                          '${formatDate(item.date)} · ${formatTimeUtcPlus7(item.createdAt)}',
                        ),
                        trailing: Text(
                          formatVnd(item.amount),
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }

                    final income = item.editableIncome!;
                    return ListTile(
                      key: ValueKey(income.id),
                      leading: const CircleAvatar(
                        child: Icon(Icons.attach_money),
                      ),
                      onLongPress: () => _showItemActions(income),
                      title: Text(item.title),
                      subtitle: Text(
                        '${formatDate(item.date)} · ${formatTimeUtcPlus7(item.createdAt)}',
                      ),
                      trailing: Text(
                        formatVnd(item.amount),
                        style: TextStyle(
                          color: Colors.green[700],
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
          await _openIncomePopup();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
