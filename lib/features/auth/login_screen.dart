import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/auth_controller.dart';

class OtpArgs {
  OtpArgs({required this.phone, required this.challenge});

  final String phone;
  final OtpChallenge challenge;
}

/// Turns what people type (059xxxxxxx, 00970..., +970...) into E.164, or null if invalid.
String? normalizePhone(String input) {
  var s = input.replaceAll(RegExp(r'[\s\-()]'), '');
  if (s.startsWith('+')) {
    // keep
  } else if (s.startsWith('00')) {
    s = '+${s.substring(2)}';
  } else if (s.startsWith('0')) {
    s = '+970${s.substring(1)}';
  } else if (RegExp(r'^5[0-9]{8}$').hasMatch(s)) {
    s = '+970$s';
  }
  return RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(s) ? s : null;
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = normalizePhone(_phone.text);
    if (phone == null) {
      setState(() => _error = 'أدخل رقم هاتف صحيحاً، مثل 0599123456');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final challenge = await ref.read(authControllerProvider.notifier).requestOtp(phone);
      if (!mounted) return;
      context.push('/login/otp', extra: OtpArgs(phone: phone, challenge: challenge));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('تسجيل الدخول', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text('أدخل رقم هاتفك وسنرسل لك رمز تحقق. لا حاجة لكلمة مرور.',
                  style: theme.textTheme.bodyLarge),
              const SizedBox(height: 32),
              Directionality(
                textDirection: TextDirection.ltr,
                child: TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  autofocus: true,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-]'))],
                  decoration: InputDecoration(
                    labelText: 'رقم الهاتف',
                    hintText: '0599 123 456',
                    border: const OutlineInputBorder(),
                    errorText: _error,
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('إرسال الرمز'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
