import 'package:flutter/material.dart';

import 'package:flutter_app_demo/core/utils/formatters.dart';
import 'package:flutter_app_demo/features/dashboard/data/services/dashboard_service.dart';

class AnalyticsScreen extends StatefulWidget {
  final String coupleId;

  const AnalyticsScreen({super.key, required this.coupleId});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _service = DashboardService();
  List<Map<String, dynamic>> _breakdown = [];
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
      final breakdown = await _service.getCategoryBreakdown(widget.coupleId);
      if (mounted) setState(() => _breakdown = breakdown);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _breakdown.fold<double>(
      0,
      (s, b) => s + ((b['amount'] as num?)?.toDouble() ?? 0),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
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
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chi tiêu theo danh mục (tháng này)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_breakdown.isEmpty)
                      const Center(child: Text('Chưa có dữ liệu.'))
                    else
                      ...(_breakdown.map((b) {
                        final amount = (b['amount'] as num?)?.toDouble() ?? 0;
                        final pct = total > 0 ? amount / total : 0.0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(b['category'] as String? ?? 'Khác'),
                                  Text(
                                    '${formatVnd(amount)} (${(pct * 100).toStringAsFixed(0)}%)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: pct,
                                backgroundColor: Colors.grey[200],
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          ),
                        );
                      })),
                    if (_breakdown.isNotEmpty) ...[
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Tổng',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            formatVnd(total),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
