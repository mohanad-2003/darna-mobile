import 'package:flutter/material.dart';

import '../../core/widgets/illustration.dart';

/// Shown right after a listing is sent for review.
Future<void> showSubmittedDialog(BuildContext context) => showDialog<void>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const ClayIllustration(StateArt.submitted, size: 200),
              const SizedBox(height: 20),
              Text(
                'تم إرسال إعلانك للمراجعة',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'سيراجعه فريقنا قريباً، وتصلك رسالة بالنتيجة. يمكنك متابعة حالته من إعلاناتي.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('حسناً')),
              ),
            ]),
          ),
        );
      },
    );
