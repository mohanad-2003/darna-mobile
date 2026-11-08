import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import 'listing_local_store.dart';

/// After Android ended the app while the photo picker was open, the app starts from its home
/// page and the user would never find the photos they just chose. This takes them back to the
/// listing they were adding photos to; that screen then asks the picker for the lost photos.
///
/// It looks once, when the app starts, and only acts for the account that opened the picker.
class PendingPickGate extends ConsumerStatefulWidget {
  const PendingPickGate({super.key, required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<PendingPickGate> createState() => _PendingPickGateState();
}

class _PendingPickGateState extends ConsumerState<PendingPickGate> {
  @override
  void initState() {
    super.initState();
    unawaited(_resume());
  }

  Future<void> _resume() async {
    if (!photoPickerCanLoseData) return;
    final store = ref.read(listingLocalStoreProvider);
    final pending = await store.loadPendingPick();
    if (pending == null) return;
    if (pending.isStale()) {
      await store.clearPendingPick();
      return;
    }

    final Me? me;
    try {
      me = await ref.read(authControllerProvider.future);
    } catch (_) {
      return;
    }
    if (!mounted) return;
    if (me?.id != pending.accountId) {
      await store.clearPendingPick(); // someone else is signed in now
      return;
    }
    // The listing screen consumes the note (and clears it) when it opens.
    unawaited(widget.router.push<void>('/listing/${pending.propertyId}'));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
