import 'package:flutter/material.dart';

import 'package:flutter_app_demo/core/utils/formatters.dart';
import 'package:flutter_app_demo/features/fund/data/models/fund_model.dart';
import 'package:flutter_app_demo/features/fund/data/services/fund_service.dart';

class FundListScreen extends StatefulWidget {
  final String coupleId;

  const FundListScreen({super.key, required this.coupleId});

  @override
  State<FundListScreen> createState() => _FundListScreenState();
}

class _FundListScreenState extends State<FundListScreen> {
  final _service = FundService();
  List<FundModel> _items = [];
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
      final items = await _service.getFunds(widget.coupleId);
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
        title: const Text('Quỹ tiết kiệm'),
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
          ? const Center(child: Text('Chưa có quỹ nào.'))
          : ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final progress =
                    (item.targetAmount != null && item.targetAmount! > 0)
                    ? (item.currentAmount / item.targetAmount!).clamp(0.0, 1.0)
                    : 0.0;
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.savings_outlined),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Text(
                              formatVnd(item.currentAmount),
                              style: TextStyle(
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (item.targetAmount != null) ...[
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.grey[200],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${(progress * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                'Mục tiêu: ${formatVnd(item.targetAmount!)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                        if (item.deadline != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              'Hạn: ${formatDate(item.deadline!)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // TODO: AddFundScreen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tính năng thêm quỹ sẽ sớm ra mắt.')),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
