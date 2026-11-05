import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/illustration.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/empty_state.dart';
import '../auth/ensure_name.dart';
import 'listing_models.dart';
import 'listing_repository.dart';

class MyListingsScreen extends ConsumerWidget {
  const MyListingsScreen({super.key});

  Future<void> _createListing(BuildContext context, WidgetRef ref) async {
    if (await ensureSignedInWithName(context, ref) && context.mounted) {
      await context.push('/listing/new');
      ref.invalidate(myListingsProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(myListingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('إعلاناتي')),
      floatingActionButton: listings.value?.isEmpty == true
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _createListing(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('إعلان جديد'),
            ),
      body: listings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorStateView.from(e, onRetry: () => ref.invalidate(myListingsProvider)),
        data: (items) {
          if (items.isEmpty) {
            return EmptyStateView(
              illustration: EmptyStateIllustration.listings,
              title: 'إعلانك الأول يبدأ من هنا',
              description: 'لم تنشر أي إعلان بعد. أضف صور عقارك وتفاصيله ليصل إلى المهتمين.',
              actionLabel: 'أضف إعلانك الأول',
              onAction: () => _createListing(context, ref),
              onRefresh: () async {
                ref.invalidate(myListingsProvider);
                await ref.read(myListingsProvider.future);
              },
            );
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
    final cover =
        listing.media.where((m) => m.isCover).firstOrNull ??
        listing.media.firstOrNull;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await context.push('/listing/${listing.id}');
          ref.invalidate(myListingsProvider);
        },
        child: Row(
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: cover == null
                  ? ColoredBox(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.home_outlined),
                    )
                  : CachedNetworkImage(
                      imageUrl: cover.thumbnailUrl,
                      fit: BoxFit.cover,
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: info.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        info.label,
                        style: TextStyle(color: info.color, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Icon(Icons.chevron_left),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
