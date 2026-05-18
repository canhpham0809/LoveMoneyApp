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
import 'package:flutter_app_demo/features/expense/data/models/category_model.dart';
import 'package:flutter_app_demo/core/theme/app_colors.dart';
import 'package:flutter_app_demo/core/utils/category_visuals.dart';

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
  List<CategoryModel> _quickAddCategoriesCache = const [];
  bool _isWarmingQuickAddCategories = false;

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
    _expenseRefreshBus.value += 1;
    _incomeRefreshBus.value += 1;
  }

  void _markFundChanged() {
    _dashboardRefreshBus.value += 1;
    _expenseRefreshBus.value += 1;
    _incomeRefreshBus.value += 1;
  }

  void _markDebtChanged() {
    _dashboardRefreshBus.value += 1;
    _expenseRefreshBus.value += 1;
    _incomeRefreshBus.value += 1;
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
            : (userDisplay[partnerId] ?? 'Người kia');
        _isLoading = false;
      });

      unawaited(_warmQuickAddCategories(coupleId));
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _warmQuickAddCategories(
    String coupleId, {
    bool force = false,
  }) async {
    if (_isWarmingQuickAddCategories) return;
    if (!force && _quickAddCategoriesCache.isNotEmpty) return;

    _isWarmingQuickAddCategories = true;
    try {
      final categories = await _expenseService.getQuickAddCategories(coupleId);
      if (!mounted) return;
      setState(() {
        _quickAddCategoriesCache = categories;
      });
    } catch (_) {
      // Ignore prefetch failures; fallback still works when user submits.
    } finally {
      _isWarmingQuickAddCategories = false;
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
  }

  Future<void> _showSwitchBackToSelfAlert() async {
    final viewingLabel = _viewerUserId == _currentUserId
        ? (_selfLabel ?? 'Tôi')
        : (_partnerLabel ?? 'Người kia');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Không thể thêm'),
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
              _toggleViewer();
            },
            child: const Text('Chuyển về tôi'),
          ),
        ],
      ),
    );
  }

  Future<void> _openQuickAddDialog(String coupleId) async {
    var categories = _quickAddCategoriesCache;
    if (categories.isEmpty) {
      await _warmQuickAddCategories(coupleId, force: true);
      categories = _quickAddCategoriesCache;
    } else {
      unawaited(_warmQuickAddCategories(coupleId, force: true));
    }
    if (!mounted) return;

    final ctrl = TextEditingController();
    String? selectedCategoryId = categories.isNotEmpty
        ? categories.first.id
        : null;
    String? selectedCategoryName = categories.isNotEmpty
        ? categories.first.name
        : null;
    final payload = await showDialog<Map<String, String?>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final media = MediaQuery.of(dialogContext).size;
          return Dialog(
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
                      const Text(
                        'Thêm nhanh chi tiêu',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: ctrl,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Vi du: 50k breakfast',
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (categories.isEmpty)
                        const Text(
                          'Chưa có danh mục chi tiêu.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        )
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            const spacing = 8.0;
                            final tileWidth =
                                (constraints.maxWidth - (spacing * 2)) / 3;
                            return Wrap(
                              spacing: spacing,
                              runSpacing: spacing,
                              children: categories.map((c) {
                                final selected = selectedCategoryId == c.id;
                                return SizedBox(
                                  width: tileWidth,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () {
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
                                      child: Ink(
                                        height: 72,
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? AppColors.tealSoft.withValues(
                                                  alpha: 0.24,
                                                )
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: selected
                                                ? AppColors.tealDeep
                                                : AppColors.border,
                                            width: selected ? 1.8 : 1,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 4,
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                                Icon(
                                                  iconFromKey(c.icon),
                                                  color: selected
                                                      ? AppColors.tealDeep
                                                      : Colors.black45,
                                                  size: 18,
                                                ),
                                              const SizedBox(height: 4),
                                              Text(
                                                c.name,
                                                maxLines: 2,
                                                textAlign: TextAlign.center,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 11,
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
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Hủy'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => Navigator.pop(dialogContext, {
                                'input': ctrl.text.trim(),
                                'categoryId': selectedCategoryId,
                                'categoryName': selectedCategoryName,
                              }),
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
        },
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
              'Không parse được Quick Add. Vui lòng qua màn Chi tiêu để nhập form.',
            ),
          ),
        );
        return;
      }

      if (result.expense != null) {
        _markExpenseChanged();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Quick Add thất bại: $e')));
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
        : (_partnerLabel ?? 'Người kia');
    final counterpartyUserId = viewerUserId == currentUserId
        ? _partnerUserId
        : currentUserId;

    final screens = [
      DashboardScreen(
        coupleId: coupleId,
        viewerUserId: viewerUserId,
        currentUserId: currentUserId,
        viewerLabel: viewerLabel,
        partnerUserId: counterpartyUserId,
        selfLabel: _selfLabel,
        partnerLabel: _partnerLabel,
        onToggleViewer: _toggleViewer,
        refreshSignal: _dashboardRefreshBus,
        onDataChanged: _markIncomeChanged,
        onCreatePressed: () async {
          if (_viewerUserId != _currentUserId) {
            await _showSwitchBackToSelfAlert();
            return;
          }
          await _openQuickAddDialog(coupleId);
        },
      ),
      ExpenseListScreen(
        coupleId: coupleId,
        viewerUserId: viewerUserId,
        currentUserId: currentUserId,
        viewerLabel: viewerLabel,
        partnerUserId: counterpartyUserId,
        onToggleViewer: _toggleViewer,
        refreshSignal: _expenseRefreshBus,
        onDataChanged: _markExpenseChanged,
      ),
      IncomeListScreen(
        coupleId: coupleId,
        viewerUserId: viewerUserId,
        currentUserId: currentUserId,
        viewerLabel: viewerLabel,
        partnerUserId: counterpartyUserId,
        onToggleViewer: _toggleViewer,
        refreshSignal: _incomeRefreshBus,
        onDataChanged: _markIncomeChanged,
      ),
      TransferListScreen(
        coupleId: coupleId,
        viewerUserId: viewerUserId,
        currentUserId: currentUserId,
        viewerLabel: viewerLabel,
        partnerUserId: counterpartyUserId,
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
      SettingsScreen(
        coupleId: coupleId,
        onProfileUpdated: () {
          _resolveCoupleId();
        },
      ),
    ];

    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 800;

    if (isLargeScreen) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: screenWidth > 1100,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              backgroundColor: Theme.of(context).cardColor,
              selectedIconTheme: const IconThemeData(color: AppColors.tealDeep),
              selectedLabelTextStyle: const TextStyle(
                color: AppColors.tealDeep,
                fontWeight: FontWeight.bold,
              ),
              unselectedIconTheme: const IconThemeData(color: Colors.black45),
              unselectedLabelTextStyle: const TextStyle(
                color: Colors.black45,
              ),
              leading: Column(
                children: [
                  const SizedBox(height: 24),
                  Icon(
                    Icons.favorite_rounded,
                    color: AppColors.tealDeep,
                    size: 32,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.shopping_bag_outlined),
                  selectedIcon: Icon(Icons.shopping_bag),
                  label: Text('Chi tiêu'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.attach_money),
                  selectedIcon: Icon(Icons.monetization_on),
                  label: Text('Thu nhập'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.swap_horiz),
                  selectedIcon: Icon(Icons.swap_horizontal_circle),
                  label: Text('Chuyển khoản'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.savings_outlined),
                  selectedIcon: Icon(Icons.savings),
                  label: Text('Quỹ tích lũy'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.credit_card_outlined),
                  selectedIcon: Icon(Icons.credit_card),
                  label: Text('Ghi nợ'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Cài đặt'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: screens,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
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
            label: 'Chi',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.attach_money), label: 'Thu'),
          BottomNavigationBarItem(
            icon: Icon(Icons.swap_horiz),
            label: 'Chuyển',
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
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
