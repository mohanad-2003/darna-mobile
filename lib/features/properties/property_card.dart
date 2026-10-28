import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import 'format.dart';
import 'listings_controller.dart';
import 'models.dart';

class PropertyCardTile extends ConsumerWidget {
  const PropertyCardTile({super.key, required this.property});

  final PropertyCard property;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final p = property;
    final isFavorite = ref.watch(favoriteOverridesProvider.select((m) => m[p.id])) ?? p.isFavorite;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => context.push('/property/${p.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: p.coverThumbnailUrl == null
                      ? const _ImagePlaceholder()
                      : CachedNetworkImage(
                          imageUrl: p.coverThumbnailUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => const _ImagePlaceholder(),
                          errorWidget: (_, _, _) => const _ImagePlaceholder(),
                        ),
                ),
                PositionedDirectional(
                  top: 8,
                  start: 8,
                  child: _Badge(text: purposeName(p.purpose)),
                ),
                PositionedDirectional(
                  top: 4,
                  end: 4,
                  child: IconButton.filledTonal(
                    tooltip: isFavorite ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
                    icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.red : null),
                    onPressed: () => toggleFavorite(context, ref, p.id, isFavorite),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(formatPrice(p),
                      style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                  const SizedBox(height: 4),
                  Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
                  if (p.location != null) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.place_outlined, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(p.location!.breadcrumbAr,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                      ),
                    ]),
                  ],
                  const SizedBox(height: 8),
                  Wrap(spacing: 16, runSpacing: 4, children: [
                    _Spec(icon: Icons.home_work_outlined, text: propertyTypeNames[p.propertyType] ?? ''),
                    if (p.bedrooms != null) _Spec(icon: Icons.bed_outlined, text: '${p.bedrooms}'),
                    if (p.bathrooms != null) _Spec(icon: Icons.bathtub_outlined, text: '${p.bathrooms}'),
                    if (p.areaSqm != null) _Spec(icon: Icons.square_foot, text: formatArea(p.areaSqm!)),
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
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 12)),
      );
}

class _Spec extends StatelessWidget {
  const _Spec({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 4),
        Text(text),
      ]);
}
