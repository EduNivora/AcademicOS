import 'package:flutter/material.dart';

import '../../domain/usecases/auth_use_cases.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final AuthUseCases authUseCases;
  final Future<void> Function() onVerificationSuccess;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.authUseCases,
    required this.onVerificationSuccess,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_isLoading || !(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      final verified = await widget.authUseCases.verifyEmailOtp.call(
        email: widget.email,
        otp: _otpController.text.trim(),
      );
      if (!mounted) return;
      if (!verified) {
        setState(() {
          _message = 'رمز التحقق غير صحيح أو انتهت صلاحيته.';
          _messageIsError = true;
          _isLoading = false;
        });
        return;
      }
      await widget.onVerificationSuccess();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'تعذّر التحقق. راجع الرمز واتصال الإنترنت ثم أعد المحاولة.';
        _messageIsError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _resend() async {
    if (_isLoading || _isResending) return;
    setState(() {
      _isResending = true;
      _message = null;
    });
    try {
      await widget.authUseCases.resendEmailVerificationOtp.call(widget.email);
      if (!mounted) return;
      setState(() {
        _message = 'أرسلنا رمز تحقق جديداً إلى بريدك الإلكتروني.';
        _messageIsError = false;
        _isResending = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'تعذّر إرسال الرمز الآن. حاول بعد قليل.';
        _messageIsError = true;
        _isResending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('التحقق من البريد الإلكتروني')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.mark_email_read_outlined, size: 54),
                    const SizedBox(height: 18),
                    Text(
                      'أدخل رمز التحقق',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'أرسلنا رمزاً إلى ${widget.email}. أدخل الرمز لإكمال إنشاء الحساب.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _otpController,
                      enabled: !_isLoading,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 8,
                      decoration: const InputDecoration(
                        labelText: 'رمز التحقق',
                        counterText: '',
                      ),
                      validator: (value) {
                        final otp = value?.trim() ?? '';
                        if (otp.length < 4 || otp.length > 8) {
                          return 'أدخل رمز التحقق المرسل إليك';
                        }
                        return null;
                      },
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _message!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _messageIsError ? colors.error : colors.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _isLoading ? null : _verify,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('تأكيد البريد الإلكتروني'),
                    ),
                    TextButton(
                      onPressed: _isLoading || _isResending ? null : _resend,
                      child: _isResending
                          ? const Text('جارٍ إرسال الرمز...')
                          : const Text('إعادة إرسال رمز التحقق'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
