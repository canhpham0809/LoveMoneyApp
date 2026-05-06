import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_app_demo/core/services/notification_service.dart';
import 'package:flutter_app_demo/features/settings/data/services/settings_service.dart';
import 'package:flutter_app_demo/features/settings/presentation/screens/debt_type_management_screen.dart';
import 'package:flutter_app_demo/features/settings/presentation/screens/expense_category_management_screen.dart';
import 'package:flutter_app_demo/features/settings/presentation/screens/income_source_management_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String coupleId;
  final VoidCallback? onProfileUpdated;

  const SettingsScreen({
    super.key,
    required this.coupleId,
    this.onProfileUpdated,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _service = SettingsService();
  final _notifService = NotificationService();

  Map<String, dynamic>? _couple;
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  String? _error;

  bool _notifEnabled = false;
  TimeOfDay _notifTime = const TimeOfDay(hour: 21, minute: 0);

  @override
  void initState() {
    super.initState();
    _load();
    _loadNotifSettings();
  }

  Future<void> _loadNotifSettings() async {
    final enabled = await _notifService.isEnabled();
    final time = await _notifService.getSavedTime();
    if (mounted) {
      setState(() {
        _notifEnabled = enabled;
        _notifTime = time;
      });
    }
  }

  Future<void> _onNotifToggle(bool value) async {
    if (value) {
      await _notifService.enableReminder(_notifTime);
    } else {
      await _notifService.disableReminder();
    }
    if (mounted) setState(() => _notifEnabled = value);
  }

  Future<void> _onPickNotifTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _notifTime,
      helpText: 'Chọn giờ nhắc nhở',
    );
    if (picked == null) return;
    setState(() => _notifTime = picked);
    if (_notifEnabled) {
      await _notifService.enableReminder(picked);
    } else {
      await _notifService.saveTime(picked);
    }
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
        _service.getCoupleSettings(widget.coupleId),
        _service.getUserProfile(),
      ]);

      if (mounted) {
        setState(() {
          _couple = results[0] as Map<String, dynamic>;
          _profile = results[1] as Map<String, dynamic>;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (showLoader && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _editNickname() async {
    final ctrl = TextEditingController(
      text: (_profile?['display_name'] as String?) ?? '',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đặt biệt danh'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Biệt danh hiển thị',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).maybePop(false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).maybePop(true),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (saved != true) return;

    final nextName = ctrl.text.trim();
    if (nextName.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biệt danh không được để trống.')),
      );
      return;
    }

    try {
      final profile = await _service.updateUserProfile(displayName: nextName);
      if (!mounted) return;
      setState(() => _profile = profile);
      widget.onProfileUpdated?.call();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã cập nhật biệt danh.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không cập nhật được: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt'),
        actions: [
          IconButton(
            onPressed: () => _load(showLoader: false),
            icon: const Icon(Icons.refresh),
          ),
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
                    onPressed: () => _load(showLoader: true),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_profile != null && _profile!.isNotEmpty) ...[
                    const Text(
                      'Tài khoản',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(
                          _profile!['display_name'] as String? ??
                              _profile!['email'] as String? ??
                              'N/A',
                        ),
                        subtitle: Text(_profile!['email'] as String? ?? ''),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Sửa biệt danh',
                          onPressed: _editNickname,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_couple != null) ...[
                    const Text(
                      'Gia đình',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            title: const Text('Tên gia đình'),
                            subtitle: Text(
                              _couple!['name'] as String? ?? 'N/A',
                            ),
                            leading: const Icon(Icons.home),
                          ),
                          if ((_couple!['invite_code'] as String?) != null) ...[
                            const Divider(height: 0),
                            ListTile(
                              title: const Text('Mã mời couple'),
                              subtitle: Text(
                                _couple!['invite_code'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              leading: const Icon(Icons.vpn_key_outlined),
                              trailing: IconButton(
                                tooltip: 'Sao chép mã',
                                icon: const Icon(Icons.copy),
                                onPressed: () async {
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  final code =
                                      _couple!['invite_code'] as String;
                                  await Clipboard.setData(
                                    ClipboardData(text: code),
                                  );
                                  if (!mounted) {
                                    return;
                                  }
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Đã sao chép mã mời.'),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text(
                    'Danh mục',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.shopping_bag_outlined),
                          title: const Text('Quản lý danh mục Chi'),
                          subtitle: const Text(
                            'Tạo/Sửa/Xoá danh mục Chi, chọn icon và màu.',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ExpenseCategoryManagementScreen(
                                  coupleId: widget.coupleId,
                                ),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 0),
                        ListTile(
                          leading: const Icon(Icons.attach_money),
                          title: const Text('Quản lý danh mục Thu'),
                          subtitle: const Text(
                            'Tạo/Sửa/Xoá danh mục Thu và chọn icon.',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => IncomeSourceManagementScreen(
                                  coupleId: widget.coupleId,
                                ),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 0),
                        ListTile(
                          leading: const Icon(Icons.credit_card_outlined),
                          title: const Text('Quản lý danh mục Nợ'),
                          subtitle: const Text(
                            'Tạo/Sửa/Xoá danh mục Nợ dùng khi lập khoản nợ.',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DebtTypeManagementScreen(
                                  coupleId: widget.coupleId,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Thông báo',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          secondary: const Icon(Icons.notifications_outlined),
                          title: const Text('Nhắc ghi chi tiêu'),
                          subtitle: const Text(
                            'Nhắc nhở hằng ngày để ghi lại thu chi.',
                          ),
                          value: _notifEnabled,
                          onChanged: _onNotifToggle,
                        ),
                        const Divider(height: 0),
                        ListTile(
                          leading: const Icon(Icons.access_time_outlined),
                          title: const Text('Giờ nhắc nhở'),
                          subtitle: Text(_notifTime.format(context)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _onPickNotifTime,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () async {
                      await Supabase.instance.client.auth.signOut();
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Đăng xuất'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
