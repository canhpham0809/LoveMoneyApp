import 'package:flutter/material.dart';

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

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      final wallet = await _service.createWallet(
        coupleId: widget.coupleId,
        name: _nameCtrl.text.trim(),
        type: _type,
        currency: _currency,
        isDefault: _isDefault,
      );
      if (mounted) {
        Navigator.pop(context, wallet.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Khï¿½ng t?o du?c vï¿½: $e')));
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
      appBar: AppBar(title: const Text('Thï¿½m vï¿½')),
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
                  labelText: 'Tï¿½n vï¿½',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Nhap ten vi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Lo?i vï¿½',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Ti?n m?t')),
                  DropdownMenuItem(value: 'bank', child: Text('Ngï¿½n hï¿½ng')),
                  DropdownMenuItem(value: 'ewallet', child: Text('E-wallet')),
                  DropdownMenuItem(value: 'other', child: Text('Khï¿½c')),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'cash'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _currency,
                decoration: const InputDecoration(
                  labelText: 'Ti?n t?',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'VND', child: Text('VND')),
                  DropdownMenuItem(value: 'USD', child: Text('USD')),
                ],
                onChanged: (v) => setState(() => _currency = v ?? 'VND'),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v ?? false),
                title: const Text('ï¿½?t lï¿½m vï¿½ m?c d?nh'),
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
                    : const Text('Lưu vi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

