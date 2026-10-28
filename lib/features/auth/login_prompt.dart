import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shown in place of a screen that needs an account.
class LoginPrompt extends StatelessWidget {
  const LoginPrompt({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock_outline, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 20),
            FilledButton(onPressed: () => context.push('/login'), child: const Text('تسجيل الدخول')),
          ]),
        ),
      );
}
