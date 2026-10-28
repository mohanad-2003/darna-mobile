import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_controller.dart';
import '../listings/listing_models.dart';

class ReviewEntry {
  ReviewEntry({required this.decision, this.reason, required this.createdAt});

  final String decision;
  final String? reason;
  final DateTime createdAt;

  factory ReviewEntry.fromJson(Json j) => ReviewEntry(
        decision: j['decision'] as String,
        reason: j['reason'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

/// A listing as a moderator sees it: all fields, the review history, open reports.
class ModerationView {
  ModerationView({required this.listing, required this.reviews, required this.openReports});

  final OwnerListing listing;
  final List<ReviewEntry> reviews;
  final int openReports;
}

const decisionNames = {
  'APPROVED': 'موافقة',
  'REJECTED': 'رفض',
  'NEEDS_CHANGES': 'طلب تعديلات',
  'SUSPENDED': 'إيقاف',
  'REINSTATED': 'إعادة نشر',
};

final adminRepositoryProvider =
    Provider<AdminRepository>((ref) => AdminRepository(ref.watch(apiClientProvider)));

final pendingQueueProvider = FutureProvider.autoDispose<List<OwnerListing>>((ref) {
  ref.watch(authControllerProvider.select((a) => a.value?.id));
  return ref.watch(adminRepositoryProvider).pending();
});

final moderationViewProvider = FutureProvider.autoDispose.family<ModerationView, String>(
    (ref, id) => ref.watch(adminRepositoryProvider).view(id));

class AdminRepository {
  AdminRepository(this._api);

  final ApiClient _api;

  Future<List<OwnerListing>> pending() async {
    final res = await _api.get('/admin/properties/pending', query: {'limit': 50});
    return (res['data'] as List).map((e) => OwnerListing.fromJson(e as Json)).toList();
  }

  Future<ModerationView> view(String id) async {
    final data = (await _api.get('/admin/properties/$id'))['data'] as Json;
    return ModerationView(
      listing: OwnerListing.fromJson(data),
      reviews: (data['reviews'] as List).map((e) => ReviewEntry.fromJson(e as Json)).toList(),
      openReports: data['openReports'] as int,
    );
  }

  /// [expectedStatus] makes the server refuse the decision if another moderator
  /// already acted on the listing.
  Future<void> review(String id, {required String decision, required String expectedStatus, String? reason}) =>
      _api.post('/admin/properties/$id/review', body: {
        'decision': decision,
        'expectedStatus': expectedStatus,
        'reason': ?reason,
      });
}
