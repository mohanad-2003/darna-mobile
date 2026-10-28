import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_controller.dart';

class InquiryItem {
  InquiryItem({
    required this.id,
    required this.propertyId,
    required this.propertyTitle,
    required this.message,
    required this.contactPreference,
    this.senderName,
    this.senderPhone,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String propertyId;
  final String propertyTitle;
  final String message;
  final String contactPreference;
  final String? senderName;
  final String? senderPhone;
  final String status;
  final DateTime createdAt;

  factory InquiryItem.fromJson(Json j) => InquiryItem(
        id: j['id'] as String,
        propertyId: j['propertyId'] as String,
        propertyTitle: j['propertyTitle'] as String,
        message: j['message'] as String,
        contactPreference: j['contactPreference'] as String,
        senderName: j['senderName'] as String?,
        senderPhone: j['senderPhone'] as String?,
        status: j['status'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

const inquiryStatusNames = {
  'NEW': 'جديد',
  'READ': 'مقروء',
  'RESPONDED': 'تم الرد',
  'CLOSED': 'مغلق',
  'SPAM': 'مزعج',
};

const contactPreferenceNames = {
  'IN_APP': 'داخل التطبيق',
  'PHONE': 'اتصال هاتفي',
  'WHATSAPP': 'واتساب',
};

final inquiriesRepositoryProvider =
    Provider<InquiriesRepository>((ref) => InquiriesRepository(ref.watch(apiClientProvider)));

final receivedInquiriesProvider = FutureProvider.autoDispose<List<InquiryItem>>((ref) {
  ref.watch(authControllerProvider.select((a) => a.value?.id));
  return ref.watch(inquiriesRepositoryProvider).received();
});

final sentInquiriesProvider = FutureProvider.autoDispose<List<InquiryItem>>((ref) {
  ref.watch(authControllerProvider.select((a) => a.value?.id));
  return ref.watch(inquiriesRepositoryProvider).sent();
});

class InquiriesRepository {
  InquiriesRepository(this._api);

  final ApiClient _api;

  List<InquiryItem> _items(Json res) =>
      (res['data'] as List).map((e) => InquiryItem.fromJson(e as Json)).toList();

  Future<List<InquiryItem>> received() async => _items(await _api.get('/me/inquiries/received', query: {'limit': 50}));

  Future<List<InquiryItem>> sent() async => _items(await _api.get('/me/inquiries/sent', query: {'limit': 50}));

  Future<void> setStatus(String id, String status) => _api.patch('/inquiries/$id', body: {'status': status});
}
