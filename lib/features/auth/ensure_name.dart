import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/auth_controller.dart';

/// Gate for actions that need an account with a name (publishing a listing).
/// Sends anonymous users to login, asks for the name if it is missing, and returns
/// true only when the caller can go on.
Future<bool> ensureSignedInWithName(BuildContext context, WidgetRef ref) async {
  var me = ref.read(authControllerProvider).value;
  if (me == null) {
    context.push('/login');
    return false;
  }
  if (me.fullName != null && me.fullName!.trim().isNotEmpty) return true;

  final name = await showDialog<String>(
    context: context,
    builder: (_) => const _NameDialog(),
  );
  if (name == null || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(authControllerProvider.notifier).updateName(name);
    me = ref.read(authControllerProvider).value;
    return true;
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return false;
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog();

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('أضف اسمك'),
        content: TextField(
          controller: _name,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'الاسم الكامل',
            helperText: 'يظهر للمهتمين بإعلانك',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final v = _name.text.trim();
              if (v.length >= 2) Navigator.of(context).pop(v);
            },
            child: const Text('حفظ'),
          ),
        ],
      );
}
