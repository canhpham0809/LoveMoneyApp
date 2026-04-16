import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_app_demo/features/income/data/services/income_service.dart';
import 'package:flutter_app_demo/features/wallet/data/services/wallet_service.dart';

class AddIncomeScreen extends StatefulWidget {
  final String coupleId;

  const AddIncomeScreen({super.key, required this.coupleId});

  @override
  State<AddIncomeScreen> createState() => _AddIncomeScreenState();
}

class _AddIncomeScreenState extends State<AddIncomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _incomeService = IncomeService();
  final _walletService = WalletService();

  List<Map<String, dynamic>> _wallets = [];
  List<Map<String, dynamic>> _sources = [];
  String? _selectedWalletId;
  String? _selectedSourceId;
  DateTime _date = DateTime.now();
  bool _isLoading = false;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    try {
      final wallets = await _walletService.getWallets(widget.coupleId);
      final sources = await _incomeService.getIncomeSources(widget.coupleId);
      if (mounted) {
        setState(() {
          _wallets = wallets.map((w) => {'id': w.id, 'name': w.name}).toList();
          _sources = sources.map((s) => {'id': s.id, 'name': s.name}).toList();
          if (_wallets.isNotEmpty) {
            _selectedWalletId = _wallets.first['id'];
          }
          if (_sources.isNotEmpty) {
            _selectedSourceId = _sources.first['id'];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tải dữ liệu: $e')));
      }
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedWalletId == null || _selectedSourceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ví và nguồn thu.')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      await _incomeService.createIncome(
        coupleId: widget.coupleId,
        userId: uid,
        walletId: _selectedWalletId!,
        incomeSourceId: _selectedSourceId!,
        amount: double.parse(_amountCtrl.text.replaceAll(',', '')),
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        date: _date,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thêm thu nhập')),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _amountCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Số tiền',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.money),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Nhập số tiền';
                        final amount = double.tryParse(v.replaceAll(',', ''));
                        if (amount == null || amount <= 0) {
                          return 'Số tiền không hợp lệ';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedSourceId,
                      decoration: const InputDecoration(
                        labelText: 'Nguồn thu',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.source),
                      ),
                      items: _sources
                          .map(
                            (s) => DropdownMenuItem(
                              value: s['id'] as String,
                              child: Text(s['name'] as String),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedSourceId = v),
                      validator: (v) => v == null ? 'Chọn nguồn thu' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedWalletId,
                      decoration: const InputDecoration(
                        labelText: 'Ví tiền',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.wallet),
                      ),
                      items: _wallets
                          .map(
                            (w) => DropdownMenuItem(
                              value: w['id'] as String,
                              child: Text(w['name'] as String),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedWalletId = v),
                      validator: (v) => v == null ? 'Chọn ví' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Ghi chú (tùy chọn)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.notes),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        'Ngày: ${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Lưu thu nhập'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
