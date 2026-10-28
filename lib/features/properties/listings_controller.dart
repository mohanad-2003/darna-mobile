import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/auth_controller.dart';
import 'models.dart';
import 'property_repository.dart';

class ListingsState {
  const ListingsState({
    this.items = const [],
    this.cursor,
    this.hasMore = true,
    this.loading = false,
    this.error,
    this.filters = const SearchFilters(),
  });

  final List<PropertyCard> items;
  final String? cursor;
  final bool hasMore;
  final bool loading;
  final String? error;
  final SearchFilters filters;

  ListingsState copyWith({
    List<PropertyCard>? items,
    String? cursor,
    bool? hasMore,
    bool? loading,
    String? error,
    bool clearError = false,
    SearchFilters? filters,
  }) =>
      ListingsState(
        items: items ?? this.items,
        cursor: cursor ?? this.cursor,
        hasMore: hasMore ?? this.hasMore,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        filters: filters ?? this.filters,
      );
}

final listingsControllerProvider =
    NotifierProvider<ListingsController, ListingsState>(ListingsController.new);

/// Search results with infinite scroll. Rebuilds (and reloads) when the user signs in
/// or out, because the heart state in each card depends on who is asking.
class ListingsController extends Notifier<ListingsState> {
  int _generation = 0;

  @override
  ListingsState build() {
    ref.watch(authControllerProvider.select((a) => a.value?.id));
    Future.microtask(loadFirst);
    return const ListingsState(loading: true);
  }

  Future<void> loadFirst() => _load(reset: true);

  Future<void> loadMore() async {
    if (state.loading || !state.hasMore) return;
    await _load(reset: false);
  }

  Future<void> setFilters(SearchFilters filters) {
    state = ListingsState(filters: filters, loading: true);
    return _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    // A newer request (filter change, pull to refresh) makes this one's answer stale.
    final generation = ++_generation;
    final base = reset ? state.copyWith(items: [], hasMore: true, loading: true, clearError: true) : state.copyWith(loading: true, clearError: true);
    state = reset ? ListingsState(filters: state.filters, loading: true) : base;
    try {
      final page = await ref
          .read(propertyRepositoryProvider)
          .search(state.filters, cursor: reset ? null : base.cursor);
      if (generation != _generation) return;
      state = state.copyWith(
        items: reset ? page.items : [...base.items, ...page.items],
        cursor: page.nextCursor,
        hasMore: page.hasMore,
        loading: false,
      );
    } on ApiException catch (e) {
      if (generation != _generation) return;
      state = state.copyWith(loading: false, error: e.message);
    }
  }
}

/// Heart toggles made in this session, by listing id. They override the value that
/// came with the card so every screen shows the same state at once.
final favoriteOverridesProvider =
    NotifierProvider<FavoriteOverrides, Map<String, bool>>(FavoriteOverrides.new);

class FavoriteOverrides extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() {
    // Overrides belong to one account.
    ref.watch(authControllerProvider.select((a) => a.value?.id));
    return {};
  }

  /// Returns an error message, or null on success.
  Future<String?> toggle(String id, {required bool current}) async {
    final repo = ref.read(propertyRepositoryProvider);
    state = {...state, id: !current};
    try {
      if (current) {
        await repo.removeFavorite(id);
      } else {
        await repo.addFavorite(id);
      }
      return null;
    } on ApiException catch (e) {
      state = {...state, id: current};
      return e.message;
    }
  }
}
