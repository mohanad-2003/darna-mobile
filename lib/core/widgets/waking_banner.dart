import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';

/// A slim notice at the top while the server is waking up, so a slow first request does
/// not look like a frozen app.
class WakingBanner extends ConsumerWidget {
  const WakingBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waking = ref.watch(apiClientProvider).isWaking;
    return ValueListenableBuilder<bool>(
      valueListenable: waking,
      builder: (context, on, _) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: !on
            ? const SizedBox.shrink()
            : SafeArea(
                bottom: false,
                child: Material(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'نجهّز الخدمة، قد يستغرق ذلك لحظات…',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
      ),
    );
  }
}
