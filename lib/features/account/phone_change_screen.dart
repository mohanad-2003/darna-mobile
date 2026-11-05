import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/bidi.dart';
import '../../core/widgets/settings_widgets.dart';
import '../auth/login_prompt.dart';
import '../auth/login_screen.dart' show normalizePhone;
import '../auth/otp_entry.dart';

enum _Step { phone, code, done }

/// Moves the account to a new number: enter it, prove you own it with a code sent
/// there, done. The current number stays in force until the code is accepted.
class PhoneChangeScreen extends ConsumerStatefulWidget {
  const PhoneChangeScreen({super.key});

  @override
  ConsumerState<PhoneChangeScreen> createState() => _PhoneChangeScreenState();
}

class _PhoneChangeScreenState extends ConsumerState<PhoneChangeScreen> {
  final _phone = TextEditingController();
  _Step _step = _Step.phone;
  OtpChallenge? _challenge;
  String? _newPhone;
  bool _sending = false;
  bool _verifying = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_sending) return;
    final me = ref.read(authControllerProvider).value;
    final phone = normalizePhone(_phone.text);
    if (phone == null) {
      setState(() => _error = 'أدخل رقم هاتف صحيحاً، مثل 0599123456');
      return;
    }
    if (phone == me?.phone) {
      setState(() => _error = 'هذا هو رقمك الحالي، أدخل الرقم الجديد');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final challenge = await ref
          .read(authControllerProvider.notifier)
          .requestPhoneChange(phone);
      if (!mounted) return;
      setState(() {
        _newPhone = phone;
        _challenge = challenge;
        _step = _Step.code;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verify(String code, OtpChallenge challenge) async {
    await ref
        .read(authControllerProvider.notifier)
        .confirmPhoneChange(
          phone: _newPhone!,
          challengeId: challenge.challengeId,
          code: code,
        );
    if (mounted) setState(() => _step = _Step.done);
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authControllerProvider).value;
    final signedOut = me == null && _step == _Step.phone;

    return PopScope(
      // From the code step, back returns to the number instead of leaving the flow, and
      // nothing is left while the code is being checked.
      canPop: _step != _Step.code,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_verifying) setState(() => _step = _Step.phone);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('تغيير رقم الهاتف')),
        body: signedOut
            ? const LoginPrompt(message: 'سجّل الدخول لتغيير رقم هاتفك')
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0, .04),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: switch (_step) {
                      _Step.phone => _buildPhoneStep(context, me?.phone ?? ''),
                      _Step.code => _buildCodeStep(context),
                      _Step.done => _buildDone(context),
                    },
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildPhoneStep(BuildContext context, String current) {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey(_Step.phone),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('ما رقمك الجديد؟', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'رقمك الحالي '),
              TextSpan(
                text: ltrIsolate(current),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text: '. سنرسل رمز تحقق إلى الرقم الجديد، ولن يتغيّر رقمك إلا بعد إدخال الرمز.',
              ),
            ],
          ),
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        TextField(
          textDirection: TextDirection.ltr,
          controller: _phone,
          enabled: !_sending,
          keyboardType: TextInputType.phone,
          autofocus: true,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-]')),
          ],
          decoration: InputDecoration(
            labelText: 'رقم الهاتف الجديد',
            hintText: '0599 123 456',
            border: const OutlineInputBorder(),
            errorText: _error,
            errorMaxLines: 4,
            prefixIcon: const Icon(Icons.phone_outlined),
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _sendCode(),
        ),
        const SizedBox(height: 12),
        const InlineMessage(
          isError: false,
          text: 'إذا كان الرقم مسجلاً في حساب آخر فلن نتمكن من استخدامه، ولا يتم دمج الحسابات.',
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _sending ? null : _sendCode,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: _sending
              ? const ButtonSpinner()
              : const Text('إرسال رمز التحقق'),
        ),
      ],
    );
  }

  Widget _buildCodeStep(BuildContext context) {
    final theme = Theme.of(context);
    final notifier = ref.read(authControllerProvider.notifier);
    return Column(
      key: const ValueKey(_Step.code),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('أكّد رقمك الجديد', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        OtpEntry(
          phone: _newPhone!,
          challenge: _challenge!,
          verifyLabel: 'تأكيد وتغيير الرقم',
          onVerify: _verify,
          onResend: () => notifier.requestPhoneChange(_newPhone!),
          onBusyChanged: (busy) {
            if (mounted) setState(() => _verifying = busy);
          },
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _verifying
              ? null
              : () => setState(() => _step = _Step.phone),
          child: const Text('تعديل الرقم'),
        ),
      ],
    );
  }

  Widget _buildDone(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      key: const ValueKey(_Step.done),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Center(
          child: CircleAvatar(
            radius: 36,
            backgroundColor: scheme.primaryContainer,
            foregroundColor: scheme.onPrimaryContainer,
            child: const Icon(Icons.check, size: 40),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'تم تغيير رقم هاتفك',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'رقمك الآن '),
              TextSpan(
                text: ltrIsolate(_newPhone!),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text: '. تم تسجيل خروج حسابك من أي جهاز آخر لحمايته.',
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('تم'),
        ),
      ],
    );
  }
}
