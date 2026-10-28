import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/auth_controller.dart';
import 'login_screen.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.args});

  final OtpArgs args;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _code = TextEditingController();
  late OtpChallenge _challenge = widget.args.challenge;
  Timer? _timer;
  late int _secondsLeft = _challenge.resendAfterSeconds;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    _secondsLeft = _challenge.resendAfterSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
      }
      setState(() => _secondsLeft = _secondsLeft > 0 ? _secondsLeft - 1 : 0);
    });
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'أدخل الرمز المرسل إليك');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final isNew = await ref.read(authControllerProvider.notifier).verifyOtp(
            phone: widget.args.phone,
            challengeId: _challenge.challengeId,
            code: code,
          );
      if (!mounted) return;
      context.go(isNew ? '/login/name' : '/');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    try {
      final next = await ref.read(authControllerProvider.notifier).requestOtp(widget.args.phone);
      setState(() {
        _challenge = next;
        _error = null;
        _code.clear();
      });
      _startCountdown();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
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
              Text('رمز التحقق', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Directionality(
                textDirection: TextDirection.rtl,
                child: Text.rich(TextSpan(children: [
                  const TextSpan(text: 'أرسلنا رمزاً إلى '),
                  TextSpan(
                    text: widget.args.phone,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ])),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 8),
                Text('وضع التطوير: الرمز لا يصل برسالة، بل يظهر في سجل الخادم (Logs في Render، أو نافذة npm run dev محلياً).',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.tertiary)),
              ],
              const SizedBox(height: 32),
              Directionality(
                textDirection: TextDirection.ltr,
                child: TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(letterSpacing: 8),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    errorText: _error,
                    counterText: '',
                  ),
                  onChanged: (v) {
                    if (v.length == 6 && !_busy) _verify();
                  },
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _verify,
                child: _busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('تأكيد'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _secondsLeft == 0 ? _resend : null,
                child: Text(_secondsLeft == 0 ? 'إعادة إرسال الرمز' : 'إعادة الإرسال بعد $_secondsLeft ثانية'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
