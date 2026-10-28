import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../properties/models.dart';
import '../properties/property_repository.dart';

class PickedLocation {
  PickedLocation(this.id, this.name);

  final String id;
  final String name;
}

/// Two-level picker: governorate, then city. Returns the chosen place with its full name.
Future<PickedLocation?> pickLocation(BuildContext context) => showModalBottomSheet<PickedLocation>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _LocationPickerSheet(),
    );

class _LocationPickerSheet extends ConsumerStatefulWidget {
  const _LocationPickerSheet();

  @override
  ConsumerState<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends ConsumerState<_LocationPickerSheet> {
  // The path of places chosen so far, root first.
  final List<GeoLocation> _path = [];
  late Future<List<GeoLocation>> _items = _load();

  Future<List<GeoLocation>> _load() =>
      ref.read(propertyRepositoryProvider).locations(parentId: _path.isEmpty ? null : _path.last.id);

  String get _pathName => _path.map((l) => l.nameAr).join(' › ');

  void _open(GeoLocation l) {
    setState(() {
      _path.add(l);
      _items = _load();
    });
  }

  void _up() {
    setState(() {
      _path.removeLast();
      _items = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_path.isNotEmpty)
            ListTile(
              leading: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _up),
              title: Text(_pathName),
              trailing: FilledButton(
                onPressed: () => Navigator.of(context).pop(PickedLocation(_path.last.id, _pathName)),
                child: const Text('اختيار هذا'),
              ),
            )
          else
            const ListTile(title: Text('اختر المحافظة')),
          const Divider(height: 1),
          Flexible(
            child: FutureBuilder<List<GeoLocation>>(
              future: _items,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
                }
                if (snap.hasError) {
                  return SizedBox(
                    height: 160,
                    child: Center(
                      child: TextButton(
                        onPressed: () => setState(() => _items = _load()),
                        child: const Text('تعذر التحميل، اضغط للمحاولة'),
                      ),
                    ),
                  );
                }
                final items = snap.data!;
                if (items.isEmpty) {
                  return const SizedBox(height: 120, child: Center(child: Text('لا توجد مناطق أدق')));
                }
                return ListView(
                  shrinkWrap: true,
                  children: [
                    for (final l in items)
                      ListTile(
                        title: Text(l.nameAr),
                        trailing: l.hasChildren ? const Icon(Icons.chevron_left) : null,
                        onTap: () {
                          if (l.hasChildren) {
                            _open(l);
                          } else {
                            final name = [..._path.map((p) => p.nameAr), l.nameAr].join(' › ');
                            Navigator.of(context).pop(PickedLocation(l.id, name));
                          }
                        },
                      ),
                  ],
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
