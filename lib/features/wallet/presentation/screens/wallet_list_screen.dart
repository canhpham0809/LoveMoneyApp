import 'package:flutter/material.dart';

import 'package:flutter_app_demo/features/wallet/data/models/wallet_model.dart';
import 'package:flutter_app_demo/features/wallet/data/services/wallet_service.dart';

class WalletListScreen extends StatefulWidget {
  final String coupleId;

  const WalletListScreen({super.key, required this.coupleId});

  @override
  State<WalletListScreen> createState() => _WalletListScreenState();
}

class _WalletListScreenState extends State<WalletListScreen> {
  final _service = WalletService();
  List<WalletModel> _items = [];
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
      final items = await _service.getWallets(widget.coupleId);
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _walletIcon(String type) {
    switch (type) {
      case 'bank':
        return Icons.account_balance;
      case 'ewallet':
        return Icons.phone_android;
      case 'cash':
        return Icons.payments_outlined;
      default:
        return Icons.wallet;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ví tiền'),
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
          ? const Center(child: Text('Chưa có ví nào.'))
          : ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return ListTile(
                  leading: CircleAvatar(child: Icon(_walletIcon(item.type))),
                  title: Row(
                    children: [
                      Text(item.name),
                      if (item.isDefault) ...const [
                        SizedBox(width: 6),
                        Chip(
                          label: Text('Mặc định'),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    '${item.type.toUpperCase()} · ${item.currency}',
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // TODO: create AddWalletScreen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tính năng thêm ví sẽ sớm ra mắt.')),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
