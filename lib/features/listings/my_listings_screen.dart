import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../auth/ensure_name.dart';
import 'listing_models.dart';
import 'listing_repository.dart';

class MyListingsScreen extends ConsumerWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(myListingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('إعلاناتي')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (await ensureSignedInWithName(context, ref) && context.mounted) {
            await context.push('/listing/new');
            ref.invalidate(myListingsProvider);
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('إعلان جديد'),
      ),
      body: listings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(e is ApiException ? e.message : 'تعذر التحميل'),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => ref.invalidate(myListingsProvider), child: const Text('إعادة المحاولة')),
          ]),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('لم تنشر أي إعلان بعد. اضغط "إعلان جديد" لتبدأ.', textAlign: TextAlign.center),
            ));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(myListingsProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: items.length,
              itemBuilder: (_, i) => _ListingTile(listing: items[i]),
            ),
          );
        },
      ),
    );
  }
}

class _ListingTile extends ConsumerWidget {
  const _ListingTile({required this.listing});

  final OwnerListing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = statusInfo(listing.status);
    final cover = listing.media.where((m) => m.isCover).firstOrNull ?? listing.media.firstOrNull;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await context.push('/listing/${listing.id}');
          ref.invalidate(myListingsProvider);
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
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: info.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(info.label, style: TextStyle(color: info.color, fontSize: 12)),
                ),
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
