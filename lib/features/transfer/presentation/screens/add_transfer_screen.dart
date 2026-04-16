import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_app_demo/features/transfer/data/services/transfer_service.dart';
import 'package:flutter_app_demo/features/wallet/data/services/wallet_service.dart';

class AddTransferScreen extends StatefulWidget {
  final String coupleId;

  const AddTransferScreen({super.key, required this.coupleId});

  @override
  State<AddTransferScreen> createState() => _AddTransferScreenState();
}

class _AddTransferScreenState extends State<AddTransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _transferService = TransferService();
  final _walletService = WalletService();

  List<Map<String, dynamic>> _wallets = [];
  String? _fromWalletId;
  String? _toWalletId;
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
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    try {
      final wallets = await _walletService.getWallets(widget.coupleId);
      if (mounted) {
        setState(() {
          _wallets = wallets.map((w) => {'id': w.id, 'name': w.name}).toList();
          if (_wallets.isNotEmpty) {
            _fromWalletId = _wallets[0]['id'];
          }
          if (_wallets.length >= 2) {
            _toWalletId = _wallets[1]['id'];
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
    if (_fromWalletId == null || _toWalletId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng chọn ví.')));
      return;
    }
    if (_fromWalletId == _toWalletId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ví gửi và ví nhận phải khác nhau.')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      await _transferService.createTransfer(
        coupleId: widget.coupleId,
        fromUserId: uid,
        toUserId: uid,
        fromWalletId: _fromWalletId!,
        toWalletId: _toWalletId!,
        amount: double.parse(_amountCtrl.text.replaceAll(',', '')),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
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
      appBar: AppBar(title: const Text('Chuyển tiền')),
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
                      initialValue: _fromWalletId,
                      decoration: const InputDecoration(
                        labelText: 'Ví gửi',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.arrow_upward),
                      ),
                      items: _wallets
                          .map(
                            (w) => DropdownMenuItem(
                              value: w['id'] as String,
                              child: Text(w['name'] as String),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _fromWalletId = v),
                      validator: (v) => v == null ? 'Chọn ví gửi' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _toWalletId,
                      decoration: const InputDecoration(
                        labelText: 'Ví nhận',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.arrow_downward),
                      ),
                      items: _wallets
                          .map(
                            (w) => DropdownMenuItem(
                              value: w['id'] as String,
                              child: Text(w['name'] as String),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _toWalletId = v),
                      validator: (v) => v == null ? 'Chọn ví nhận' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _noteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Ghi chú (tùy chọn)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.notes),
                      ),
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
                          : const Text('Lưu chuyển tiền'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
