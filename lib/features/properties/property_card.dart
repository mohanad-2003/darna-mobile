import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import 'format.dart';
import 'listings_controller.dart';
import 'models.dart';

class PropertyCardTile extends ConsumerWidget {
  const PropertyCardTile({super.key, required this.property, this.heroScope = 'list'});

  final PropertyCard property;

  /// Makes the photo's Hero tag unique per list: the home and favorites tabs stay alive
  /// together, and the same listing can appear in both.
  final String heroScope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = property;
    final heroTag = '$heroScope-photo-${p.id}';
    final isFavorite = ref.watch(favoriteOverridesProvider.select((m) => m[p.id])) ?? p.isFavorite;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: () => context.push(
          '/property/${p.id}',
          extra: <String, String?>{'tag': heroTag, 'url': p.coverThumbnailUrl},
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: heroTag,
                    child: p.coverThumbnailUrl == null
                        ? const _ImagePlaceholder()
                        : CachedNetworkImage(
                            imageUrl: p.coverThumbnailUrl!,
                            fit: BoxFit.cover,
                            fadeInDuration: const Duration(milliseconds: 200),
                            placeholder: (_, _) => const _ImagePlaceholder(),
                            errorWidget: (_, _, _) => const _ImagePlaceholder(),
                          ),
                  ),
                  // Darkens the bottom so the price stays readable on any photo.
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.45, 1],
                          colors: [Colors.transparent, Color(0xB3000000)],
                        ),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    top: 10,
                    start: 10,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      _Badge(text: purposeName(p.purpose), color: scheme.primary, textColor: scheme.onPrimary),
                      const SizedBox(width: 6),
                      _Badge(
                        text: propertyTypeNames[p.propertyType] ?? '',
                        color: Colors.black54,
                        textColor: Colors.white,
                      ),
                    ]),
                  ),
                  PositionedDirectional(
                    top: 6,
                    end: 6,
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: isFavorite ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                          child: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            key: ValueKey(isFavorite),
                            color: isFavorite ? Colors.red : Colors.black87,
                          ),
                        ),
                        onPressed: () => toggleFavorite(context, ref, p.id, isFavorite),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    bottom: 10,
                    start: 14,
                    end: 14,
                    child: Text(
                      formatPrice(p),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: const [Shadow(blurRadius: 6, color: Colors.black45)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (p.location != null) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.place_outlined, size: 16, color: scheme.outline),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          p.location!.breadcrumbAr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ]),
                  ],
                  const SizedBox(height: 10),
                  Row(children: [
                    if (p.bedrooms != null) _Spec(icon: Icons.bed_outlined, text: '${p.bedrooms}'),
                    if (p.bathrooms != null) _Spec(icon: Icons.bathtub_outlined, text: '${p.bathrooms}'),
                    if (p.areaSqm != null) _Spec(icon: Icons.square_foot, text: formatArea(p.areaSqm!)),
                    const Spacer(),
                    if (p.office?.verified == true)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.verified, size: 16, color: scheme.primary),
                        const SizedBox(width: 4),
                        Text('مكتب موثّق', style: theme.textTheme.bodySmall?.copyWith(color: scheme.primary)),
                      ]),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Toggles the heart, sending signed-out users to the login screen first.
Future<void> toggleFavorite(BuildContext context, WidgetRef ref, String id, bool current) async {
  final messenger = ScaffoldMessenger.of(context);
  if (ref.read(authControllerProvider).value == null) {
    context.push('/login');
    return;
  }
  HapticFeedback.lightImpact();
  final error = await ref.read(favoriteOverridesProvider.notifier).toggle(id, current: current);
  if (error != null) messenger.showSnackBar(SnackBar(content: Text(error)));
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(Icons.home_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
      );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color, required this.textColor});

  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w500)),
      );
}

class _Spec extends StatelessWidget {
  const _Spec({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 16),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 4),
          Text(text),
        ]),
      );
}
