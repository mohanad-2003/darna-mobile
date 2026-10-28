import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/auth_controller.dart';
import 'format.dart';
import 'listings_controller.dart';
import 'models.dart';
import 'property_card.dart';
import 'property_repository.dart';
import 'report_sheet.dart';

final propertyDetailProvider = FutureProvider.autoDispose.family<PropertyDetail, String>(
    (ref, id) => ref.watch(propertyRepositoryProvider).detail(id));

class PropertyDetailScreen extends ConsumerWidget {
  const PropertyDetailScreen({super.key, required this.propertyId});

  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(propertyDetailProvider(propertyId));
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (detail.hasValue)
            PopupMenuButton<String>(
              onSelected: (_) => _reportListing(context, ref, propertyId),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'report', child: Text('الإبلاغ عن الإعلان')),
              ],
            ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(e is ApiException ? e.message : 'تعذر تحميل الإعلان', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              if (e is! ApiException || e.isNetwork)
                FilledButton(
                  onPressed: () => ref.invalidate(propertyDetailProvider(propertyId)),
                  child: const Text('إعادة المحاولة'),
                ),
            ]),
          ),
        ),
        data: (d) => _Body(detail: d),
      ),
      bottomNavigationBar: detail.hasValue ? _ContactBar(detail: detail.requireValue) : null,
    );
  }
}

Future<void> _reportListing(BuildContext context, WidgetRef ref, String id) async {
  if (ref.read(authControllerProvider).value == null) {
    context.push('/login');
    return;
  }
  final input = await showReportSheet(context);
  if (input == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(propertyRepositoryProvider).report(id, input.reason, input.description);
    messenger.showSnackBar(const SnackBar(content: Text('شكراً لك، وصلنا بلاغك وسنراجعه')));
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(
      content: Text(e.code == 'FORBIDDEN' ? 'لا يمكنك الإبلاغ عن إعلانك' : e.message),
    ));
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.detail});

  final PropertyDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final p = detail.card;
    final isFavorite = ref.watch(favoriteOverridesProvider.select((m) => m[p.id])) ?? p.isFavorite;

    return ListView(
      children: [
        _Gallery(media: detail.media),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(formatPrice(p),
                      style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                ),
                IconButton(
                  icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : null),
                  onPressed: () => toggleFavorite(context, ref, p.id, isFavorite),
                ),
              ]),
              Text(p.title, style: theme.textTheme.titleLarge),
              if (p.location != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.place_outlined, size: 18),
                  const SizedBox(width: 4),
                  Expanded(child: Text(p.location!.breadcrumbAr)),
                ]),
              ],
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _Fact(Icons.sell_outlined, purposeName(p.purpose)),
                _Fact(Icons.home_work_outlined, propertyTypeNames[p.propertyType] ?? ''),
                if (p.bedrooms != null) _Fact(Icons.bed_outlined, '${p.bedrooms} غرف'),
                if (p.bathrooms != null) _Fact(Icons.bathtub_outlined, '${p.bathrooms} حمامات'),
                if (p.areaSqm != null) _Fact(Icons.square_foot, formatArea(p.areaSqm!)),
                if (detail.floorNumber != null) _Fact(Icons.stairs_outlined, 'الطابق ${detail.floorNumber}'),
                if (detail.furnished == true) const _Fact(Icons.chair_outlined, 'مفروشة'),
              ]),
              const Divider(height: 32),
              Text('الوصف', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(detail.description, style: theme.textTheme.bodyLarge),
              if (detail.addressText != null) ...[
                const SizedBox(height: 16),
                Text('العنوان', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(detail.addressText!),
              ],
              if (p.office != null) ...[
                const Divider(height: 32),
                Row(children: [
                  const Icon(Icons.business_outlined),
                  const SizedBox(width: 8),
                  Expanded(child: Text(p.office!.name, style: theme.textTheme.titleMedium)),
                  if (p.office!.verified) const Icon(Icons.verified, color: Colors.blue),
                ]),
              ],
              const SizedBox(height: 80),
            ],
          ),
        ),
      ],
    );
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.media});

  final List<MediaItem> media;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.media.isEmpty) {
      return AspectRatio(
        aspectRatio: 16 / 10,
        child: Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Icon(Icons.home_outlined, size: 64),
        ),
      );
    }
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Stack(children: [
        PageView.builder(
          itemCount: widget.media.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) => CachedNetworkImage(
            imageUrl: widget.media[i].url,
            fit: BoxFit.cover,
            placeholder: (_, _) => const Center(child: CircularProgressIndicator()),
            errorWidget: (_, _, _) => const Center(child: Icon(Icons.broken_image_outlined, size: 48)),
          ),
        ),
        if (widget.media.length > 1)
          PositionedDirectional(
            bottom: 8,
            end: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
              child: Text('${_index + 1} / ${widget.media.length}', style: const TextStyle(color: Colors.white)),
            ),
          ),
      ]),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Chip(avatar: Icon(icon, size: 18), label: Text(text));
}

class _ContactBar extends ConsumerWidget {
  const _ContactBar({required this.detail});

  final PropertyDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(children: [
          if (detail.canRevealPhone)
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.phone),
                label: const Text('إظهار الرقم'),
                onPressed: () => _reveal(context, ref),
              ),
            ),
          if (detail.canRevealPhone) const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('أرسل استفساراً'),
              onPressed: () => _inquire(context, ref),
            ),
          ),
        ]),
      ),
    );
  }

  bool _requireLogin(BuildContext context, WidgetRef ref) {
    if (ref.read(authControllerProvider).value != null) return true;
    context.push('/login');
    return false;
  }

  Future<void> _reveal(BuildContext context, WidgetRef ref) async {
    if (!_requireLogin(context, ref)) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final contact = await ref.read(propertyRepositoryProvider).revealContact(detail.card.id);
      if (!context.mounted) return;
      await showDialog<void>(context: context, builder: (_) => _ContactDialog(contact: contact));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _inquire(BuildContext context, WidgetRef ref) async {
    if (!_requireLogin(context, ref)) return;
    final messenger = ScaffoldMessenger.of(context);
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _InquirySheet(),
    );
    if (message == null) return;
    try {
      await ref.read(propertyRepositoryProvider).sendInquiry(detail.card.id, message);
      messenger.showSnackBar(const SnackBar(content: Text('تم إرسال استفسارك')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _ContactDialog extends StatelessWidget {
  const _ContactDialog({required this.contact});

  final ContactInfo contact;

  Future<void> _open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(contact.name ?? 'المعلن'),
      content: Directionality(
        textDirection: TextDirection.ltr,
        child: SelectableText(contact.phone, style: Theme.of(context).textTheme.headlineSmall),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إغلاق')),
        if (contact.whatsappUrl != null)
          TextButton(onPressed: () => _open(contact.whatsappUrl!), child: const Text('واتساب')),
        FilledButton(onPressed: () => _open('tel:${contact.phone}'), child: const Text('اتصال')),
      ],
    );
  }
}

class _InquirySheet extends StatefulWidget {
  const _InquirySheet();

  @override
  State<_InquirySheet> createState() => _InquirySheetState();
}

class _InquirySheetState extends State<_InquirySheet> {
  final _text = TextEditingController(text: 'مرحباً، هل ما زال العقار متاحاً؟');

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: _text,
          maxLines: 4,
          maxLength: 3000,
          decoration: const InputDecoration(labelText: 'رسالتك', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              final text = _text.text.trim();
              if (text.isNotEmpty) Navigator.of(context).pop(text);
            },
            child: const Text('إرسال'),
          ),
        ),
      ]),
    );
  }
}
