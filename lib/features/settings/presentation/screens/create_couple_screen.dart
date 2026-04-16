import 'package:flutter/material.dart';

import 'package:flutter_app_demo/features/expense/data/services/expense_service.dart';
import 'package:flutter_app_demo/features/income/data/services/income_service.dart';
import 'package:flutter_app_demo/features/settings/data/services/settings_service.dart';
import 'package:flutter_app_demo/features/wallet/data/services/wallet_service.dart';

class CreateCoupleScreen extends StatefulWidget {
  const CreateCoupleScreen({super.key});

  @override
  State<CreateCoupleScreen> createState() => _CreateCoupleScreenState();
}

class _CreateCoupleScreenState extends State<CreateCoupleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _settingsService = SettingsService();
  final _walletService = WalletService();
  final _expenseService = ExpenseService();
  final _incomeService = IncomeService();

  String _currency = 'VND';
  String _language = 'vi';
  bool _createStarterData = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      final couple = await _settingsService.createCouple(
        name: _nameCtrl.text.trim(),
        currency: _currency,
        language: _language,
      );
      final coupleId = couple['id'] as String;

      if (_createStarterData) {
        await _seedStarterData(coupleId);
      }

      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không tạo được couple: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _seedStarterData(String coupleId) async {
    await _walletService.createWallet(
      coupleId: coupleId,
      name: 'Ví tiền mặt',
      type: 'cash',
      currency: _currency,
      isDefault: true,
    );

    final categorySeeds = <Map<String, String>>[
      {'name': 'Ăn uống', 'icon': 'restaurant', 'color': '#EF4444'},
      {'name': 'Đi lại', 'icon': 'directions_car', 'color': '#3B82F6'},
      {'name': 'Sinh hoạt', 'icon': 'home', 'color': '#10B981'},
    ];
    for (final item in categorySeeds) {
      await _expenseService.createCategory(
        coupleId: coupleId,
        name: item['name']!,
        icon: item['icon']!,
        color: item['color']!,
      );
    }

    final incomeSeeds = <Map<String, String>>[
      {'name': 'Lương', 'icon': 'payments', 'type': 'salary'},
      {'name': 'Thưởng', 'icon': 'card_giftcard', 'type': 'bonus'},
      {'name': 'Khác', 'icon': 'account_balance_wallet', 'type': 'other'},
    ];
    for (final item in incomeSeeds) {
      await _incomeService.createIncomeSource(
        coupleId: coupleId,
        name: item['name']!,
        icon: item['icon']!,
        type: item['type']!,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo couple mới')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Bắt đầu gia đình tài chính của bạn',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sau khi tạo couple, app sẽ tự gắn bạn vào couple đó. Bạn cũng có thể tạo sẵn dữ liệu mẫu để dùng ngay.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tên couple',
                    hintText: 'Ví dụ: Nhà An & Linh',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.favorite_outline),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nhập tên couple';
                    }
                    if (value.trim().length < 3) {
                      return 'Tên couple cần ít nhất 3 ký tự';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _currency,
                  decoration: const InputDecoration(
                    labelText: 'Tiền tệ mặc định',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.currency_exchange),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'VND', child: Text('VND')),
                    DropdownMenuItem(value: 'USD', child: Text('USD')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _currency = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _language,
                  decoration: const InputDecoration(
                    labelText: 'Ngôn ngữ',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.language),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'vi', child: Text('Tiếng Việt')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _language = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  value: _createStarterData,
                  onChanged: (value) {
                    setState(() => _createStarterData = value ?? true);
                  },
                  title: const Text('Tạo dữ liệu khởi đầu'),
                  subtitle: const Text(
                    'Bao gồm 1 ví mặc định, 3 danh mục chi tiêu và 3 nguồn thu.',
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.favorite),
                  label: Text(_isLoading ? 'Đang tạo...' : 'Tạo couple'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
