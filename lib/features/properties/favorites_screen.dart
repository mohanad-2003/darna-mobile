import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/auth_controller.dart';
import '../auth/login_prompt.dart';
import 'listings_controller.dart';
import 'models.dart';
import 'property_card.dart';
import 'property_repository.dart';

// Reloaded whenever the signed-in user changes.
final _favoritesProvider = FutureProvider.autoDispose<PagedResult<PropertyCard>>((ref) {
  ref.watch(authControllerProvider.select((a) => a.value?.id));
  return ref.watch(propertyRepositoryProvider).favorites();
});

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authControllerProvider.select((a) => a.value != null));
    if (!signedIn) {
      return const Scaffold(
        body: LoginPrompt(message: 'سجّل الدخول لحفظ الإعلانات المفضلة والعودة إليها لاحقاً'),
      );
    }
    final favorites = ref.watch(_favoritesProvider);
    // A heart removed here should disappear from the list without a reload.
    final overrides = ref.watch(favoriteOverridesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('المفضلة')),
      body: favorites.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(e is ApiException ? e.message : 'تعذر التحميل'),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => ref.invalidate(_favoritesProvider), child: const Text('إعادة المحاولة')),
          ]),
        ),
        data: (page) {
          final items = page.items.where((p) => overrides[p.id] != false).toList();
          if (items.isEmpty) {
            return const Center(child: Text('لا توجد إعلانات مفضلة بعد'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(_favoritesProvider.future),
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) => PropertyCardTile(property: items[i]),
            ),
          );
        },
      ),
    );
  }
}
