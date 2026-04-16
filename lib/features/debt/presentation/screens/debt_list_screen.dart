import 'package:flutter/material.dart';

import 'package:flutter_app_demo/core/utils/formatters.dart';
import 'package:flutter_app_demo/features/debt/data/models/debt_model.dart';
import 'package:flutter_app_demo/features/debt/data/services/debt_service.dart';

class DebtListScreen extends StatefulWidget {
  final String coupleId;

  const DebtListScreen({super.key, required this.coupleId});

  @override
  State<DebtListScreen> createState() => _DebtListScreenState();
}

class _DebtListScreenState extends State<DebtListScreen> {
  final _service = DebtService();
  List<DebtModel> _items = [];
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
      final items = await _service.getDebts(widget.coupleId);
      if (mounted) setState(() => _items = items);
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
        title: const Text('Khoản nợ'),
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
          ? const Center(child: Text('Chưa có khoản nợ nào.'))
          : ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final pct = item.originalAmount > 0
                    ? 1 - (item.remainingAmount / item.originalAmount)
                    : 1.0;
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: item.isClosed
                          ? Colors.green
                          : Colors.orange,
                      child: Icon(
                        item.isClosed ? Icons.check : Icons.credit_card,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(item.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.creditorName),
                        LinearProgressIndicator(
                          value: pct.clamp(0.0, 1.0),
                          backgroundColor: Colors.grey[200],
                          color: item.isClosed ? Colors.green : Colors.orange,
                        ),
                        Text(
                          'Còn lại: ${formatVnd(item.remainingAmount)}'
                          '${item.dueDate != null ? ' · Hạn: ${formatDate(item.dueDate!)}' : ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    trailing: Text(
                      formatVnd(item.originalAmount),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // TODO: AddDebtScreen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tính năng thêm nợ sẽ sớm ra mắt.')),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
