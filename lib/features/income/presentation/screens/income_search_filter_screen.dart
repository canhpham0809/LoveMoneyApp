import 'package:flutter/material.dart';

import 'package:flutter_app_demo/core/utils/formatters.dart';
import 'package:flutter_app_demo/features/income/data/models/income_model.dart';
import 'package:flutter_app_demo/features/income/data/services/income_service.dart';

class IncomeSearchFilterScreen extends StatefulWidget {
  final String coupleId;

  const IncomeSearchFilterScreen({super.key, required this.coupleId});

  @override
  State<IncomeSearchFilterScreen> createState() =>
      _IncomeSearchFilterScreenState();
}

class _IncomeSearchFilterScreenState extends State<IncomeSearchFilterScreen> {
  final _service = IncomeService();
  final _searchCtrl = TextEditingController();

  List<IncomeModel> _all = [];
  List<IncomeModel> _filtered = [];
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
      final items = await _service.getIncomes(widget.coupleId);
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
      final text = (item.description ?? '').toLowerCase();
      final matchQuery = q.isEmpty || text.contains(q);
      final matchMonth =
          _month == null ||
          (item.date.year == _month!.year && item.date.month == _month!.month);
      return matchQuery && matchMonth;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

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
      appBar: AppBar(title: const Text('Search & Filter thu nhap')),
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
                    hintText: 'Tim theo mo ta thu nhap',
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
                            ? 'Loc theo thang'
                            : 'Thang ${_month!.month.toString().padLeft(2, '0')}/${_month!.year}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_month != null)
                      TextButton(
                        onPressed: () {
                          setState(() => _month = null);
                          _applyFilter();
                        },
                        child: const Text('Bo loc'),
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
                ? const Center(child: Text('Khong tim thay giao dich phu hop.'))
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final item = _filtered[index];
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.attach_money),
                        ),
                        title: Text(item.description ?? 'Thu nhap'),
                        subtitle: Text(formatDate(item.date)),
                        trailing: Text(
                          formatVnd(item.amount),
                          style: TextStyle(
                            color: Colors.green[700],
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
