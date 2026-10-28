import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_controller.dart';
import 'models.dart';

final propertyRepositoryProvider =
    Provider<PropertyRepository>((ref) => PropertyRepository(ref.watch(apiClientProvider)));

class SearchFilters {
  const SearchFilters({this.purpose, this.locationId, this.locationName});

  final String? purpose; // SALE | RENT | null = both
  final String? locationId;
  final String? locationName;

  SearchFilters copyWith({
    String? purpose,
    bool clearPurpose = false,
    String? locationId,
    String? locationName,
    bool clearLocation = false,
  }) =>
      SearchFilters(
        purpose: clearPurpose ? null : (purpose ?? this.purpose),
        locationId: clearLocation ? null : (locationId ?? this.locationId),
        locationName: clearLocation ? null : (locationName ?? this.locationName),
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

  Future<void> sendInquiry(String id, String message) =>
      _api.post('/properties/$id/inquiries', body: {'message': message});
}
