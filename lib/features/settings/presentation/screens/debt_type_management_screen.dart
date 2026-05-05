import 'package:flutter/material.dart';

import 'package:flutter_app_demo/features/debt/data/services/debt_service.dart';

class DebtTypeManagementScreen extends StatefulWidget {
  final String coupleId;

  const DebtTypeManagementScreen({super.key, required this.coupleId});

  @override
  State<DebtTypeManagementScreen> createState() =>
      _DebtTypeManagementScreenState();
}

class _DebtTypeManagementScreenState extends State<DebtTypeManagementScreen> {
  final _service = DebtService();
  List<Map<String, dynamic>> _items = [];
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
      final items = await _service.getDebtTypes(widget.coupleId);
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

    final reordered = List<Map<String, dynamic>>.from(_items);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    setState(() => _items = reordered);

    try {
      await _service.updateDebtTypeOrder(
        reordered.map((e) => e['id'] as String).toList(),
      );
    } catch (e) {
      if (!mounted) return;
      await _load(showLoader: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không cập nhật được thứ tự danh mục Nợ: $e')),
      );
    }
  }

  Future<void> _openDebtTypeDialog({Map<String, dynamic>? existing}) async {
    final nameCtrl = TextEditingController(
      text: (existing?['name'] as String?) ?? '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(existing == null ? 'Thêm danh mục Nợ' : 'Sửa danh mục Nợ'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Tên danh mục Nợ',
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

    if (confirmed != true) return;

    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tên danh mục Nợ không được để trống.')),
      );
      return;
    }

    try {
      if (existing == null) {
        await _service.createDebtType(coupleId: widget.coupleId, name: name);
      } else {
        await _service.updateDebtType(
          debtTypeId: existing['id'] as String,
          name: name,
        );
      }
      await _load(showLoader: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không lưu được danh mục Nợ: $e')));
    }
  }

  Future<void> _deleteDebtType(Map<String, dynamic> item) async {
    final name = (item['name'] as String?) ?? 'N/A';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xoá danh mục Nợ'),
        content: Text('Xác nhận xoá danh mục $name?'),
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
      await _service.deleteDebtType(item['id'] as String);
      await _load(showLoader: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không xoá được danh mục Nợ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý danh mục Nợ'),
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
          ? const Center(child: Text('Chưa có danh mục Nợ nào.'))
          : ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: _items.length,
              onReorder: _onReorder,
              itemBuilder: (context, index) {
                final item = _items[index];
                final name = (item['name'] as String?) ?? 'N/A';
                return Container(
                  key: ValueKey(item['id']),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0x14000000)),
                    ),
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.credit_card_outlined),
                    ),
                    title: Text(name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _openDebtTypeDialog(existing: item),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () => _deleteDebtType(item),
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
        onPressed: () => _openDebtTypeDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Tạo danh mục Nợ'),
      ),
    );
  }
}
