import 'dart:convert';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Only Android can end the app while the system photo picker is open and keep the result for
/// later; the other platforms never lose it.
bool get photoPickerCanLoseData => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// A draft older than this is thrown away instead of offered.
const draftMaxAge = Duration(days: 30);

/// The "a picker is open" marker only means something for a short while after it was written.
const pendingPickMaxAge = Duration(minutes: 15);

/// "This account opened the system photo picker for this listing." Written just before the
/// picker opens and removed when it returns. If it is still there on the next launch, Android
/// ended the app while the picker was open and the chosen photos may be waiting to be retrieved.
class PendingPick {
  PendingPick({required this.accountId, required this.propertyId, required this.at});

  final String accountId;
  final String propertyId;
  final DateTime at;

  bool isStale([DateTime? now]) => (now ?? DateTime.now()).difference(at) > pendingPickMaxAge;

  Map<String, Object?> toJson() => {'a': accountId, 'p': propertyId, 't': at.toIso8601String()};

  static PendingPick? fromJson(Object? json) {
    if (json is! Map) return null;
    final at = DateTime.tryParse('${json['t']}');
    final account = json['a'];
    final property = json['p'];
    if (at == null || account is! String || property is! String) return null;
    return PendingPick(accountId: account, propertyId: property, at: at);
  }
}

/// What the listing screens keep on the device. It is all best effort: when storage fails, the
/// screens carry on as if nothing was stored.
///
/// Never put session tokens or photo content here: a draft is only the text fields of the form,
/// and the pending pick is two ids and a time.
abstract class ListingLocalStore {
  /// The saved new-listing draft of [accountId], or null (none, too old, or unreadable).
  Future<Map<String, Object?>?> loadDraft(String accountId);
  Future<void> saveDraft(String accountId, Map<String, Object?> fields);
  Future<void> clearDraft(String accountId);

  Future<PendingPick?> loadPendingPick();
  Future<void> savePendingPick(PendingPick pick);
  Future<void> clearPendingPick();
}

/// Drafts hold a phone number and the owner's words, so they go in the platform keystore
/// (like the session) rather than in plain preferences. Each account has its own entry.
class DeviceListingLocalStore implements ListingLocalStore {
  DeviceListingLocalStore([FlutterSecureStorage? secure]) : _secure = secure ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secure;

  static const _draftVersion = 1;
  static String _draftKey(String accountId) => 'listing_draft_v$_draftVersion.$accountId';
  static const _pickKey = 'pending_photo_pick';

  @override
  Future<Map<String, Object?>?> loadDraft(String accountId) async {
    try {
      final raw = await _secure.read(key: _draftKey(accountId));
      if (raw == null) return null;
      final json = jsonDecode(raw);
      final savedAt = json is Map ? DateTime.tryParse('${json['savedAt']}') : null;
      final fields = json is Map ? json['fields'] : null;
      if (savedAt == null || fields is! Map || DateTime.now().difference(savedAt) > draftMaxAge) {
        await clearDraft(accountId);
        return null;
      }
      return fields.cast<String, Object?>();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveDraft(String accountId, Map<String, Object?> fields) async {
    try {
      await _secure.write(
        key: _draftKey(accountId),
        value: jsonEncode({'savedAt': DateTime.now().toIso8601String(), 'fields': fields}),
      );
    } catch (_) {}
  }

  @override
  Future<void> clearDraft(String accountId) async {
    try {
      await _secure.delete(key: _draftKey(accountId));
    } catch (_) {}
  }

  @override
  Future<PendingPick?> loadPendingPick() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_pickKey);
      return raw == null ? null : PendingPick.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> savePendingPick(PendingPick pick) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_pickKey, jsonEncode(pick.toJson()));
    } catch (_) {}
  }

  @override
  Future<void> clearPendingPick() async {
    try {
      await (await SharedPreferences.getInstance()).remove(_pickKey);
    } catch (_) {}
  }
}

final listingLocalStoreProvider = Provider<ListingLocalStore>((ref) => DeviceListingLocalStore());
