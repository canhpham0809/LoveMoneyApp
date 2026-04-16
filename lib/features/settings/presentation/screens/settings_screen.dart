import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_app_demo/features/settings/data/services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  final String coupleId;

  const SettingsScreen({super.key, required this.coupleId});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _service = SettingsService();
  Map<String, dynamic>? _couple;
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final couple = await _service.getCoupleSettings(widget.coupleId);
      final profile = await _service.getUserProfile();
      if (mounted) {
        setState(() {
          _couple = couple;
          _profile = profile;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt'),
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile
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
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Couple settings
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
                          const Divider(height: 0),
                          ListTile(
                            title: const Text('Đơn vị tiền tệ'),
                            subtitle: Text(
                              _couple!['currency'] as String? ?? 'VND',
                            ),
                            leading: const Icon(Icons.currency_exchange),
                          ),
                          const Divider(height: 0),
                          ListTile(
                            title: const Text('Ngôn ngữ'),
                            subtitle: Text(
                              _couple!['language'] as String? ?? 'vi',
                            ),
                            leading: const Icon(Icons.language),
                          ),
                          if (_couple!['monthly_budget_amount'] != null) ...[
                            const Divider(height: 0),
                            ListTile(
                              title: const Text('Ngân sách tháng'),
                              subtitle: Text(
                                _couple!['monthly_budget_amount'].toString(),
                              ),
                              leading: const Icon(Icons.account_balance_wallet),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Sign out
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
