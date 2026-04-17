import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_app_demo/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:flutter_app_demo/features/expense/presentation/screens/expense_list_screen.dart';
import 'package:flutter_app_demo/features/income/presentation/screens/income_list_screen.dart';
import 'package:flutter_app_demo/features/transfer/presentation/screens/transfer_list_screen.dart';
import 'package:flutter_app_demo/features/settings/presentation/screens/create_couple_screen.dart';
import 'package:flutter_app_demo/features/settings/presentation/screens/join_couple_screen.dart';
import 'package:flutter_app_demo/features/settings/presentation/screens/settings_screen.dart';
import 'package:flutter_app_demo/features/fund/presentation/screens/fund_list_screen.dart';
import 'package:flutter_app_demo/features/debt/presentation/screens/debt_list_screen.dart';
import 'package:flutter_app_demo/features/shared/data/services/quick_add_service.dart';
import 'package:flutter_app_demo/features/expense/data/services/expense_service.dart';

class AppShellScreen extends StatefulWidget {
  const AppShellScreen({super.key});

  @override
  State<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends State<AppShellScreen> {
  int _selectedIndex = 0;
  String? _coupleId;
  String? _currentUserId;
  String? _viewerUserId;
  String? _selfLabel;
  String? _partnerUserId;
  String? _partnerLabel;
  bool _isLoading = true;
  String? _error;
  final ValueNotifier<int> _dashboardRefreshBus = ValueNotifier<int>(0);
  final ValueNotifier<int> _expenseRefreshBus = ValueNotifier<int>(0);
  final ValueNotifier<int> _incomeRefreshBus = ValueNotifier<int>(0);
  final ValueNotifier<int> _transferRefreshBus = ValueNotifier<int>(0);
  final ValueNotifier<int> _fundRefreshBus = ValueNotifier<int>(0);
  final ValueNotifier<int> _debtRefreshBus = ValueNotifier<int>(0);
  final _quickAddService = QuickAddService();
  final _expenseService = ExpenseService();
  int _quickAddSnackVersion = 0;

  void _markExpenseChanged() {
    _dashboardRefreshBus.value += 1;
    _expenseRefreshBus.value += 1;
  }

  void _markIncomeChanged() {
    _dashboardRefreshBus.value += 1;
    _incomeRefreshBus.value += 1;
  }

  void _markTransferChanged() {
    _dashboardRefreshBus.value += 1;
    _transferRefreshBus.value += 1;
  }

  void _markFundChanged() {
    _dashboardRefreshBus.value += 1;
  }

  void _markDebtChanged() {
    _dashboardRefreshBus.value += 1;
  }

  @override
  void dispose() {
    _dashboardRefreshBus.dispose();
    _expenseRefreshBus.dispose();
    _incomeRefreshBus.dispose();
    _transferRefreshBus.dispose();
    _fundRefreshBus.dispose();
    _debtRefreshBus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _resolveCoupleId();
  }

  Future<void> _resolveCoupleId() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) {
        setState(() {
          _error = 'Không tìm thấy phiên đăng nhập.';
          _isLoading = false;
        });
        return;
      }
      final rows = await Supabase.instance.client
          .from('couple_members')
          .select('couple_id')
          .eq('user_id', uid)
          .eq('is_deleted', false)
          .limit(1);
      if (rows.isEmpty) {
        setState(() {
          _error =
              'Bạn chưa thuộc couple nào. Hãy tạo hoặc tham gia một couple.';
          _isLoading = false;
        });
        return;
      }
      final coupleId = rows.first['couple_id'] as String;
      final members = await Supabase.instance.client
          .from('couple_members')
          .select('user_id')
          .eq('couple_id', coupleId)
          .eq('is_deleted', false);
      final memberIds = members
          .map((m) => m['user_id'] as String)
          .toSet()
          .toList();

