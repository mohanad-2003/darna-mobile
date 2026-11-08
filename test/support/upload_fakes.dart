import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:darna/core/api/api_exception.dart';
import 'package:darna/features/listings/listing_local_store.dart';
import 'package:darna/features/listings/listing_models.dart';
import 'package:darna/features/listings/listing_repository.dart';
import 'package:darna/features/listings/manage_listing_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'account_harness.dart';
import 'memory_listing_store.dart';

Map<String, Object?> ownerListingJson({String status = 'DRAFT'}) => {
      'id': 'p1',
      'listingStatus': status,
      'title': 'شقة للبيع في رام الله',
      'description': 'وصف طويل بما يكفي لإعلان تجريبي',
      'purpose': 'SALE',
      'propertyType': 'APARTMENT',
      'price': '90000.00',
      'currency': 'USD',
      'contactPhone': '+970599111222',
      'location': {'id': 'l1', 'breadcrumbAr': 'رام الله'},
      'media': <Object?>[],
    };

/// A JPEG-looking file: only the first bytes matter to the app, [seed] makes each one different.
Uint8List jpegBytes(int seed) =>
    Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, ...List.generate(64, (i) => (i * 7 + seed) % 251)]);

XFile photo(int seed, {String? name}) => XFile.fromData(jpegBytes(seed), name: name ?? 'photo_$seed.jpg');

/// A picked file whose temporary copy no longer exists.
class BrokenFile extends XFile {
  BrokenFile() : super('/gone/photo.jpg');

  @override
  Future<Uint8List> readAsBytes() => Future.error(const FileSystemException('file is gone'));
}

/// The system picker: returns what the test set, and can hold "lost" results for recovery.
class FakePicker extends ImagePicker {
  List<XFile> next = [];
  LostDataResponse lost = LostDataResponse.empty();
  int retrieveCalls = 0;

  /// Called when the picker "opens", to look at the state of the app at that moment.
  void Function()? onPick;

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    onPick?.call();
    return next;
  }

  @override
  Future<LostDataResponse> retrieveLostData() async {
    retrieveCalls++;
    return lost;
  }
}

/// Stands in for the signed-URL upload, and counts what the screen asks for.
class FakeRepo extends ListingRepository {
  FakeRepo(super.api);

  int tickets = 0;
  int puts = 0;
  int attaches = 0;

  /// Holds every storage upload until completed.
  Completer<void>? gate;

  /// Returns an error to throw for the n-th storage upload (1-based), or null.
  Object? Function(int n)? failPut;

  @override
  Future<UploadTicket> uploadTicket(String id, String contentType, int size) async {
    tickets++;
    return UploadTicket(
      uploadId: 'upload-$tickets',
      url: 'https://storage.test/$tickets',
      headers: const {},
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
    );
  }

  @override
  Future<void> putToStorage(UploadTicket ticket, Uint8List bytes) async {
    puts++;
    await gate?.future;
    final error = failPut?.call(puts);
    if (error != null) throw error;
  }

  @override
  Future<void> attach(String id, String uploadId) async => attaches++;
}

ApiException get offlineError =>
    ApiException(status: 0, code: 'UPLOAD_FAILED', message: 'فشل رفع الصورة، تحقق من الاتصال وحاول مرة أخرى');

/// The manage-listing screen with fake picker, storage upload and local store.
class UploadHarness {
  UploadHarness({String accountId = 'u1'}) : session = TestSession(user: userJson(id: accountId)) {
    session.api.on('GET', '/properties/p1', (_) => {'data': ownerListingJson()});
    repo = FakeRepo(session.api);
  }

  final TestSession session;
  late final FakeRepo repo;
  final picker = FakePicker();
  final store = MemoryListingStore();

  Widget app() => testApp(
        screen: ManageListingScreen(propertyId: 'p1', picker: picker),
        session: session,
        extraOverrides: [
          listingRepositoryProvider.overrideWithValue(repo),
          listingLocalStoreProvider.overrideWithValue(store),
        ],
      );
}

extension UploadHarnessDriving on UploadHarness {
  /// Opens the screen on top of the home page.
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
  }

  /// Taps "add photos" with [files] as the picker's answer.
  Future<void> pick(WidgetTester tester, List<XFile> files, {bool settle = true}) async {
    picker.next = files;
    await tester.tap(find.text('إضافة صور'));
    settle ? await tester.pumpAndSettle() : await tester.pump(const Duration(milliseconds: 50));
  }
}
