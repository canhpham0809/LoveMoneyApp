import 'package:flutter/material.dart';

import 'package:flutter_app_demo/features/settings/data/services/settings_service.dart';

class JoinCoupleScreen extends StatefulWidget {
  const JoinCoupleScreen({super.key});

  @override
  State<JoinCoupleScreen> createState() => _JoinCoupleScreenState();
}

class _JoinCoupleScreenState extends State<JoinCoupleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _settingsService = SettingsService();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _settingsService.joinCoupleByCode(_codeCtrl.text);
      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      final message = e.toString();
      String friendly = 'Không tham gia được couple.';
      if (message.contains('INVALID_COUPLE_CODE')) {
        friendly = 'Mã couple không đúng.';
      } else if (message.contains('ALREADY_IN_COUPLE')) {
        friendly = 'Bạn đã thuộc một couple khác.';
      } else if (message.contains('UNAUTHENTICATED')) {
        friendly = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$friendly\n$message')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tham gia couple')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Nhập mã mời từ người còn lại',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Mỗi couple tối đa 2 người. Sau khi tham gia, bạn sẽ dùng chung dữ liệu tài chính.',
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Mã couple',
                    hintText: 'Ví dụ: A1B2C3D4',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.key_outlined),
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) {
                      return 'Nhập mã couple';
                    }
                    if (v.length < 6) {
                      return 'Mã quá ngắn';
                    }
                    return null;
                  },
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
                      : const Icon(Icons.group_add),
                  label: Text(
                    _isLoading ? 'Đang tham gia...' : 'Tham gia couple',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
