import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';

class ListingMedia {
  ListingMedia({required this.id, required this.url, required this.thumbnailUrl, required this.isCover});

  final String id;
  final String url;
  final String thumbnailUrl;
  final bool isCover;

  factory ListingMedia.fromJson(Json j) => ListingMedia(
        id: j['id'] as String,
        url: j['url'] as String,
        thumbnailUrl: (j['thumbnailUrl'] as String?) ?? (j['url'] as String),
        isCover: (j['isCover'] as bool?) ?? false,
      );
}

/// A listing as its owner sees it: every status, every field, the moderation reason.
class OwnerListing {
  OwnerListing({
    required this.id,
    required this.status,
    this.moderationReason,
    required this.title,
    required this.description,
    required this.purpose,
    required this.propertyType,
    required this.price,
    required this.currency,
    this.rentPeriod,
    this.areaSqm,
    this.bedrooms,
    this.bathrooms,
    this.floorNumber,
    this.furnished,
    this.contactName,
    required this.contactPhone,
    required this.showPhone,
    required this.allowWhatsapp,
    this.addressText,
    required this.locationId,
    required this.locationName,
    required this.media,
  });

  final String id;
  final String status;
  final String? moderationReason;
  final String title;
  final String description;
  final String purpose;
  final String propertyType;
  final String price;
  final String currency;
  final String? rentPeriod;
  final String? areaSqm;
  final int? bedrooms;
  final int? bathrooms;
  final int? floorNumber;
  final bool? furnished;
  final String? contactName;
  final String contactPhone;
  final bool showPhone;
  final bool allowWhatsapp;
  final String? addressText;
  final String locationId;
  final String locationName;
  final List<ListingMedia> media;

  bool get isEditable => const {'DRAFT', 'NEEDS_CHANGES', 'REJECTED', 'PUBLISHED', 'PAUSED'}.contains(status);
  bool get canSubmit => const {'DRAFT', 'NEEDS_CHANGES', 'REJECTED'}.contains(status);

  factory OwnerListing.fromJson(Json j) {
    final loc = j['location'] as Json?;
    return OwnerListing(
      id: j['id'] as String,
      status: j['listingStatus'] as String,
      moderationReason: j['moderationReason'] as String?,
      title: j['title'] as String,
      description: j['description'] as String,
      purpose: j['purpose'] as String,
      propertyType: j['propertyType'] as String,
      price: j['price'] as String,
      currency: j['currency'] as String,
      rentPeriod: j['rentPeriod'] as String?,
      areaSqm: j['areaSqm'] as String?,
      bedrooms: j['bedrooms'] as int?,
      bathrooms: j['bathrooms'] as int?,
      floorNumber: j['floorNumber'] as int?,
      furnished: j['furnished'] as bool?,
      contactName: j['contactName'] as String?,
      contactPhone: j['contactPhone'] as String,
      showPhone: (j['showPhone'] as bool?) ?? true,
      allowWhatsapp: (j['allowWhatsapp'] as bool?) ?? true,
      addressText: j['addressText'] as String?,
      locationId: loc?['id'] as String? ?? '',
      locationName: (loc?['breadcrumbAr'] as String?) ?? '',
      media: ((j['media'] as List?) ?? []).map((m) => ListingMedia.fromJson(m as Json)).toList(),
    );
  }
}

class StatusInfo {
  const StatusInfo(this.label, this.color, this.hint);

  final String label;
  final Color color;
  final String hint;
}

const _statusInfo = {
  'DRAFT': StatusInfo('مسودة', Colors.blueGrey, 'أضف الصور ثم أرسل الإعلان للمراجعة.'),
  'PENDING_REVIEW': StatusInfo('قيد المراجعة', Colors.orange, 'سيراجع فريقنا إعلانك قريباً وستصلك رسالة بالنتيجة.'),
  'PUBLISHED': StatusInfo('منشور', Colors.green, 'إعلانك ظاهر للجميع.'),
  'NEEDS_CHANGES': StatusInfo('يحتاج تعديلات', Colors.deepOrange, 'عدّل الإعلان حسب الملاحظات ثم أرسله مجدداً.'),
  'REJECTED': StatusInfo('مرفوض', Colors.red, 'يمكنك تعديل الإعلان وإعادة إرساله.'),
  'PAUSED': StatusInfo('متوقف مؤقتاً', Colors.grey, 'الإعلان مخفي حتى تستأنفه.'),
  'SUSPENDED': StatusInfo('موقوف من الإدارة', Colors.red, 'أوقفت الإدارة هذا الإعلان.'),
  'EXPIRED': StatusInfo('منتهي', Colors.grey, 'انتهت مدة الإعلان، جدّده ليظهر مجدداً.'),
  'ARCHIVED': StatusInfo('مؤرشف', Colors.grey, ''),
};

StatusInfo statusInfo(String status) =>
    _statusInfo[status] ?? StatusInfo(status, Colors.grey, '');

class UploadTicket {
  UploadTicket({required this.uploadId, required this.url, required this.headers});

  final String uploadId;
  final String url;
  final Map<String, String> headers;
}
