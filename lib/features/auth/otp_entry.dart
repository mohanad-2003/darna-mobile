import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/bidi.dart';
import '../../core/widgets/settings_widgets.dart';

/// The code step shared by the flows that re-verify a phone (changing the number,
/// deleting the account): explains where the code went, takes it, and offers a resend
/// once the cool-down ends.
///
/// It never submits by itself, so a sensitive action always needs a deliberate tap.
class OtpEntry extends StatefulWidget {
  const OtpEntry({
    super.key,
    required this.phone,
    required this.challenge,
    required this.onVerify,
    required this.onResend,
    required this.verifyLabel,
    this.destructive = false,
    this.onBusyChanged,
  });

  /// The number the code was sent to, as E.164.
  final String phone;
  final OtpChallenge challenge;

  /// Runs the action with the typed code. Throw an [ApiException] to show its message
  /// under the field; any other outcome means the step is done.
  final Future<void> Function(String code, OtpChallenge challenge) onVerify;

  /// Asks for a new code.
  final Future<OtpChallenge> Function() onResend;
  final String verifyLabel;

  /// Styles the button as an irreversible action.
  final bool destructive;

  /// Tells the parent while the action is in flight, e.g. to block leaving the screen.
  final ValueChanged<bool>? onBusyChanged;

  @override
  State<OtpEntry> createState() => _OtpEntryState();
}

class _OtpEntryState extends State<OtpEntry> {
  final _code = TextEditingController();
  late OtpChallenge _challenge = widget.challenge;
  Timer? _timer;
  late int _secondsLeft = _challenge.resendAfterSeconds;
  bool _busy = false;
  bool _resending = false;
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
      if (!mounted) return t.cancel();
      setState(() => _secondsLeft = _secondsLeft > 0 ? _secondsLeft - 1 : 0);
      if (_secondsLeft == 0) t.cancel();
    });
  }

  void _setBusy(bool value) {
    _busy = value;
    widget.onBusyChanged?.call(value);
  }

  Future<void> _verify() async {
    if (_busy) return;
    final code = _code.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'أدخل الرمز المرسل إليك');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _setBusy(true);
      _error = null;
    });
    try {
      await widget.onVerify(code, _challenge);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() => _setBusy(false));
      } else {
        widget.onBusyChanged?.call(false);
      }
    }
  }

  Future<void> _resend() async {
    if (_resending || _busy) return;
    setState(() => _resending = true);
    try {
      final next = await widget.onResend();
      if (!mounted) return;
      setState(() {
        _challenge = next;
        _error = null;
        _code.clear();
      });
      _startCountdown();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'أرسلنا رمز تحقق إلى '),
              TextSpan(
                // The number is left-to-right even inside Arabic text.
                text: ltrIsolate(widget.phone),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          style: theme.textTheme.bodyLarge,
        ),
        if (kDebugMode) ...[
          const SizedBox(height: 8),
          Text(
            'وضع التطوير: الرمز لا يصل برسالة، بل يظهر في سجل الخادم (Logs في Render، أو نافذة npm run dev محلياً).',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.tertiary),
          ),
        ],
        const SizedBox(height: 24),
        TextField(
          textDirection: TextDirection.ltr,
          controller: _code,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          autofocus: true,
          maxLength: 6,
          textAlign: TextAlign.center,
          autofillHints: const [AutofillHints.oneTimeCode],
          style: theme.textTheme.headlineMedium?.copyWith(letterSpacing: 8),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'رمز التحقق',
            border: const OutlineInputBorder(),
            errorText: _error,
            errorMaxLines: 3,
            counterText: '',
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _verify(),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _verify,
          style: widget.destructive
              ? FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                )
              : null,
          child: _busy ? const ButtonSpinner() : Text(widget.verifyLabel),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: _secondsLeft == 0 && !_resending && !_busy
              ? _resend
              : null,
          child: Text(
            _secondsLeft == 0
                ? 'إعادة إرسال الرمز'
                : 'إعادة الإرسال بعد $_secondsLeft ثانية',
          ),
        ),
      ],
    );
  }
}
