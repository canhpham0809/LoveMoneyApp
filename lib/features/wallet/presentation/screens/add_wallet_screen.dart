import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import 'package:flutter_app_demo/core/utils/amount_input.dart';
import 'package:flutter_app_demo/features/wallet/data/services/wallet_service.dart';

class AddWalletScreen extends StatefulWidget {
  final String coupleId;

  const AddWalletScreen({super.key, required this.coupleId});

  @override
  State<AddWalletScreen> createState() => _AddWalletScreenState();
}

class _AddWalletScreenState extends State<AddWalletScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = WalletService();
  final _nameCtrl = TextEditingController();

  String _type = 'cash';
  String _currency = 'VND';
  bool _isDefault = false;
  bool _isSaving = false;

  // Gold-specific fields
  final _goldQuantityCtrl = TextEditingController(text: '1.0');
  final _goldUnitPriceCtrl = TextEditingController();
  final _goldStoreCtrl = TextEditingController();
  String _goldType = 'SJ9999';
  DateTime _buyDate = DateTime.now();

  final List<Map<String, String>> _goldTypesList = [
    {'code': 'SJ9999', 'name': 'SJC Nhẫn Trơn (24K)'},
    {'code': 'SJL1L10', 'name': 'SJC Vàng Miếng 9999'},
    {'code': 'PQHN24NTT', 'name': 'PNJ Nhẫn Trơn 24K'},
    {'code': 'DOHNL', 'name': 'DOJI Nhẫn Trơn'},
    {'code': 'manual', 'name': 'Tự nhập giá thủ công'},
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _goldQuantityCtrl.dispose();
    _goldUnitPriceCtrl.dispose();
    _goldStoreCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      Map<String, dynamic>? goldMetadata;
      if (_type == 'gold') {
        final qty = double.tryParse(_goldQuantityCtrl.text.trim()) ?? 1.0;
        final unitPrice = parseAmountInput(_goldUnitPriceCtrl.text.trim()) ?? 0.0;
        final totalPrice = qty * unitPrice;

        final firstRound = {
          'id': const Uuid().v4(),
          'quantity': qty,
          'unit_price': unitPrice,
          'total_price': totalPrice,
          'store': _goldStoreCtrl.text.trim(),
          'date': _buyDate.toIso8601String(),
        };

        goldMetadata = {
          'gold_type': _goldType,
          'total_quantity': qty,
          'purchase_cost': totalPrice,
          'last_known_price': unitPrice,
          'last_updated_price': DateTime.now().toUtc().toIso8601String(),
          'rounds': [firstRound],
        };
      }

      final wallet = await _service.createWallet(
        coupleId: widget.coupleId,
        name: _nameCtrl.text.trim(),
        type: _type,
        currency: _type == 'gold' ? 'VND' : _currency,
        isDefault: _isDefault,
        goldMetadata: goldMetadata,
      );
      if (mounted) {
        Navigator.pop(context, wallet.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không tạo được ví: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thêm ví')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tên ví',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Nhập tên ví';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: 'Loại ví',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Tiền mặt')),
                  DropdownMenuItem(value: 'bank', child: Text('Ngân hàng')),
                  DropdownMenuItem(value: 'ewallet', child: Text('E-wallet')),
                  DropdownMenuItem(value: 'gold', child: Text('Vàng (Gold)')),
                  DropdownMenuItem(value: 'other', child: Text('Khác')),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'cash'),
              ),
              if (_type == 'gold') ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _goldType,
                  decoration: const InputDecoration(
                    labelText: 'Loại Vàng',
                    border: OutlineInputBorder(),
                  ),
                  items: _goldTypesList.map((t) {
                    return DropdownMenuItem(value: t['code'], child: Text(t['name']!));
                  }).toList(),
                  onChanged: (v) => setState(() => _goldType = v ?? 'SJ9999'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _goldQuantityCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Số lượng chỉ vàng (ví dụ: 1.0, 0.5, 2.5)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Nhập số lượng chỉ vàng';
                    if (double.tryParse(v) == null) return 'Số lượng phải là một số';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _goldUnitPriceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [ThousandsSeparatorInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Đơn giá lúc mua (VND cho 1 chỉ)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Nhập đơn giá 1 chỉ';
                    if (parseAmountInput(v) == null) return 'Đơn giá phải là số hợp lệ';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _goldStoreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Cửa hàng mua',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Nhập tên cửa hàng mua';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Ngày mua'),
                  subtitle: Text('${_buyDate.day}/${_buyDate.month}/${_buyDate.year}'),
                  trailing: const Icon(Icons.calendar_today),
                  contentPadding: EdgeInsets.zero,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _buyDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => _buyDate = picked);
                    }
                  },
                ),
              ],
              if (_type != 'gold') ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _currency,
                  decoration: const InputDecoration(
                    labelText: 'Tiền tệ',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'VND', child: Text('VND')),
                    DropdownMenuItem(value: 'USD', child: Text('USD')),
                  ],
                  onChanged: (v) => setState(() => _currency = v ?? 'VND'),
                ),
              ],
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v ?? false),
                title: const Text('Đặt làm ví mặc định'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _isSaving ? null : _submit,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Lưu ví'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
