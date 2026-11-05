import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/time_ago.dart';
import '../../core/widgets/illustration.dart';
import '../../core/widgets/skeleton.dart';
import 'contact_bar.dart';
import 'format.dart';
import 'gallery_screen.dart';
import 'listings_controller.dart';
import 'models.dart';
import 'property_card.dart';
import 'property_repository.dart';

final propertyDetailProvider = FutureProvider.autoDispose.family<PropertyDetail, String>(
    (ref, id) => ref.watch(propertyRepositoryProvider).detail(id));

const _expandedHeight = 340.0;

class PropertyDetailScreen extends ConsumerWidget {
  const PropertyDetailScreen({super.key, required this.propertyId});

  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(propertyDetailProvider(propertyId));
    return detail.when(
      loading: () => Scaffold(appBar: AppBar(), body: const PropertyDetailSkeleton()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorStateView.from(
          e,
          onRetry: () => ref.invalidate(propertyDetailProvider(propertyId)),
          onBack: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      data: (d) => Scaffold(
        body: _DetailView(detail: d),
        bottomNavigationBar: ContactBar(detail: d),
      ),
    );
  }
}

class _DetailView extends ConsumerStatefulWidget {
  const _DetailView({required this.detail});

  final PropertyDetail detail;

  @override
  ConsumerState<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends ConsumerState<_DetailView> {
  final _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _openGallery() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => GalleryScreen(media: widget.detail.media, initialIndex: _index),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.detail;
    final topPadding = MediaQuery.paddingOf(context).top;
    final collapsedHeight = kToolbarHeight + topPadding;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          automaticallyImplyLeading: false,
          expandedHeight: _expandedHeight,
          toolbarHeight: kToolbarHeight,
          backgroundColor: Theme.of(context).colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          clipBehavior: Clip.hardEdge,
          flexibleSpace: LayoutBuilder(builder: (context, c) {
            // 1 while fully expanded, 0 once collapsed into the toolbar.
            final t = ((c.maxHeight - collapsedHeight) / (_expandedHeight - kToolbarHeight)).clamp(0.0, 1.0);
            return _HeroHeader(
              detail: d,
              t: t,
              pages: _pages,
              index: _index,
              topPadding: topPadding,
              onPageChanged: (i) => setState(() => _index = i),
              onOpenGallery: _openGallery,
            );
          }),
        ),
        SliverToBoxAdapter(child: _Content(detail: d)),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

/// The photo area that shrinks into a regular toolbar while scrolling.
class _HeroHeader extends ConsumerWidget {
  const _HeroHeader({
    required this.detail,
    required this.t,
    required this.pages,
    required this.index,
    required this.topPadding,
    required this.onPageChanged,
    required this.onOpenGallery,
  });

  final PropertyDetail detail;
  final double t;
  final PageController pages;
  final int index;
  final double topPadding;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onOpenGallery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final p = detail.card;
    final media = detail.media;
    final isFavorite = ref.watch(favoriteOverridesProvider.select((m) => m[p.id])) ?? p.isFavorite;
    final expanded = t > 0.5;

    Widget photos;
    if (media.isEmpty) {
      photos = ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Center(child: Icon(Icons.home_outlined, size: 72, color: scheme.outline)),
      );
    } else {
      photos = PageView.builder(
        controller: pages,
        itemCount: media.length,
        onPageChanged: onPageChanged,
        itemBuilder: (_, i) => GestureDetector(
          onTap: expanded ? onOpenGallery : null,
          child: CachedNetworkImage(
            imageUrl: media[i].url,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            placeholder: (_, _) => const Skeleton(height: double.infinity, radius: 0),
            errorWidget: (_, _, _) => ColoredBox(
              color: scheme.surfaceContainerHighest,
              child: Center(child: Icon(Icons.broken_image_outlined, size: 48, color: scheme.outline)),
            ),
          ),
        ),
      );
    }

