import 'package:darna/features/listings/listing_local_store.dart';

/// The listing screens' local storage, in memory.
class MemoryListingStore implements ListingLocalStore {
  final drafts = <String, Map<String, Object?>>{};
  PendingPick? pick;

  @override
  Future<Map<String, Object?>?> loadDraft(String accountId) async => drafts[accountId];

  @override
  Future<void> saveDraft(String accountId, Map<String, Object?> fields) async => drafts[accountId] = Map.of(fields);

  @override
  Future<void> clearDraft(String accountId) async => drafts.remove(accountId);

  @override
  Future<PendingPick?> loadPendingPick() async => pick;

  @override
  Future<void> savePendingPick(PendingPick value) async => pick = value;

  @override
  Future<void> clearPendingPick() async => pick = null;
}
