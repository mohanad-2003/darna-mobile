import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum EmptyStateIllustration {
  listings,
  favorites,
  search,
  notifications,
  inquiries,
  review,
}

/// A successful, empty response with context and an optional next step.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.illustration,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.onRefresh,
  }) : assert((actionLabel == null) == (onAction == null));

  final EmptyStateIllustration illustration;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        'assets/empty_states/${illustration.name}.svg',
                        width: 260,
                        height: (constraints.maxHeight * .38).clamp(
                          100.0,
                          210.0,
                        ),
                        excludeFromSemantics: true,
                      ),
                      const SizedBox(height: 16),
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        description,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.7,
                        ),
                      ),
                      if (onAction != null) ...[
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: onAction,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 14,
                            ),
                          ),
                          child: Text(actionLabel!),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        return onRefresh == null
            ? content
            : RefreshIndicator(onRefresh: onRefresh!, child: content);
      },
    );
  }
}
