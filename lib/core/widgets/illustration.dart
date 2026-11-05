import 'package:flutter/material.dart';

import '../api/api_exception.dart';

enum StateArt {
  welcome('welcome_phone'),
  submitted('listing_under_review'),
  offline('no_connection'),
  unavailable('listing_unavailable'),
  addPhotos('add_listing_photos');

  const StateArt(this.file);
  final String file;
  String get asset => 'assets/illustrations/$file.webp';
}

class ClayIllustration extends StatelessWidget {
  const ClayIllustration(this.art, {super.key, this.size = 180});

  final StateArt art;
  final double size;

  @override
  Widget build(BuildContext context) {
    // The art has a transparent background (see tool/export_assets.cjs), so it sits directly
    // on the screen with no frame, in light and dark themes alike.
    return Image.asset(art.asset, width: size, height: size, fit: BoxFit.contain, excludeFromSemantics: true);
  }
}

/// A failed load, with art that fits the reason: no connection, a listing that is gone, or a
/// plain message for anything else.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({super.key, required this.message, this.art, this.onRetry, this.actionLabel, this.onAction});

  /// Picks the art and the message from the error itself. [onRetry] is offered whenever trying
  /// again can help (not for a listing that no longer exists).
  factory ErrorStateView.from(Object error, {required VoidCallback onRetry, String? fallback, VoidCallback? onBack}) {
    if (error is ApiException) {
      if (error.code == 'PROPERTY_NOT_FOUND' || error.status == 404) {
        return ErrorStateView(
          message: 'هذا الإعلان لم يعد متاحاً. ربما بيع أو أُوقف أو حُذف.',
          art: StateArt.unavailable,
          actionLabel: onBack == null ? null : 'العودة',
          onAction: onBack,
        );
      }
      if (error.isNetwork) {
        return ErrorStateView(message: error.message, art: StateArt.offline, onRetry: onRetry);
      }
      return ErrorStateView(message: error.message, onRetry: onRetry);
    }
    return ErrorStateView(message: fallback ?? 'تعذر التحميل', art: StateArt.offline, onRetry: onRetry);
  }

  /// For screens that keep only the message text and an "offline" flag.
  factory ErrorStateView.text(String message, {required bool offline, required VoidCallback onRetry}) =>
      ErrorStateView(message: message, art: offline ? StateArt.offline : null, onRetry: onRetry);

  final String message;
  final StateArt? art;
  final VoidCallback? onRetry;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (art != null)
              ClayIllustration(art!, size: 200)
            else
              Icon(Icons.error_outline, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
            if (onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ]),
        ),
      ),
    );
  }
}
