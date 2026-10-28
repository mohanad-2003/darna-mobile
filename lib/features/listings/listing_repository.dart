import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/auth/auth_controller.dart';
import 'listing_models.dart';

final listingRepositoryProvider =
    Provider<ListingRepository>((ref) => ListingRepository(ref.watch(apiClientProvider)));

/// The signed-in user's listings. Reloads when the account changes.
final myListingsProvider = FutureProvider.autoDispose<List<OwnerListing>>((ref) {
  ref.watch(authControllerProvider.select((a) => a.value?.id));
  return ref.watch(listingRepositoryProvider).mine();
});

final ownerListingProvider = FutureProvider.autoDispose.family<OwnerListing, String>(
    (ref, id) => ref.watch(listingRepositoryProvider).get(id));

/// Image type from the file's first bytes (not its name), or null if it is not
/// JPEG, PNG or WebP — the only types the backend accepts.
String? sniffImageType(Uint8List b) {
  if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return 'image/jpeg';
  if (b.length >= 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return 'image/png';
  if (b.length >= 12 &&
      String.fromCharCodes(b.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(b.sublist(8, 12)) == 'WEBP') {
    return 'image/webp';
  }
  return null;
}

class ListingRepository {
  ListingRepository(this._api);

  final ApiClient _api;

  Future<List<OwnerListing>> mine() async {
    final res = await _api.get('/me/properties', query: {'limit': 50});
    return (res['data'] as List).map((e) => OwnerListing.fromJson(e as Json)).toList();
  }

  Future<OwnerListing> get(String id) async =>
      OwnerListing.fromJson((await _api.get('/properties/$id'))['data'] as Json);

  Future<OwnerListing> create(Json body) async =>
      OwnerListing.fromJson((await _api.post('/properties', body: body))['data'] as Json);

  Future<OwnerListing> update(String id, Json body) async =>
      OwnerListing.fromJson((await _api.patch('/properties/$id', body: body))['data'] as Json);

  Future<void> _action(String id, String action) => _api.post('/properties/$id/$action');

  Future<void> submit(String id) => _action(id, 'submit');
  Future<void> pause(String id) => _action(id, 'pause');
  Future<void> resume(String id) => _action(id, 'resume');
  Future<void> renew(String id) => _action(id, 'renew');
  Future<void> archive(String id) => _action(id, 'archive');

  // ---- images: ask for a signed URL, send the bytes straight to storage, then attach.

  Future<UploadTicket> uploadTicket(String id, String contentType, int size) async {
    final res = await _api.post('/properties/$id/media/upload-url',
        body: {'contentType': contentType, 'sizeBytes': size});
    return UploadTicket(
      uploadId: res['uploadId'] as String,
      url: res['uploadUrl'] as String,
      headers: (res['headers'] as Map).map((k, v) => MapEntry(k as String, v as String)),
    );
  }

  Future<void> putToStorage(UploadTicket ticket, Uint8List bytes) async {
    try {
      // A bare Dio: this goes to the storage host, not to our API, and must not carry our token.
      await Dio().put<void>(
        ticket.url,
        data: bytes,
        options: Options(
          headers: {...ticket.headers, Headers.contentLengthHeader: bytes.length},
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
    } on DioException catch (e) {
      throw ApiException(
        status: e.response?.statusCode ?? 0,
        code: 'UPLOAD_FAILED',
        message: 'فشل رفع الصورة، تحقق من الاتصال وحاول مرة أخرى',
      );
    }
  }

  Future<void> attach(String id, String uploadId) =>
      _api.post('/properties/$id/media', body: {'uploadId': uploadId});

  Future<void> setCover(String id, String mediaId) =>
      _api.patch('/properties/$id/media/$mediaId', body: {'isCover': true});

  Future<void> deleteMedia(String id, String mediaId) => _api.delete('/properties/$id/media/$mediaId');
}