    return Stack(fit: StackFit.expand, children: [
      photos,
      // Lets the white buttons stay readable on bright photos.
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: 120,
        child: IgnorePointer(
          child: Opacity(
            opacity: t,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x99000000), Colors.transparent],
                ),
              ),
            ),
          ),
        ),
      ),
      // Fades the photos out as the header collapses into a plain toolbar.
      Positioned.fill(
        child: IgnorePointer(child: ColoredBox(color: scheme.surface.withValues(alpha: 1 - t))),
      ),
      // The content sheet "rises" over the photo.
      Positioned(
        left: 0,
        right: 0,
        bottom: -1,
        height: 26,
        child: IgnorePointer(
          child: Opacity(
            opacity: t,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
            ),
          ),
        ),
      ),
      if (media.length > 1) ...[
        Positioned(
          bottom: 36,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Opacity(
              opacity: t,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < media.length && i < 12; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == index ? 20 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == index ? Colors.white : Colors.white54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ],
      if (media.isNotEmpty)
        PositionedDirectional(
          end: 16,
          bottom: 40,
          child: IgnorePointer(
            child: Opacity(
              opacity: t,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(14)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.photo_library_outlined, size: 14, color: Colors.white),
                  const SizedBox(width: 5),
                  Text('${index + 1} / ${media.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                ]),
              ),
            ),
          ),
        ),
      // Toolbar row: back, title (once collapsed), favorite, menu.
      Positioned(
        top: topPadding,
        left: 8,
        right: 8,
        height: kToolbarHeight,
        child: Row(children: [
          _CircleButton(
            t: t,
            tooltip: 'رجوع',
            icon: Icons.arrow_back,
            onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Opacity(
                opacity: (1 - t * 1.6).clamp(0.0, 1.0),
                child: Text(
                  p.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          _CircleButton(
            t: t,
            tooltip: isFavorite ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
            icon: isFavorite ? Icons.favorite : Icons.favorite_border,
            iconColor: isFavorite ? Colors.redAccent : null,
            onPressed: () => toggleFavorite(context, ref, p.id, isFavorite),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            tooltip: 'المزيد',
            onSelected: (_) => reportListing(context, ref, p.id),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'report', child: Text('الإبلاغ عن الإعلان')),
            ],
            child: _CircleVisual(t: t, icon: Icons.more_vert),
          ),
        ]),
      ),
    ]);
  }
}

/// Translucent dark circle over the photo that melts into a plain icon button once collapsed.
class _CircleVisual extends StatelessWidget {
  const _CircleVisual({required this.t, required this.icon, this.iconColor});

  final double t;
  final IconData icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.38 * t),
      ),
      child: Icon(icon, size: 22, color: iconColor ?? Color.lerp(scheme.onSurface, Colors.white, t)),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.t,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.iconColor,
  });

  final double t;
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkResponse(
          onTap: onPressed,
          radius: 24,
          child: _CircleVisual(t: t, icon: icon, iconColor: iconColor),
        ),
      );
}

class _Content extends StatelessWidget {
  const _Content({required this.detail});

  final PropertyDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = detail.card;
    final published = p.publishedAt;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          _Pill(text: purposeName(p.purpose), color: scheme.primary, textColor: scheme.onPrimary),
          _Pill(
            text: propertyTypeNames[p.propertyType] ?? '',
            color: scheme.secondaryContainer,
            textColor: scheme.onSecondaryContainer,
          ),
          if (p.office?.verified == true)
            _Pill(
              icon: Icons.verified,
              text: 'مكتب موثّق',
              color: scheme.primaryContainer,
              textColor: scheme.onPrimaryContainer,
            ),
          if (published != null)
            Text(
              'نُشر ${timeAgoAr(published)}',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
        ]),
        const SizedBox(height: 14),
        Text(
          formatPrice(p),
          style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: scheme.primary),
        ),
        const SizedBox(height: 6),
        Text(p.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, height: 1.35)),
        if (p.location != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.place_outlined, size: 18, color: scheme.primary),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                p.location!.breadcrumbAr,
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ]),
        ],
        _QuickFacts(detail: detail),
        _Section(
          title: 'الوصف',
          child: _ExpandableText(detail.description),
        ),
        _Section(title: 'تفاصيل العقار', child: _DetailsCard(detail: detail)),
        if (detail.hasLocation || p.location != null || detail.addressText != null)
          _Section(title: 'الموقع', child: _LocationCard(detail: detail)),
        if (p.office != null) _Section(title: 'المعلن', child: _OfficeCard(office: p.office!)),
        const SizedBox(height: 12),
        Center(
          child: Consumer(
            builder: (context, ref, _) => TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
              onPressed: () => reportListing(context, ref, p.id),
              icon: const Icon(Icons.flag_outlined, size: 18),
              label: const Text('الإبلاغ عن الإعلان'),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color, required this.textColor, this.icon});

  final String text;
  final Color color;
  final Color textColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 14, color: textColor), const SizedBox(width: 4)],
          Text(text, style: TextStyle(color: textColor, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 26),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          child,
        ]),
      );
}

BoxDecoration _cardDecoration(ColorScheme scheme) => BoxDecoration(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
    );

class _QuickFacts extends StatelessWidget {
  const _QuickFacts({required this.detail});

  final PropertyDetail detail;

