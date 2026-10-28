import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/ensure_name.dart';
import '../notifications/notifications_repository.dart';

import 'filters_sheet.dart';
import 'listings_controller.dart';
import 'models.dart';
import 'property_card.dart';
import 'property_repository.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        ref.read(listingsControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(listingsControllerProvider);
    final controller = ref.read(listingsControllerProvider.notifier);
    final filters = state.filters;

    return Scaffold(
      appBar: AppBar(
        title: const Text('دارنا'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              if (await ensureSignedInWithName(context, ref) && context.mounted) {
                context.push('/listing/new');
              }
            },
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('أضف إعلاناً'),
          ),
          IconButton(
            tooltip: 'الإشعارات',
            icon: Badge(
              isLabelVisible: (ref.watch(unreadCountProvider).value ?? 0) > 0,
              label: Text('${ref.watch(unreadCountProvider).value ?? 0}'),
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () async {
              await context.push('/notifications');
              ref.invalidate(unreadCountProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _chip('الكل', filters.purpose == null,
                    () => controller.setFilters(filters.copyWith(clearPurpose: true))),
                _chip('للبيع', filters.purpose == 'SALE',
                    () => controller.setFilters(filters.copyWith(purpose: 'SALE'))),
                _chip('للإيجار', filters.purpose == 'RENT',
                    () => controller.setFilters(filters.copyWith(purpose: 'RENT'))),
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  child: ActionChip(
                    avatar: const Icon(Icons.place_outlined, size: 18),
                    label: Text(filters.locationName ?? 'كل المحافظات'),
                    onPressed: () => _pickLocation(context),
                  ),
                ),
                if (filters.locationId != null)
                  IconButton(
                    tooltip: 'إلغاء الموقع',
                    icon: const Icon(Icons.close),
                    onPressed: () => controller.setFilters(filters.copyWith(clearLocation: true)),
                  ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  child: ActionChip(
                    avatar: Badge(
                      isLabelVisible: filters.activeCount > 0,
                      label: Text('${filters.activeCount}'),
                      child: const Icon(Icons.tune, size: 18),
                    ),
                    label: const Text('تصفية'),
                    onPressed: () async {
                      final next = await showFiltersSheet(context, filters);
                      if (next != null) controller.setFilters(next);
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _body(state, controller)),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
      );

  Widget _body(ListingsState state, ListingsController controller) {
    if (state.items.isEmpty && state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.items.isEmpty && state.error != null) {
      return _Message(
        icon: Icons.wifi_off,
        text: state.error!,
        action: FilledButton(onPressed: controller.loadFirst, child: const Text('إعادة المحاولة')),
      );
    }
    if (state.items.isEmpty) {
      return const _Message(icon: Icons.search_off, text: 'لا توجد إعلانات مطابقة');
    }
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(unreadCountProvider);
        await controller.loadFirst();
      },
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.items.length + 1,
        itemBuilder: (context, i) {
          if (i < state.items.length) return PropertyCardTile(property: state.items[i]);
          if (state.loading) {
            return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
          }
          if (state.error != null) {
            return TextButton(onPressed: controller.loadMore, child: const Text('تعذر التحميل، اضغط للمحاولة'));
          }
          return const SizedBox(height: 24);
        },
      ),
    );
  }

  Future<void> _pickLocation(BuildContext context) async {
    final controller = ref.read(listingsControllerProvider.notifier);
    final current = ref.read(listingsControllerProvider).filters;
    final picked = await showModalBottomSheet<GeoLocation>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _LocationSheet(),
    );
    if (picked != null) {
      controller.setFilters(current.copyWith(locationId: picked.id, locationName: picked.nameAr));
    }
  }
}

final _governoratesProvider = FutureProvider.autoDispose<List<GeoLocation>>(
    (ref) => ref.watch(propertyRepositoryProvider).locations());

class _LocationSheet extends ConsumerWidget {
  const _LocationSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locations = ref.watch(_governoratesProvider);
    return SafeArea(
      child: locations.when(
        loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => SizedBox(
          height: 200,
          child: Center(
            child: TextButton(
              onPressed: () => ref.invalidate(_governoratesProvider),
              child: const Text('تعذر تحميل المحافظات، اضغط للمحاولة'),
            ),
          ),
        ),
        data: (list) => ListView(
          shrinkWrap: true,
          children: [
            for (final l in list)
              ListTile(title: Text(l.nameAr), onTap: () => Navigator.of(context).pop(l)),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ]),
        ),
      );
}
