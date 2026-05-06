import 'package:flutter/material.dart';

import 'package:flutter_app_demo/core/utils/category_visuals.dart';
import 'package:flutter_app_demo/features/expense/data/models/category_model.dart';
import 'package:flutter_app_demo/features/expense/data/services/expense_service.dart';

class ExpenseCategoryManagementScreen extends StatefulWidget {
  final String coupleId;

  const ExpenseCategoryManagementScreen({super.key, required this.coupleId});

  @override
  State<ExpenseCategoryManagementScreen> createState() =>
      _ExpenseCategoryManagementScreenState();
}

class _ExpenseCategoryManagementScreenState
    extends State<ExpenseCategoryManagementScreen> {
  final _service = ExpenseService();
  List<CategoryModel> _categories = [];
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
      final categories = await _service.getCategories(widget.coupleId);
      if (!mounted) return;
      setState(() => _categories = categories);
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

    final reordered = List<CategoryModel>.from(_categories);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    setState(() => _categories = reordered);

    try {
      await _service.updateCategoryOrder(reordered.map((e) => e.id).toList());
    } catch (e) {
      if (!mounted) return;
      await _load(showLoader: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không cập nhật được thứ tự danh mục: $e')),
      );
    }
  }

  Future<void> _openCategoryDialog({CategoryModel? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    var selectedIcon = existing?.icon ?? 'label';
    var selectedColor = colorFromHex(existing?.color ?? '#6366F1');
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
                  children: kCategoryIconChoices
                      .map(
                        (choice) => ChoiceChip(
                          avatar: Icon(choice.icon, size: 18),
                          label: Text(choice.key),
                          selected: selectedIcon == choice.key,
                          onSelected: (_) {
                            setDialogState(() => selectedIcon = choice.key);
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Chọn màu',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: kCategoryColorChoices
                      .map(
                        (color) => InkWell(
                          onTap: () {
                            setDialogState(() => selectedColor = color);
                          },
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selectedColor.toARGB32() == color.toARGB32()
                                    ? Colors.black
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: selectedColor.toARGB32() == color.toARGB32()
                                ? const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: selectedColor.withValues(alpha: 0.16),
                      child: Icon(
                        iconFromKey(selectedIcon),
                        color: selectedColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Màu đã chọn: ${colorToHex(selectedColor)}'),
                    ),
                  ],
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
        await _service.createCategory(
          coupleId: widget.coupleId,
          name: name,
          icon: selectedIcon,
          color: colorToHex(selectedColor),
          showInQuickAdd: showInQuickAdd,
          showInExpenseForm: showInExpenseForm,
        );
      } else {
        await _service.updateCategory(
          categoryId: existing.id,
          name: name,
          icon: selectedIcon,
          color: colorToHex(selectedColor),
          isActive: isActive,
          showInQuickAdd: showInQuickAdd,
          showInExpenseForm: showInExpenseForm,
        );
      }
      await _load(showLoader: false);
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
      await _service.deleteCategory(item.id);
      await _load(showLoader: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không xoá được danh mục: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý danh mục Chi'),
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
          : _categories.isEmpty
          ? const Center(child: Text('Chưa có danh mục Chi nào.'))
          : ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: _categories.length,
              onReorder: _onReorder,
              itemBuilder: (context, index) {
                final item = _categories[index];
                final color = colorFromHex(item.color);
                return Container(
                  key: ValueKey(item.id),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0x14000000)),
                    ),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.16),
                      child: Icon(iconFromKey(item.icon), color: color),
                    ),
                    title: Text(item.name),
                    subtitle: Text(
                      'Màu: ${item.color.toUpperCase()} · Quick Add: ${item.showInQuickAdd ? 'On' : 'Off'} · Tạo Chi: ${item.showInExpenseForm ? 'On' : 'Off'} · Active: ${item.isActive ? 'On' : 'Off'}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _openCategoryDialog(existing: item),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () => _deleteCategory(item),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCategoryDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Tạo danh mục Chi'),
      ),
    );
  }
}
