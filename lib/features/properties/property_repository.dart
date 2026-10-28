import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_controller.dart';
import 'models.dart';

final propertyRepositoryProvider =
    Provider<PropertyRepository>((ref) => PropertyRepository(ref.watch(apiClientProvider)));

class SearchFilters {
  const SearchFilters({
    this.purpose,
    this.locationId,
    this.locationName,
    this.propertyTypes = const {},
    this.currency,
    this.minPrice,
    this.maxPrice,
    this.minBedrooms,
    this.sort = 'newest',
  });

  final String? purpose; // SALE | RENT | null = both
  final String? locationId;
  final String? locationName;
  final Set<String> propertyTypes;
  // The backend never compares prices across currencies, so a price filter or a price
  // sort always comes with one.
  final String? currency;
  final String? minPrice;
  final String? maxPrice;
  final int? minBedrooms;
  final String sort; // newest | price_asc | price_desc

  bool get hasPrice => minPrice != null || maxPrice != null;

  /// How many filters from the filter sheet are active (the purpose and location chips
  /// show their own state).
  int get activeCount =>
      (propertyTypes.isEmpty ? 0 : 1) + (hasPrice ? 1 : 0) + (minBedrooms == null ? 0 : 1) + (sort == 'newest' ? 0 : 1);

  SearchFilters copyWith({
    String? purpose,
    bool clearPurpose = false,
    String? locationId,
    String? locationName,
    bool clearLocation = false,
    Set<String>? propertyTypes,
    String? currency,
    String? minPrice,
    String? maxPrice,
    bool clearPrice = false,
    int? minBedrooms,
    bool clearBedrooms = false,
    String? sort,
  }) =>
      SearchFilters(
        purpose: clearPurpose ? null : (purpose ?? this.purpose),
        locationId: clearLocation ? null : (locationId ?? this.locationId),
        locationName: clearLocation ? null : (locationName ?? this.locationName),
        propertyTypes: propertyTypes ?? this.propertyTypes,
        currency: currency ?? this.currency,
        minPrice: clearPrice ? null : (minPrice ?? this.minPrice),
        maxPrice: clearPrice ? null : (maxPrice ?? this.maxPrice),
        minBedrooms: clearBedrooms ? null : (minBedrooms ?? this.minBedrooms),
        sort: sort ?? this.sort,
      );

  /// Everything from the filter sheet reset; purpose and location stay.
  SearchFilters clearedSheet() => SearchFilters(
        purpose: purpose,
        locationId: locationId,
        locationName: locationName,
      );
}

class PropertyRepository {
  PropertyRepository(this._api);

  final ApiClient _api;

  PagedResult<PropertyCard> _cards(Json res) {
    final page = res['page'] as Json;
    return PagedResult(
      items: (res['data'] as List).map((e) => PropertyCard.fromJson(e as Json)).toList(),
      nextCursor: page['nextCursor'] as String?,
      hasMore: page['hasMore'] as bool,
    );
  }

  Future<PagedResult<PropertyCard>> search(SearchFilters f, {String? cursor}) async {
    final res = await _api.get('/properties', query: {
      'purpose': ?f.purpose,
      'locationId': ?f.locationId,
      if (f.propertyTypes.isNotEmpty) 'propertyType': (f.propertyTypes.toList()..sort()).join(','),
      // Sent only with a price filter or sort; the backend requires it then.
      if (f.hasPrice || f.sort != 'newest') 'currency': f.currency ?? 'ILS',
      'minPrice': ?f.minPrice,
      'maxPrice': ?f.maxPrice,
      'minBedrooms': ?f.minBedrooms,
      if (f.sort != 'newest') 'sort': f.sort,
      'cursor': ?cursor,
      'limit': 20,
    });
    return _cards(res);
  }

  Future<PropertyDetail> detail(String id) async {
    final res = await _api.get('/properties/$id');
    return PropertyDetail.fromJson(res['data'] as Json);
  }

  Future<PagedResult<PropertyCard>> favorites() async =>
      _cards(await _api.get('/me/favorites', query: {'limit': 50}));

  Future<void> addFavorite(String id) => _api.put('/properties/$id/favorites');

  Future<void> removeFavorite(String id) => _api.delete('/properties/$id/favorites');

  Future<List<GeoLocation>> locations({String? parentId}) async {
    final res = await _api.get('/locations', query: {'parentId': ?parentId});
    return (res['data'] as List)
        .map((e) => GeoLocation(
              id: (e as Json)['id'] as String,
              nameAr: e['nameAr'] as String,
              hasChildren: (e['hasChildren'] as bool?) ?? false,
            ))
        .toList();
  }

  Future<ContactInfo> revealContact(String id) async =>
      ContactInfo.fromJson(await _api.post('/properties/$id/contact-reveal'));

  Future<void> report(String id, String reason, String? description) => _api.post(
        '/properties/$id/reports',
        body: {'reason': reason, 'description': ?description},
      );

  Future<void> sendInquiry(String id, String message) =>
      _api.post('/properties/$id/inquiries', body: {'message': message});
}
