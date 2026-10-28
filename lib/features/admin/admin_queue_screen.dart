import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../listings/listing_models.dart';
import '../properties/format.dart';
import 'admin_repository.dart';

class AdminQueueScreen extends ConsumerWidget {
  const AdminQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(pendingQueueProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('مراجعة الإعلانات')),
      body: queue.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(e is ApiException ? e.message : 'تعذر التحميل'),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => ref.invalidate(pendingQueueProvider), child: const Text('إعادة المحاولة')),
          ]),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('لا توجد إعلانات بانتظار المراجعة'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(pendingQueueProvider.future),
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) => _QueueTile(listing: items[i]),
            ),
          );
        },
      ),
    );
  }
}

class _QueueTile extends ConsumerWidget {
  const _QueueTile({required this.listing});

  final OwnerListing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cover = listing.media.where((m) => m.isCover).firstOrNull ?? listing.media.firstOrNull;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await context.push('/admin/review/${listing.id}');
          ref.invalidate(pendingQueueProvider);
        },
        child: Row(children: [
          SizedBox(
            width: 96,
            height: 96,
            child: cover == null
                ? const ColoredBox(color: Colors.black12, child: Icon(Icons.home_outlined))
                : CachedNetworkImage(imageUrl: cover.thumbnailUrl, fit: BoxFit.cover),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(listing.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(
                  '${purposeName(listing.purpose)} · ${propertyTypeNames[listing.propertyType] ?? ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(listing.locationName, style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ),
          const Icon(Icons.chevron_left),
          const SizedBox(width: 8),
        ]),
      ),
    );
  }
}
