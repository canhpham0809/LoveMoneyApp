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
        ).showSnackBar(SnackBar(content: Text('Khong tao duoc vi: $e')));
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
      appBar: AppBar(title: const Text('Them vi')),
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
                  labelText: 'Ten vi',
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
                  labelText: 'Loai vi',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Tien mat')),
                  DropdownMenuItem(value: 'bank', child: Text('Ngan hang')),
                  DropdownMenuItem(value: 'ewallet', child: Text('E-wallet')),
                  DropdownMenuItem(value: 'other', child: Text('Khac')),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'cash'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _currency,
                decoration: const InputDecoration(
                  labelText: 'Tien te',
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
                title: const Text('Dat lam vi mac dinh'),
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
                    : const Text('Luu vi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