      final users = memberIds.isEmpty
          ? <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              await Supabase.instance.client
                  .from('users')
                  .select('id, display_name, email')
                  .inFilter('id', memberIds),
            );
      final userDisplay = {
        for (final u in users)
          u['id'] as String:
              ((u['display_name'] as String?)?.trim().isNotEmpty == true
              ? (u['display_name'] as String).trim()
              : ((u['email'] as String?) ?? 'User')),
      };
      final partnerId = memberIds
          .where((id) => id != uid)
          .cast<String?>()
          .firstWhere((id) => id != null, orElse: () => null);

      setState(() {
        _coupleId = coupleId;
        _currentUserId = uid;
        _viewerUserId = uid;
        _selfLabel = userDisplay[uid] ?? 'Tôi';
        _partnerUserId = partnerId;
        _partnerLabel = partnerId == null
            ? null
            : (userDisplay[partnerId] ?? 'Partner');
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _toggleViewer() {
    final current = _currentUserId;
    final partner = _partnerUserId;
    final viewing = _viewerUserId;
    if (current == null || partner == null || viewing == null) return;

    setState(() {
      _viewerUserId = viewing == current ? partner : current;
    });

    _dashboardRefreshBus.value += 1;
    _expenseRefreshBus.value += 1;
    _incomeRefreshBus.value += 1;
    _transferRefreshBus.value += 1;
  }

  Future<void> _openQuickAddDialog(String coupleId) async {
    final categories = await _expenseService.getCategories(coupleId);
    if (!mounted) return;

    final ctrl = TextEditingController();
    String? selectedCategoryId;
    String? selectedCategoryName;
    final payload = await showDialog<Map<String, String?>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Quick Add'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Vi du: 50k breakfast',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tag danh muc',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                if (categories.isEmpty)
                  const Text(
                    'Chua co danh muc chi tieu.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories
                        .map(
                          (c) => ChoiceChip(
                            label: Text(c.name),
                            labelStyle: const TextStyle(fontSize: 12),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 0,
                            ),
                            selected: selectedCategoryId == c.id,
                            onSelected: (_) {
                              setDialogState(() {
                                if (selectedCategoryId == c.id) {
                                  selectedCategoryId = null;
                                  selectedCategoryName = null;
                                } else {
                                  selectedCategoryId = c.id;
                                  selectedCategoryName = c.name;
                                }
                              });
                            },
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Huy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'input': ctrl.text.trim(),
                'categoryId': selectedCategoryId,
                'categoryName': selectedCategoryName,
              }),
              child: const Text('Luu nhanh'),
            ),
          ],
        ),
      ),
    );

    final input = payload?['input']?.trim();
    final forcedCategoryId = payload?['categoryId'];
    final forcedCategoryName = payload?['categoryName'];

    if (!mounted || input == null || input.isEmpty) return;

    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      final result = await _quickAddService.quickAddExpense(
        coupleId: coupleId,
        userId: uid,
        input: input,
        forcedCategoryId: forcedCategoryId,
        forcedCategoryName: forcedCategoryName,
      );

      if (!mounted) return;

      if (!result.success && result.fallbackRequired) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Khong parse duoc Quick Add. Vui long qua man Chi tieu de nhap form.',
            ),
          ),
        );
        return;
      }

      if (result.expense != null) {
        _markExpenseChanged();
        final messenger = ScaffoldMessenger.of(context);
        _quickAddSnackVersion += 1;
        final version = _quickAddSnackVersion;
        messenger
          ..hideCurrentSnackBar()
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 3),
              content: Text(
                'Da luu nhanh ${result.parsedAmount?.toStringAsFixed(0) ?? ''} vao ${result.suggestedCategoryName ?? 'danh muc mac dinh'}',
              ),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () async {
                  await _expenseService.deleteExpense(result.expense!.id);
                },
              ),
            ),
          );

        unawaited(
          Future<void>.delayed(const Duration(seconds: 3), () {
            if (!mounted || version != _quickAddSnackVersion) {
              return;
            }
            messenger.hideCurrentSnackBar();
          }),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Quick Add that bai: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _coupleId == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 48),
                const SizedBox(height: 16),
                Text(
                  _error ?? 'Lỗi không xác định',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    final created = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateCoupleScreen(),
                      ),
                    );
                    if (created == true && mounted) {
                      setState(() {
                        _isLoading = true;
                        _error = null;
                      });
                      await _resolveCoupleId();
                    }
                  },
                  icon: const Icon(Icons.favorite_outline),
                  label: const Text('Tạo couple mới'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final joined = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const JoinCoupleScreen(),
                      ),
                    );
                    if (joined == true && mounted) {
                      setState(() {
                        _isLoading = true;
                        _error = null;
                      });
                      await _resolveCoupleId();
                    }
                  },
                  icon: const Icon(Icons.group_add_outlined),
                  label: const Text('Tham gia bằng mã'),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    await Supabase.instance.client.auth.signOut();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Đăng xuất'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final coupleId = _coupleId!;
    final currentUserId = _currentUserId;
    final viewerUserId = _viewerUserId;
    if (currentUserId == null || viewerUserId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final viewerLabel = viewerUserId == currentUserId
        ? (_selfLabel ?? 'Tôi')
        : (_partnerLabel ?? 'Partner');

    final screens = [
      DashboardScreen(
        coupleId: coupleId,
        viewerUserId: viewerUserId,
        currentUserId: currentUserId,
        viewerLabel: viewerLabel,
        partnerUserId: _partnerUserId,
        onToggleViewer: _toggleViewer,
        refreshSignal: _dashboardRefreshBus,
        onCreatePressed: () => _openQuickAddDialog(coupleId),
      ),
      ExpenseListScreen(
        coupleId: coupleId,
        viewerUserId: viewerUserId,
        currentUserId: currentUserId,
        viewerLabel: viewerLabel,
        partnerUserId: _partnerUserId,
        onToggleViewer: _toggleViewer,
        refreshSignal: _expenseRefreshBus,
        onDataChanged: _markExpenseChanged,
      ),
      IncomeListScreen(
        coupleId: coupleId,
        viewerUserId: viewerUserId,
        currentUserId: currentUserId,
        viewerLabel: viewerLabel,
        partnerUserId: _partnerUserId,
        onToggleViewer: _toggleViewer,
        refreshSignal: _incomeRefreshBus,
        onDataChanged: _markIncomeChanged,
      ),
      TransferListScreen(
        coupleId: coupleId,
        viewerUserId: viewerUserId,
        currentUserId: currentUserId,
        viewerLabel: viewerLabel,
        partnerUserId: _partnerUserId,
        onToggleViewer: _toggleViewer,
        refreshSignal: _transferRefreshBus,
        onDataChanged: _markTransferChanged,
      ),
      FundListScreen(
        coupleId: coupleId,
        refreshSignal: _fundRefreshBus,
        onDataChanged: _markFundChanged,
      ),
      DebtListScreen(
        coupleId: coupleId,
        refreshSignal: _debtRefreshBus,
        onDataChanged: _markDebtChanged,
      ),
      SettingsScreen(coupleId: coupleId),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag_outlined),
            activeIcon: Icon(Icons.shopping_bag),
            label: 'Chi tiêu',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            label: 'Thu nhập',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.swap_horiz),
            label: 'Chuyển tiền',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.savings_outlined),
            activeIcon: Icon(Icons.savings),
            label: 'Quỹ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.credit_card_outlined),
            activeIcon: Icon(Icons.credit_card),
            label: 'Nợ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Cài đặt',
          ),
        ],
      ),
    );
  }
}
