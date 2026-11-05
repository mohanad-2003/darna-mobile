import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/widgets/settings_widgets.dart';
import '../auth/login_prompt.dart';
import '../auth/otp_entry.dart';

enum _Step { explain, code, done }

/// Deleting the account: what it does, an explicit acknowledgement, then a code sent to
/// the current number. "Deleted" is only ever shown after the server says so.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  _Step _step = _Step.explain;
  bool _understood = false;
  bool _sending = false;
  bool _deleting = false;
  String? _error;
  OtpChallenge? _challenge;
  String? _phone;

  Future<void> _sendCode() async {
    if (_sending || !_understood) return;
    final me = ref.read(authControllerProvider).value;
    if (me == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final challenge = await ref
          .read(authControllerProvider.notifier)
          .requestAccountDeletion();
      if (!mounted) return;
      setState(() {
        _phone = me.phone;
        _challenge = challenge;
        _step = _Step.code;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(String code, OtpChallenge challenge) async {
    await ref
        .read(authControllerProvider.notifier)
        .deleteAccount(challengeId: challenge.challengeId, code: code);
    if (mounted) setState(() => _step = _Step.done);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final me = auth.value;
    // Deleting signs the user out, so "no account" is expected once the code step starts.
    final needsLogin = me == null && _step == _Step.explain;

    return PopScope(
      canPop: _step != _Step.code,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_deleting) setState(() => _step = _Step.explain);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('حذف الحساب'),
          // Nothing to go back to once the account is gone.
          automaticallyImplyLeading: _step != _Step.done,
        ),
        body: needsLogin
            ? (auth.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : const LoginPrompt(message: 'سجّل الدخول لإدارة حسابك'))
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
                      _Step.explain => _buildExplain(context),
                      _Step.code => _buildCode(context),
                      _Step.done => _buildDone(context),
                    },
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildExplain(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      key: const ValueKey(_Step.explain),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ExcludeSemantics(
                child: Icon(
                  Icons.delete_forever_outlined,
                  color: scheme.onErrorContainer,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  'حذف حسابك نهائياً',
                  style: theme.textTheme.headlineSmall,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'هذا الإجراء لا يمكن التراجع عنه. اقرأ ما سيحدث قبل المتابعة.',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 20),
        const _ImpactCard(
          title: 'ما سيُحذف أو يتوقف',
          icon: Icons.remove_circle_outline,
          items: [
            'حسابك: لن تتمكن من الدخول إليه أو استرجاعه. يمكنك لاحقاً إنشاء حساب جديد بالرقم نفسه، لكنه سيبدأ فارغاً.',
            'إعلاناتك: تُؤرشف وتختفي من التطبيق، ولا يمكن إعادة نشرها. وتُحذف صورها نهائياً بعد 30 يوماً.',
            'بياناتك الشخصية: الاسم والبريد الإلكتروني ورقم الهاتف، ومعها المفضلة والإشعارات والأجهزة المسجلة.',
            'جلساتك: يتم تسجيل خروجك من هذا الجهاز ومن كل الأجهزة الأخرى.',
          ],
        ),
        const SizedBox(height: 12),
        const _ImpactCard(
          title: 'ما سيبقى',
          icon: Icons.history,
          items: [
            'الرسائل التي أرسلتها للمعلنين تبقى عندهم دون اسمك أو رقمك، ويُحذف نصها بعد 90 يوماً.',
            'سجلات البلاغات والمراجعة اللازمة لسلامة المنصة، دون بياناتك الشخصية.',
          ],
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          InlineMessage(text: _error!),
          const SizedBox(height: 12),
        ],
        // The whole row toggles, so the tap target is large and reads as one control.
        CheckboxListTile(
          value: _understood,
          onChanged: _sending
              ? null
              : (v) => setState(() => _understood = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: const Text('أفهم أن حذف حسابي نهائي ولا يمكن التراجع عنه'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _understood && !_sending ? _sendCode : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          child: _sending
              ? const ButtonSpinner()
              : const Text('متابعة وإرسال رمز التحقق'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء، أبقِ حسابي'),
        ),
      ],
    );
  }

  Widget _buildCode(BuildContext context) {
    final theme = Theme.of(context);
    final notifier = ref.read(authControllerProvider.notifier);
    return Column(
      key: const ValueKey(_Step.code),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('أكّد هويتك', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        OtpEntry(
          phone: _phone!,
          challenge: _challenge!,
          verifyLabel: 'حذف حسابي نهائياً',
          destructive: true,
          onVerify: _delete,
          onResend: notifier.requestAccountDeletion,
          onBusyChanged: (busy) {
            if (mounted) setState(() => _deleting = busy);
          },
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _deleting
              ? null
              : () => setState(() => _step = _Step.explain),
          child: const Text('رجوع'),
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
          'تم حذف حسابك',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'شكراً لاستخدامك دارنا. يمكنك مواصلة تصفح العقارات كزائر، أو إنشاء حساب جديد في أي وقت.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () => context.go('/'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('العودة إلى الرئيسية'),
        ),
      ],
    );
  }
}

class _ImpactCard extends StatelessWidget {
  const _ImpactCard({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Icon(icon, size: 20, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ExcludeSemantics(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: scheme.outline,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(item, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