  @override
  Widget build(BuildContext context) {
    final p = detail.card;
    final facts = <_FactData>[
      if (p.bedrooms != null) _FactData(Icons.bed_outlined, '${p.bedrooms}', 'غرف نوم'),
      if (p.bathrooms != null) _FactData(Icons.bathtub_outlined, '${p.bathrooms}', 'حمامات'),
      if (p.areaSqm != null) _FactData(Icons.square_foot, formatArea(p.areaSqm!), 'المساحة'),
      if (detail.floorNumber != null) _FactData(Icons.stairs_outlined, '${detail.floorNumber}', 'الطابق'),
      if (detail.furnished != null)
        _FactData(Icons.chair_outlined, detail.furnished! ? 'مفروشة' : 'غير مفروشة', 'الأثاث'),
    ];
    if (facts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: LayoutBuilder(builder: (context, c) {
        const gap = 10.0;
        final width = (c.maxWidth - gap * 2) / 3;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final f in facts) SizedBox(width: width, child: _FactTile(f)),
        ]);
      }),
    );
  }
}

class _FactData {
  const _FactData(this.icon, this.value, this.label);

  final IconData icon;
  final String value;
  final String label;
}

class _FactTile extends StatelessWidget {
  const _FactTile(this.data);

  final _FactData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: _cardDecoration(scheme),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
          child: Icon(data.icon, size: 19, color: scheme.onPrimaryContainer),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(data.value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 2),
        Text(data.label, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      ]),
    );
  }
}

/// Description clamped to a few lines, with "show more" only when it actually overflows.
class _ExpandableText extends StatefulWidget {
  const _ExpandableText(this.text);

  final String text;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  static const _collapsedLines = 5;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyLarge?.copyWith(height: 1.7);
    return LayoutBuilder(builder: (context, c) {
      final painter = TextPainter(
        text: TextSpan(text: widget.text, style: style),
        maxLines: _collapsedLines,
        textDirection: Directionality.of(context),
      )..layout(maxWidth: c.maxWidth);
      final overflows = painter.didExceedMaxLines;
      painter.dispose();

      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: Text(
            widget.text,
            style: style,
            maxLines: _expanded ? null : _collapsedLines,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
        ),
        if (overflows)
          TextButton(
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(_expanded ? 'عرض أقل' : 'عرض المزيد'),
          ),
      ]);
    });
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.detail});

  final PropertyDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = detail.card;
    final rows = <(String, String)>[
      ('نوع العقار', propertyTypeNames[p.propertyType] ?? ''),
      ('الغرض', purposeName(p.purpose)),
      if (p.rentPeriod != null) ('فترة الإيجار', rentPeriodName(p.rentPeriod!)),
      if (p.areaSqm != null) ('المساحة', formatArea(p.areaSqm!)),
      if (detail.floorNumber != null) ('الطابق', '${detail.floorNumber}'),
    ];
    return Container(
      decoration: _cardDecoration(scheme),
      child: Column(children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.6)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(children: [
              Text(rows[i].$1, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
              const Spacer(),
              Text(rows[i].$2, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.detail});

  final PropertyDetail detail;

  Future<void> _openMap() {
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${detail.latitude},${detail.longitude}');
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = detail.card;
    final lines = <String>[
      if (detail.addressText != null && detail.addressText!.trim().isNotEmpty) detail.addressText!,
      if (p.location != null) p.location!.breadcrumbAr,
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(scheme),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
            child: Icon(Icons.place, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var i = 0; i < lines.length; i++)
                Text(
                  lines[i],
                  style: i == 0
                      ? theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)
                      : theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              if (detail.hasLocation && detail.isApproximateLocation) ...[
                const SizedBox(height: 6),
                Text(
                  'الموقع تقريبي، يُحدَّد العنوان الدقيق مع المعلن.',
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
                ),
              ],
            ]),
          ),
        ]),
        if (detail.hasLocation) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openMap,
              icon: const Icon(Icons.map_outlined, size: 20),
              label: const Text('عرض على الخريطة'),
            ),
          ),
        ],
      ]),
    );
  }
}

class _OfficeCard extends StatelessWidget {
  const _OfficeCard({required this.office});

  final OfficeSummary office;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(scheme),
      child: Row(children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: scheme.primaryContainer,
          child: Icon(Icons.business_outlined, color: scheme.onPrimaryContainer),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(office.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(
              office.verified ? 'مكتب عقارات موثّق' : 'مكتب عقارات',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ]),
        ),
        if (office.verified) Icon(Icons.verified, color: scheme.primary),
      ]),
    );
  }
}
