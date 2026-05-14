import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_app_demo/core/theme/app_colors.dart';
import 'otp_verify_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirm = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
    if (v.length < 8) return 'Mật khẩu tối thiểu 8 ký tự';
    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Cần ít nhất 1 chữ hoa (A-Z)';
    if (!RegExp(r'[a-z]').hasMatch(v)) return 'Cần ít nhất 1 chữ thường (a-z)';
    if (!RegExp(r'[0-9]').hasMatch(v)) return 'Cần ít nhất 1 chữ số (0-9)';
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(v)) {
      return 'Cần ít nhất 1 ký tự đặc biệt (!@#\$%...)';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (!mounted) return;

      // Supabase trả identities rỗng khi email đã tồn tại (security by design)
      if (res.user != null && (res.user!.identities?.isEmpty ?? true)) {
        setState(
          () => _error =
              'Email này đã được đăng ký. Vui lòng đăng nhập hoặc dùng email khác.',
        );
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpVerifyScreen(email: _emailCtrl.text.trim()),
        ),
      );
    } on AuthException catch (e) {
      setState(() => _error = _mapAuthError(e.message));
    } catch (e) {
      setState(() => _error = 'Đã xảy ra lỗi. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _mapAuthError(String msg) {
    if (msg.contains('already registered') ||
        msg.contains('already exists') ||
        msg.contains('User already registered')) {
      return 'Email này đã được đăng ký. Vui lòng đăng nhập hoặc dùng email khác.';
    }
    if (msg.contains('invalid email')) return 'Email không hợp lệ.';
    if (msg.contains('rate limit') ||
        msg.contains('over_email_send_rate_limit')) {
      return 'Hệ thống đang giới hạn số email gửi đi. Vui lòng đợi vài phút rồi thử lại.';
    }
    if (msg.contains('Password should be')) {
      return 'Mật khẩu chưa đủ mạnh. Vui lòng kiểm tra lại.';
    }
    return msg;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      body: Stack(
        children: [
          // Background Decoration
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.teal.withValues(alpha: 0.05),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Header
                              Text(
                                'Tạo tài khoản mới',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : AppColors.tealDeep,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Bắt đầu hành trình quản lý tài chính cùng người thân ngay hôm nay.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Email
                              TextFormField(
                                controller: _emailCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'Địa chỉ Email',
                                  prefixIcon: Icon(Icons.email_outlined, size: 20),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Vui lòng nhập email';
                                  }
                                  if (!RegExp(
                                    r'^[\w\.\+\-]+@[\w\-]+\.[a-z]{2,}$',
                                  ).hasMatch(v.trim())) {
                                    return 'Email không đúng định dạng';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Password
                              TextFormField(
                                controller: _passwordCtrl,
                                obscureText: !_showPassword,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  hintText: 'Mật khẩu',
                                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _showPassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        setState(() => _showPassword = !_showPassword),
                                  ),
                                ),
                                validator: _validatePassword,
                              ),
                              const SizedBox(height: 12),

                              // Password strength hint
                              _PasswordHintRow(password: _passwordCtrl.text),

                              const SizedBox(height: 16),

                              // Confirm password
                              TextFormField(
                                controller: _confirmCtrl,
                                obscureText: !_showConfirm,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  hintText: 'Xác nhận mật khẩu',
                                  prefixIcon: const Icon(Icons.lock_reset_outlined, size: 22),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _showConfirm
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        setState(() => _showConfirm = !_showConfirm),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Vui lòng nhập lại mật khẩu';
                                  }
                                  if (v != _passwordCtrl.text) {
                                    return 'Mật khẩu không khớp';
                                  }
                                  return null;
                                },
                              ),

                              // Error message
                              if (_error != null) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.dangerSoft.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.danger.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline,
                                        color: AppColors.danger,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: const TextStyle(
                                            color: AppColors.danger,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 32),

                              // Register button
                              FilledButton(
                                onPressed: _isLoading ? null : _submit,
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Đăng ký tài khoản'),
                              ),
                              const SizedBox(height: 16),

                              // Back to login
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Đã có tài khoản?',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text(
                                      'Đăng nhập ngay',
                                      style: TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Hiển thị gợi ý độ mạnh mật khẩu
class _PasswordHintRow extends StatelessWidget {
  final String password;
  const _PasswordHintRow({required this.password});

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    final checks = [
      (RegExp(r'.{8,}').hasMatch(password), '8+ ký tự'),
      (RegExp(r'[A-Z]').hasMatch(password), 'Chữ hoa'),
      (RegExp(r'[a-z]').hasMatch(password), 'Chữ thường'),
      (RegExp(r'[0-9]').hasMatch(password), 'Số'),
      (
        RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(password),
        'Ký tự đặc biệt',
      ),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: checks.map((c) {
        final ok = c.$1;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              size: 14,
              color: ok ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 3),
            Text(
              c.$2,
              style: TextStyle(
                fontSize: 12,
                color: ok ? Colors.green : Colors.grey,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
