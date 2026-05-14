import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Màn hình nhập mã OTP xác nhận email sau đăng ký.
/// Supabase gửi OTP 8 số qua email ({{ .Token }} trong email template).
class OtpVerifyScreen extends StatefulWidget {
  final String email;
  const OtpVerifyScreen({super.key, required this.email});

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  static const _otpLength = 6;

  final List<TextEditingController> _controllers = List.generate(
    _otpLength,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    _otpLength,
    (_) => FocusNode(),
  );

  bool _isVerifying = false;
  bool _isResending = false;
  String? _otpError;
  int _resendCountdown = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    for (final node in _focusNodes) {
      node.onKeyEvent = _onKey;
    }
    _startCountdown();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  // ─── Countdown ────────────────────────────────────────────────────────────

  void _startCountdown() {
    setState(() {
      _resendCountdown = 60;
      _canResend = false;
    });
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) _canResend = true;
      });
      return _resendCountdown > 0;
    });
  }

  // ─── OTP logic ────────────────────────────────────────────────────────────

  String get _otp => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() {});
    if (_otp.length == _otpLength) _verifyOtp();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace) {
      final index = _focusNodes.indexOf(node);
      if (_controllers[index].text.isEmpty && index > 0) {
        _focusNodes[index - 1].requestFocus();
        _controllers[index - 1].clear();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Future<void> _verifyOtp() async {
    final otp = _otp;
    if (otp.length < _otpLength) {
      setState(() => _otpError = 'Vui lòng nhập đủ $_otpLength chữ số');
      return;
    }
    setState(() {
      _isVerifying = true;
      _otpError = null;
    });
    try {
      await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.signup,
        email: widget.email,
        token: otp,
      );
      // _AuthGate will handle navigation
    } on AuthException catch (e) {
      setState(() => _otpError = _mapError(e.message));
    } catch (_) {
      setState(() => _otpError = 'Đã xảy ra lỗi. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resend() async {
    if (!_canResend || _isResending) return;
    setState(() {
      _isResending = true;
      _otpError = null;
    });
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );
      _startCountdown();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email xác nhận đã được gửi lại'),
          duration: Duration(seconds: 3),
        ),
      );
    } on AuthException catch (e) {
      setState(() => _otpError = _mapError(e.message));
    } catch (_) {
      setState(() => _otpError = 'Không thể gửi lại. Thử lại sau.');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  String _mapError(String msg) {
    final lowerMsg = msg.toLowerCase();
    if (lowerMsg.contains('expired') || lowerMsg.contains('token has expired')) {
      return 'Mã OTP đã hết hạn. Vui lòng yêu cầu gửi lại.';
    }
    if (lowerMsg.contains('invalid') || 
        lowerMsg.contains('incorrect') ||
        lowerMsg.contains('not found')) {
      return 'Mã OTP không đúng. Vui lòng kiểm tra lại email.';
    }
    if (lowerMsg.contains('rate limit') ||
        lowerMsg.contains('over_email_send_rate_limit')) {
      return 'Hệ thống đang giới hạn số email gửi đi. Vui lòng đợi vài phút rồi thử lại.';
    }
    return msg;
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  const Icon(
                    Icons.mark_email_read_outlined,
                    size: 52,
                    color: Colors.teal,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Xác nhận Email',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      children: [
                        const TextSpan(text: 'Email xác nhận đã gửi đến\n'),
                        TextSpan(
                          text: widget.email,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildOtpContent(theme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── OTP content ─────────────────────────────────────────────────────────

  Widget _buildOtpContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // OTP boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_otpLength, (i) {
            return SizedBox(
              width: 48,
              height: 56,
              child: TextFormField(
                controller: _controllers[i],
                focusNode: _focusNodes[i],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                obscureText: false,
                autocorrect: false,
                enableSuggestions: false,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(1),
                ],
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace', // Ensure digits are standard
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: _controllers[i].text.isNotEmpty
                      ? theme.colorScheme.primaryContainer.withAlpha(150)
                      : theme.colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (v) => _onDigitChanged(i, v),
              ),
            );
          }),
        ),

        if (_otpError != null) ...[
          const SizedBox(height: 12),
          _ErrorBox(message: _otpError!, theme: theme),
        ],

        const SizedBox(height: 20),

        FilledButton(
          onPressed: (_isVerifying || _otp.length < _otpLength)
              ? null
              : _verifyOtp,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isVerifying
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Xác nhận',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
        ),
        const SizedBox(height: 14),

        Center(
          child: _isResending
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : _canResend
              ? TextButton(
                  onPressed: _resend,
                  child: const Text('Gửi lại email'),
                )
              : Text(
                  'Gửi lại sau $_resendCountdown giây',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
        ),
      ],
    );
  }
}

// ─── Shared widgets ────────────────────────────────────────────────────────────

class _ErrorBox extends StatelessWidget {
  final String message;
  final ThemeData theme;
  const _ErrorBox({required this.message, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
