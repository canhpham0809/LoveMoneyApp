import 'package:flutter/material.dart';

import 'package:flutter_app_demo/core/utils/formatters.dart';
import 'package:flutter_app_demo/features/expense/data/models/expense_model.dart';
import 'package:flutter_app_demo/features/expense/data/services/expense_service.dart';

class ExpenseSearchFilterScreen extends StatefulWidget {
  final String coupleId;

  const ExpenseSearchFilterScreen({super.key, required this.coupleId});

  @override
  State<ExpenseSearchFilterScreen> createState() =>
      _ExpenseSearchFilterScreenState();
}

class _ExpenseSearchFilterScreenState extends State<ExpenseSearchFilterScreen> {
  final _service = ExpenseService();
  final _searchCtrl = TextEditingController();

  List<ExpenseModel> _all = [];
  List<ExpenseModel> _filtered = [];
  DateTime? _month;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl
      ..removeListener(_applyFilter)
      ..dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final items = await _service.getExpenses(widget.coupleId);
      if (!mounted) return;
      setState(() => _all = items);
      _applyFilter();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered = _all.where((item) {
      final text = '${item.description ?? ''} ${item.categoryName ?? ''}'
          .toLowerCase();
      final matchQuery = q.isEmpty || text.contains(q);
      final matchMonth =
          _month == null ||
          (item.date.year == _month!.year && item.date.month == _month!.month);
      return matchQuery && matchMonth;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (mounted) {
      setState(() => _filtered = filtered);
    }
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _month ?? now,
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: DateTime(now.year + 2, 12, 31),
      helpText: 'Chon thang loc',
    );
    if (picked != null) {
      setState(() => _month = DateTime(picked.year, picked.month));
      _applyFilter();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tìm kiếm & Lọc chi tiêu')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Tìm theo mô tả, danh mục',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickMonth,
                      icon: const Icon(Icons.calendar_month),
                      label: Text(
                        _month == null
                            ? 'Lọc theo tháng'
                            : 'Tháng ${_month!.month.toString().padLeft(2, '0')}/${_month!.year}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_month != null)
                      TextButton(
                        onPressed: () {
                          setState(() => _month = null);
                          _applyFilter();
                        },
                        child: const Text('Bỏ lọc'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? const Center(child: Text('Không tìm thấy giao dịch phù hợp.'))
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final item = _filtered[index];
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.shopping_bag_outlined),
                        ),
                        title: Text(item.categoryName ?? 'Chi tiêu'),
                        subtitle: Text(
                          '${item.description ?? ''} · ${formatDate(item.date)}',
                        ),
                        trailing: Text(
                          formatVnd(item.amount),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
