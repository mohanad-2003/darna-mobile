import '../../core/api/api_client.dart';

class LocationSummary {
  LocationSummary({required this.id, required this.nameAr, required this.breadcrumbAr});

  final String id;
  final String nameAr;
  final String breadcrumbAr;

  factory LocationSummary.fromJson(Json j) => LocationSummary(
        id: j['id'] as String,
        nameAr: j['nameAr'] as String,
        breadcrumbAr: (j['breadcrumbAr'] as String?) ?? (j['nameAr'] as String),
      );
}

class OfficeSummary {
  OfficeSummary({required this.id, required this.name, required this.verified});

  final String id;
  final String name;
  final bool verified;

  factory OfficeSummary.fromJson(Json j) => OfficeSummary(
        id: j['id'] as String,
        name: j['name'] as String,
        verified: (j['verified'] as bool?) ?? false,
      );
}

class MediaItem {
  MediaItem({required this.id, required this.url, required this.thumbnailUrl, this.altText});

  final String id;
  final String url;
  final String thumbnailUrl;
  final String? altText;

  factory MediaItem.fromJson(Json j) => MediaItem(
        id: j['id'] as String,
        url: j['url'] as String,
        thumbnailUrl: (j['thumbnailUrl'] as String?) ?? (j['url'] as String),
        altText: j['altText'] as String?,
      );
}

/// A listing as shown in search results and favorites.
class PropertyCard {
  PropertyCard({
    required this.id,
    required this.title,
    required this.purpose,
    required this.propertyType,
    required this.price,
    required this.currency,
    this.rentPeriod,
    this.areaSqm,
    this.bedrooms,
    this.bathrooms,
    this.coverThumbnailUrl,
    this.location,
    this.office,
    this.isFavorite = false,
  });

  final String id;
  final String title;
  final String purpose;
  final String propertyType;
  final String price;
  final String currency;
  final String? rentPeriod;
  final String? areaSqm;
  final int? bedrooms;
  final int? bathrooms;
  final String? coverThumbnailUrl;
  final LocationSummary? location;
  final OfficeSummary? office;
  final bool isFavorite;

  factory PropertyCard.fromJson(Json j) => PropertyCard(
        id: j['id'] as String,
        title: j['title'] as String,
        purpose: j['purpose'] as String,
        propertyType: j['propertyType'] as String,
        price: j['price'] as String,
        currency: j['currency'] as String,
        rentPeriod: j['rentPeriod'] as String?,
        areaSqm: j['areaSqm'] as String?,
        bedrooms: j['bedrooms'] as int?,
        bathrooms: j['bathrooms'] as int?,
        coverThumbnailUrl: j['coverThumbnailUrl'] as String?,
        location: j['location'] is Map ? LocationSummary.fromJson(j['location'] as Json) : null,
        office: j['office'] is Map ? OfficeSummary.fromJson(j['office'] as Json) : null,
        isFavorite: (j['isFavorite'] as bool?) ?? false,
      );
}

class PropertyDetail {
  PropertyDetail({
    required this.card,
    required this.description,
    required this.media,
    this.floorNumber,
    this.furnished,
    this.addressText,
    required this.canRevealPhone,
  });

  final PropertyCard card;
  final String description;
  final List<MediaItem> media;
  final int? floorNumber;
  final bool? furnished;
  final String? addressText;
  final bool canRevealPhone;

  factory PropertyDetail.fromJson(Json j) => PropertyDetail(
        card: PropertyCard.fromJson(j),
        description: j['description'] as String,
        media: ((j['media'] as List?) ?? [])
            .map((m) => MediaItem.fromJson(m as Json))
            .toList(),
        floorNumber: j['floorNumber'] as int?,
        furnished: j['furnished'] as bool?,
        addressText: j['addressText'] as String?,
        canRevealPhone: (j['canRevealPhone'] as bool?) ?? false,
      );
}

class ContactInfo {
  ContactInfo({this.name, required this.phone, this.whatsappUrl});

  final String? name;
  final String phone;
  final String? whatsappUrl;

  factory ContactInfo.fromJson(Json j) => ContactInfo(
        name: j['name'] as String?,
        phone: j['phone'] as String,
        whatsappUrl: j['whatsappUrl'] as String?,
      );
}

class PagedResult<T> {
  PagedResult({required this.items, required this.nextCursor, required this.hasMore});

  final List<T> items;
  final String? nextCursor;
  final bool hasMore;
}

class GeoLocation {
  GeoLocation({required this.id, required this.nameAr, this.hasChildren = false});

  final String id;
  final String nameAr;
  final bool hasChildren;
}
