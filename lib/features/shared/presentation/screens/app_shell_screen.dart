import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_app_demo/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:flutter_app_demo/features/expense/presentation/screens/expense_list_screen.dart';
import 'package:flutter_app_demo/features/income/presentation/screens/income_list_screen.dart';
import 'package:flutter_app_demo/features/transfer/presentation/screens/transfer_list_screen.dart';
import 'package:flutter_app_demo/features/dashboard/presentation/screens/analytics_screen.dart';
import 'package:flutter_app_demo/features/settings/presentation/screens/create_couple_screen.dart';
import 'package:flutter_app_demo/features/settings/presentation/screens/join_couple_screen.dart';
import 'package:flutter_app_demo/features/settings/presentation/screens/settings_screen.dart';
import 'package:flutter_app_demo/features/expense/presentation/screens/add_expense_screen.dart';
import 'package:flutter_app_demo/features/income/presentation/screens/add_income_screen.dart';
import 'package:flutter_app_demo/features/transfer/presentation/screens/add_transfer_screen.dart';

class AppShellScreen extends StatefulWidget {
  const AppShellScreen({super.key});

  @override
  State<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends State<AppShellScreen> {
  int _selectedIndex = 0;
  String? _coupleId;
  bool _isLoading = true;
  String? _error;

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
      setState(() {
        _coupleId = rows.first['couple_id'] as String;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showAddMenu(BuildContext context, String coupleId) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Material(
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          color: Theme.of(ctx).colorScheme.surface,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Text(
                      'Thêm giao dịch',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.shopping_bag_outlined),
                    title: const Text('Chi tiêu'),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddExpenseScreen(coupleId: coupleId),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.attach_money),
                    title: const Text('Thu nhập'),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddIncomeScreen(coupleId: coupleId),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.swap_horiz),
                    title: const Text('Chuyển tiền'),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddTransferScreen(coupleId: coupleId),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
    final screens = [
      DashboardScreen(coupleId: coupleId),
      ExpenseListScreen(coupleId: coupleId),
      IncomeListScreen(coupleId: coupleId),
      TransferListScreen(coupleId: coupleId),
      AnalyticsScreen(coupleId: coupleId),
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
            label: 'Dashboard',
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
            icon: Icon(Icons.trending_up_outlined),
            activeIcon: Icon(Icons.trending_up),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Cài đặt',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMenu(context, coupleId),
        child: const Icon(Icons.add),
      ),
    );
  }
}
