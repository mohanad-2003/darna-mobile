import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/widgets/settings_widgets.dart';
import '../auth/login_prompt.dart';
import 'profile_validation.dart';

/// Edit the name and the optional email. Saving is possible only when something changed
/// and everything is valid; leaving with unsaved changes asks first.
class ProfileEditScreen extends ConsumerWidget {
  const ProfileEditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final me = auth.value;
    if (me != null) return _ProfileForm(me: me);
    return Scaffold(
      appBar: AppBar(title: const Text('تعديل الملف الشخصي')),
      body: auth.isLoading
          ? const Center(child: CircularProgressIndicator())
          : const LoginPrompt(message: 'سجّل الدخول لتعديل ملفك الشخصي'),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.me});

  final Me me;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.me.fullName ?? '');
  late final _email = TextEditingController(text: widget.me.email ?? '');

  bool _saving = false;
  bool _saved = false;
  String? _banner;
  bool _bannerIsNetwork = false;
  String? _emailServerError;

  @override
  void initState() {
    super.initState();
    _name.addListener(_changed);
    _email.addListener(() {
      _emailServerError = null;
      _changed();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  bool get _dirty =>
      _name.text.trim() != (widget.me.fullName ?? '') ||
      _email.text.trim().toLowerCase() != (widget.me.email ?? '').toLowerCase();

  bool get _valid =>
      validateFullName(_name.text) == null &&
      validateEmail(_email.text) == null;

  bool get _canSave => _dirty && _valid && !_saving;

  Future<void> _save() async {
    if (!_canSave) return;
    FocusScope.of(context).unfocus();
    final me = widget.me;
    final name = _name.text.trim();
    final email = _email.text.trim();
    // Only what changed is sent, so an untouched email cannot clash with anything.
    final changes = <String, Object?>{
      if (name != (me.fullName ?? '')) 'fullName': name,
      if (email.toLowerCase() != (me.email ?? '').toLowerCase())
        'email': email.isEmpty ? null : email,
    };
    setState(() {
      _saving = true;
      _banner = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).updateProfile(changes);
      if (!mounted) return;
      _saved = true;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('تم حفظ التغييرات')));
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'EMAIL_IN_USE') {
        setState(() => _emailServerError = e.message);
        _formKey.currentState?.validate();
      } else {
        setState(() {
          _banner = e.isNetwork
              ? '${e.message}\nما كتبته محفوظ هنا، لم يضع منه شيء.'
              : e.message;
          _bannerIsNetwork = e.isNetwork;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _banner = 'تعذر حفظ التغييرات، حاول مرة أخرى');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تجاهل التغييرات؟'),
        content: const Text('لديك تغييرات لم تُحفظ. إن غادرت الآن ستفقدها.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('متابعة التعديل'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('تجاهل'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      // Navigator.pop, not maybePop: the guard below would stop this one.
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = _name.text.trim();

    return PopScope(
      canPop: _saved || (!_dirty && !_saving),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _saving) return;
        _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('تعديل الملف الشخصي')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.topCenter,
                child: _banner == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: InlineMessage(
                          text: _banner!,
                          onRetry: _bannerIsNetwork && _canSave ? _save : null,
                        ),
                      ),
              ),
              Center(
                child: ExcludeSemantics(
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: scheme.primaryContainer,
                    foregroundColor: scheme.onPrimaryContainer,
                    child: name.isEmpty
                        ? const Icon(Icons.person, size: 36)
                        : Text(
                            name.characters.first,
                            style: theme.textTheme.headlineMedium,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _name,
                        enabled: !_saving,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        decoration: const InputDecoration(
                          labelText: 'الاسم الكامل',
                          helperText: 'يظهر للمعلنين عند إرسال استفساراتك',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                          errorMaxLines: 2,
                        ),
                        validator: validateFullName,
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        textDirection: TextDirection.ltr,
                        controller: _email,
                        enabled: !_saving,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.email],
                        onFieldSubmitted: (_) => _save(),
                        decoration: const InputDecoration(
                          labelText: 'البريد الإلكتروني (اختياري)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.mail_outline),
                          errorMaxLines: 3,
                        ),
                        validator: (v) => _emailServerError ?? validateEmail(v),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _PhoneRow(phone: widget.me.phone, enabled: !_saving),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _canSave ? _save : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: _saving
                      ? Row(
                          key: const ValueKey('saving'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const ButtonSpinner(),
                            const SizedBox(width: 12),
                            const Text('جارٍ الحفظ…'),
                          ],
                        )
                      : const Text('حفظ التغييرات', key: ValueKey('idle')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The phone is not edited here: changing it needs a code sent to the new number.
class _PhoneRow extends StatelessWidget {
  const _PhoneRow({required this.phone, required this.enabled});

  final String phone;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.phone_outlined, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'رقم الهاتف',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(phone, style: theme.textTheme.bodyLarge),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: enabled ? () => context.push('/account/phone') : null,
            style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
            child: const Text('تغيير'),
          ),
        ],
      ),
    );
  }
}
