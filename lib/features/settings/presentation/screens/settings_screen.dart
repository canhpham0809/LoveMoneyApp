import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_app_demo/features/expense/data/models/category_model.dart';
import 'package:flutter_app_demo/features/expense/data/services/expense_service.dart';
import 'package:flutter_app_demo/features/income/data/models/income_source_model.dart';
import 'package:flutter_app_demo/features/income/data/services/income_service.dart';
import 'package:flutter_app_demo/features/settings/data/services/settings_service.dart';

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
  final _expenseService = ExpenseService();
  final _incomeService = IncomeService();

  Map<String, dynamic>? _couple;
  Map<String, dynamic>? _profile;
  List<CategoryModel> _categories = [];
  List<IncomeSourceModel> _incomeSources = [];
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
      final results = await Future.wait<dynamic>([
        _service.getCoupleSettings(widget.coupleId),
        _service.getUserProfile(),
        _expenseService.getCategories(widget.coupleId),
        _incomeService.getIncomeSources(widget.coupleId),
      ]);

      if (mounted) {
        setState(() {
          _couple = results[0] as Map<String, dynamic>;
          _profile = results[1] as Map<String, dynamic>;
          _categories = List<CategoryModel>.from(results[2] as List);
          _incomeSources = List<IncomeSourceModel>.from(results[3] as List);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  Future<void> _openCategoryDialog({CategoryModel? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final iconCtrl = TextEditingController(text: existing?.icon ?? 'label');
    final colorCtrl = TextEditingController(text: existing?.color ?? '#6366F1');
    var isActive = existing?.isActive ?? true;
    var showInQuickAdd = existing?.showInQuickAdd ?? true;
    var showInExpenseForm = existing?.showInExpenseForm ?? true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(
            existing == null ? 'Thêm danh mục Chi' : 'Sửa danh mục Chi',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tên danh mục',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: iconCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Icon',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: colorCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Màu (hex)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: showInExpenseForm,
                  onChanged: (v) => setDialogState(() => showInExpenseForm = v),
                  title: const Text('Hiện khi tạo Chi tiêu'),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  value: showInQuickAdd,
                  onChanged: (v) => setDialogState(() => showInQuickAdd = v),
                  title: const Text('Hiện trong Quick Add'),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  value: isActive,
                  onChanged: (v) => setDialogState(() => isActive = v),
                  title: const Text('Kích hoạt'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
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
      ),
    );

    if (confirmed != true) return;

    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tên danh mục không được để trống.')),
      );
      return;
    }

    try {
      if (existing == null) {
        await _expenseService.createCategory(
          coupleId: widget.coupleId,
          name: name,
          icon: iconCtrl.text.trim().isEmpty ? 'label' : iconCtrl.text.trim(),
          color: colorCtrl.text.trim().isEmpty
              ? '#6366F1'
              : colorCtrl.text.trim(),
          showInQuickAdd: showInQuickAdd,
          showInExpenseForm: showInExpenseForm,
        );
      } else {
        await _expenseService.updateCategory(
          categoryId: existing.id,
          name: name,
          icon: iconCtrl.text.trim().isEmpty ? 'label' : iconCtrl.text.trim(),
          color: colorCtrl.text.trim().isEmpty
              ? '#6366F1'
              : colorCtrl.text.trim(),
          isActive: isActive,
          showInQuickAdd: showInQuickAdd,
          showInExpenseForm: showInExpenseForm,
        );
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không lưu được danh mục: $e')));
    }
  }

  Future<void> _deleteCategory(CategoryModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xoá danh mục Chi'),
        content: Text('Xác nhận xoá danh mục ${item.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).maybePop(false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).maybePop(true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _expenseService.deleteCategory(item.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không xoá được danh mục: $e')));
    }
  }

  Future<void> _openIncomeSourceDialog({IncomeSourceModel? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final iconCtrl = TextEditingController(text: existing?.icon ?? 'payments');
    final typeCtrl = TextEditingController(text: existing?.type ?? 'other');
    var isActive = existing?.isActive ?? true;
    var showInIncomeForm = existing?.showInIncomeForm ?? true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(
            existing == null ? 'Thêm danh mục Thu' : 'Sửa danh mục Thu',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tên danh mục',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: iconCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Icon',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: typeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Loại',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: showInIncomeForm,
                  onChanged: (v) => setDialogState(() => showInIncomeForm = v),
                  title: const Text('Hiện khi tạo Thu nhập'),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  value: isActive,
                  onChanged: (v) => setDialogState(() => isActive = v),
                  title: const Text('Kích hoạt'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
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
      ),
    );

    if (confirmed != true) return;

    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tên danh mục không được để trống.')),
      );
      return;
    }

    try {
      if (existing == null) {
        await _incomeService.createIncomeSource(
          coupleId: widget.coupleId,
          name: name,
          icon: iconCtrl.text.trim().isEmpty
              ? 'payments'
              : iconCtrl.text.trim(),
          type: typeCtrl.text.trim().isEmpty ? 'other' : typeCtrl.text.trim(),
          showInIncomeForm: showInIncomeForm,
        );
      } else {
        await _incomeService.updateIncomeSource(
          sourceId: existing.id,
          name: name,
          icon: iconCtrl.text.trim().isEmpty
              ? 'payments'
              : iconCtrl.text.trim(),
          type: typeCtrl.text.trim().isEmpty ? 'other' : typeCtrl.text.trim(),
          isActive: isActive,
          showInIncomeForm: showInIncomeForm,
        );
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không lưu được danh mục Thu: $e')),
      );
    }
  }

  Future<void> _deleteIncomeSource(IncomeSourceModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xoá danh mục Thu'),
        content: Text('Xác nhận xoá danh mục ${item.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).maybePop(false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).maybePop(true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _incomeService.deleteIncomeSource(item.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không xoá được danh mục Thu: $e')),
      );
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
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Danh mục Chi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _openCategoryDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Thêm'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: _categories
                          .map(
                            (c) => ListTile(
                              leading: const Icon(Icons.category_outlined),
                              title: Text(c.name),
                              subtitle: Text(
                                'Quick Add: ${c.showInQuickAdd ? 'On' : 'Off'} · Tạo Chi: ${c.showInExpenseForm ? 'On' : 'Off'} · Active: ${c.isActive ? 'On' : 'Off'}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () =>
                                        _openCategoryDialog(existing: c),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _deleteCategory(c),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Danh mục Thu',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _openIncomeSourceDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Thêm'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: _incomeSources
                          .map(
                            (s) => ListTile(
                              leading: const Icon(Icons.attach_money),
                              title: Text(s.name),
                              subtitle: Text(
                                'Hiện tạo Thu: ${s.showInIncomeForm ? 'On' : 'Off'} · Active: ${s.isActive ? 'On' : 'Off'} · Type: ${s.type}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () =>
                                        _openIncomeSourceDialog(existing: s),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _deleteIncomeSource(s),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
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
