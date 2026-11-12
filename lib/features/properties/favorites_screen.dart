import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/illustration.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/empty_state.dart';
import '../../core/auth/auth_controller.dart';
import '../auth/login_prompt.dart';
import 'listings_controller.dart';
import 'models.dart';
import 'property_card.dart';
import 'property_repository.dart';

// Reloaded whenever the signed-in user changes.
final _favoritesProvider =
    FutureProvider.autoDispose<PagedResult<PropertyCard>>((ref) {
      ref.watch(authControllerProvider.select((a) => a.value?.id));
      return ref.watch(propertyRepositoryProvider).favorites();
    });

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(
      authControllerProvider.select((a) => a.value != null),
    );
    if (!signedIn) {
      return const Scaffold(
        body: LoginPrompt(
          message: 'سجّل الدخول لحفظ الإعلانات المفضلة والعودة إليها لاحقاً',
        ),
      );
    }
    final favorites = ref.watch(_favoritesProvider);
    // A heart removed here should disappear from the list without a reload.
    final overrides = ref.watch(favoriteOverridesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('المفضلة')),
      body: favorites.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorStateView.from(e, onRetry: () => ref.invalidate(_favoritesProvider)),
        data: (page) {
          final items = page.items
              .where((p) => overrides[p.id] != false)
              .toList();
          if (items.isEmpty) {
            return EmptyStateView(
              illustration: EmptyStateIllustration.favorites,
              title: 'عقاراتك المفضلة تنتظرك',
              description: 'اضغط على القلب بجانب أي عقار يعجبك، وستجده هنا لتعود إليه بسهولة.',
              actionLabel: 'تصفح العقارات',
              onAction: () => context.go('/'),
              onRefresh: () async {
                ref.invalidate(_favoritesProvider);
                await ref.read(_favoritesProvider.future);
              },
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(_favoritesProvider.future),
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) => PropertyCardTile(property: items[i], heroScope: 'favorites'),
            ),
          );
        },
      ),
    );
  }
}
