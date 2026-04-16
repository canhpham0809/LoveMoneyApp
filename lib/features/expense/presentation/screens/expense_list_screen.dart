import 'package:flutter/material.dart';

import 'package:flutter_app_demo/core/utils/formatters.dart';
import 'package:flutter_app_demo/features/expense/data/models/expense_model.dart';
import 'package:flutter_app_demo/features/expense/data/services/expense_service.dart';
import 'package:flutter_app_demo/features/expense/presentation/screens/add_expense_screen.dart';

class ExpenseListScreen extends StatefulWidget {
  final String coupleId;

  const ExpenseListScreen({super.key, required this.coupleId});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  final _service = ExpenseService();
  List<ExpenseModel> _items = [];
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
      final items = await _service.getExpenses(widget.coupleId);
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete(String id) async {
    try {
      await _service.deleteExpense(id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi xóa: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiêu'),
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
          : _items.isEmpty
          ? const Center(child: Text('Chưa có chi tiêu nào.'))
          : ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return Dismissible(
                  key: ValueKey(item.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => _delete(item.id),
                  child: ListTile(
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
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddExpenseScreen(coupleId: widget.coupleId),
            ),
          );
          _load();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
