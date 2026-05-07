import 'package:flutter/material.dart';

import 'package:flutter_app_demo/core/utils/category_visuals.dart';
import 'package:flutter_app_demo/features/income/data/models/income_source_model.dart';
import 'package:flutter_app_demo/features/income/data/services/income_service.dart';

class IncomeSourceManagementScreen extends StatefulWidget {
  final String coupleId;

  const IncomeSourceManagementScreen({super.key, required this.coupleId});

  @override
  State<IncomeSourceManagementScreen> createState() =>
      _IncomeSourceManagementScreenState();
}

class _IncomeSourceManagementScreenState
    extends State<IncomeSourceManagementScreen> {
  final _service = IncomeService();
  List<IncomeSourceModel> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
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
      final items = await _service.getIncomeSources(widget.coupleId);
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (showLoader && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;

    final reordered = List<IncomeSourceModel>.from(_items);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    setState(() => _items = reordered);

    try {
      await _service.updateIncomeSourceOrder(
        reordered.map((e) => e.id).toList(),
      );
    } catch (e) {
      if (!mounted) return;
      await _load(showLoader: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không cập nhật được thứ tự danh mục Thu: $e')),
      );
    }
  }

  Future<void> _openIncomeSourceDialog({IncomeSourceModel? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final typeCtrl = TextEditingController(text: existing?.type ?? 'other');
    var selectedIcon = existing?.icon ?? 'payments';
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Chọn icon',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kIncomeIconChoices
                      .map(
                        (choice) => ChoiceChip(
                          label: Icon(
                            choice.icon,
                            size: 22,
                            color: selectedIcon == choice.key
                                ? null
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          ),
                          selected: selectedIcon == choice.key,
                          padding: const EdgeInsets.all(6),
                          onSelected: (_) {
                            setDialogState(() => selectedIcon = choice.key);
                          },
                        ),
                      )
                      .toList(),
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
        await _service.createIncomeSource(
          coupleId: widget.coupleId,
          name: name,
          icon: selectedIcon,
          type: typeCtrl.text.trim().isEmpty ? 'other' : typeCtrl.text.trim(),
          showInIncomeForm: showInIncomeForm,
        );
      } else {
        await _service.updateIncomeSource(
          sourceId: existing.id,
          name: name,
          icon: selectedIcon,
          type: typeCtrl.text.trim().isEmpty ? 'other' : typeCtrl.text.trim(),
          isActive: isActive,
          showInIncomeForm: showInIncomeForm,
        );
      }
      await _load(showLoader: false);
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
      await _service.deleteIncomeSource(item.id);
      await _load(showLoader: false);
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
        title: const Text('Quản lý danh mục Thu'),
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
          : _items.isEmpty
          ? const Center(child: Text('Chưa có danh mục Thu nào.'))
          : ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: _items.length,
              onReorder: _onReorder,
              itemBuilder: (context, index) {
                final item = _items[index];
                return Container(
                  key: ValueKey(item.id),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0x14000000)),
                    ),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(child: Icon(iconFromKey(item.icon))),
                    title: Text(item.name),
                    subtitle: Text(
                      'Hiện tạo Thu: ${item.showInIncomeForm ? 'On' : 'Off'} · Active: ${item.isActive ? 'On' : 'Off'} · Type: ${item.type}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () =>
                              _openIncomeSourceDialog(existing: item),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () => _deleteIncomeSource(item),
                        ),
                        ReorderableDragStartListener(
                          index: index,
                          child: const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.drag_indicator),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openIncomeSourceDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
