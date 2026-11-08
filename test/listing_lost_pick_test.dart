import 'package:darna/app/theme.dart';
import 'package:darna/features/listings/listing_local_store.dart';
import 'package:darna/features/listings/pending_pick_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'support/account_harness.dart';
import 'support/memory_listing_store.dart';
import 'support/upload_fakes.dart';

PendingPick _note({String account = 'u1', String property = 'p1', Duration age = Duration.zero}) =>
    PendingPick(accountId: account, propertyId: property, at: DateTime.now().subtract(age));

/// Opens the manage screen the way the app does after Android ended it: the screen starts up
/// by itself and has to look for the lost photos.
Future<UploadHarness> _openWith(
  WidgetTester tester, {
  PendingPick? note,
  LostDataResponse? lost,
  String accountId = 'u1',
}) async {
  final h = UploadHarness(accountId: accountId);
  h.store.pick = note;
  if (lost != null) h.picker.lost = lost;
  await h.open(tester);
  return h;
}

void main() {
  group('after Android ended the app with the picker open', () {
    testWidgets('the chosen photos come back and are uploaded', (tester) async {
      final h = await _openWith(tester,
          note: _note(), lost: LostDataResponse(type: RetrieveType.image, files: [photo(1), photo(2)]));

      expect(h.picker.retrieveCalls, 1);
      expect(h.repo.attaches, 2);
      expect(h.store.pick, isNull); // the note is used up
      expect(find.text('استعدنا 2 صور اخترتها، وسنرفعها الآن'), findsOneWidget);
    });

    testWidgets('a single recovered file (older plugin shape) is handled too', (tester) async {
      final h = await _openWith(tester, note: _note(), lost: LostDataResponse(type: RetrieveType.image, file: photo(1)));

      expect(h.repo.attaches, 1);
    });

    testWidgets('nothing happens without a note: the picker is not even asked', (tester) async {
      final h = await _openWith(tester, lost: LostDataResponse(files: [photo(1)]));

      expect(h.picker.retrieveCalls, 0);
      expect(h.repo.attaches, 0);
    });

    testWidgets('a note about another listing is left alone', (tester) async {
      final h = await _openWith(tester, note: _note(property: 'other'), lost: LostDataResponse(files: [photo(1)]));

      expect(h.picker.retrieveCalls, 0);
      expect(h.store.pick?.propertyId, 'other');
    });

    testWidgets('another account does not inherit the photos', (tester) async {
      final h = await _openWith(tester,
          note: _note(account: 'u1'), accountId: 'u2', lost: LostDataResponse(files: [photo(1)]));

      expect(h.picker.retrieveCalls, 0);
      expect(h.repo.attaches, 0);
      expect(h.store.pick, isNull);
    });

    testWidgets('an old note is dropped', (tester) async {
      final h = await _openWith(tester,
          note: _note(age: const Duration(hours: 2)), lost: LostDataResponse(files: [photo(1)]));

      expect(h.picker.retrieveCalls, 0);
      expect(h.repo.attaches, 0);
      expect(h.store.pick, isNull);
    });

    testWidgets('the limit applies to recovered photos', (tester) async {
      final h = await _openWith(tester,
          note: _note(), lost: LostDataResponse(files: [for (var i = 0; i < 25; i++) photo(i)]));

      expect(h.repo.attaches, 20);
      // two messages are queued (recovered, then the limit): the second shows after the first
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('سيُرفع أول 20 صور فقط (الحد الأقصى 20)'), findsOneWidget);
    });

    testWidgets('duplicates among recovered photos are uploaded once', (tester) async {
      final h = await _openWith(tester,
          note: _note(), lost: LostDataResponse(files: [photo(1, name: 'a.jpg'), photo(1, name: 'b.jpg'), photo(2)]));

      expect(h.repo.attaches, 2);
    });

    testWidgets('a photo whose temporary file disappeared fails visibly and the others still go', (tester) async {
      final h = await _openWith(tester, note: _note(), lost: LostDataResponse(files: [BrokenFile(), photo(2)]));

      expect(find.text('تعذرت قراءة الصورة، اخترها من جديد'), findsOneWidget);
      expect(h.repo.attaches, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a recovery error is reported, not thrown', (tester) async {
      final h = await _openWith(tester,
          note: _note(), lost: LostDataResponse(exception: PlatformException(code: 'picker_failed')));

      expect(find.text('تعذر استعادة الصور المختارة، اخترها من جديد'), findsOneWidget);
      expect(h.repo.attaches, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty answer changes nothing', (tester) async {
      final h = await _openWith(tester, note: _note());

      expect(h.picker.retrieveCalls, 1);
      expect(h.repo.attaches, 0);
      expect(h.store.pick, isNull);
    });
  });

  group('the note around a normal pick', () {
    testWidgets('is written before the picker opens and removed when it returns', (tester) async {
      final h = UploadHarness();
      PendingPick? whileOpen;
      h.picker.onPick = () => whileOpen = h.store.pick;
      await h.open(tester);

      await h.pick(tester, [photo(1)]);

      expect(whileOpen?.propertyId, 'p1');
      expect(whileOpen?.accountId, 'u1');
      expect(h.store.pick, isNull);
      expect(h.repo.attaches, 1);
    });

    testWidgets('is removed when the user cancels the picker', (tester) async {
      final h = UploadHarness();
      await h.open(tester);

      await h.pick(tester, []);

      expect(h.store.pick, isNull);
      expect(h.repo.attaches, 0);
    });
  });

  group('starting the app', () {
    Future<GoRouter> start(WidgetTester tester, MemoryListingStore store, {String accountId = 'u1'}) async {
      final session = TestSession(user: userJson(id: accountId));
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('home')),
        GoRoute(path: '/listing/:id', builder: (_, state) => Text('listing-${state.pathParameters['id']}')),
      ]);
      await tester.pumpWidget(ProviderScope(
        overrides: [...session.overrides, listingLocalStoreProvider.overrideWithValue(store)],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light(),
          builder: (context, child) => PendingPickGate(router: router, child: child!),
        ),
      ));
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('goes back to the listing whose picker was open', (tester) async {
      final store = MemoryListingStore()..pick = _note();
      await start(tester, store);

      expect(find.text('listing-p1'), findsOneWidget);
    });

    testWidgets('does nothing without a note', (tester) async {
      await start(tester, MemoryListingStore());

      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('does not send another account to that listing, and forgets the note', (tester) async {
      final store = MemoryListingStore()..pick = _note(account: 'u1');
      await start(tester, store, accountId: 'u2');

      expect(find.text('home'), findsOneWidget);
      expect(store.pick, isNull);
    });

    testWidgets('forgets an old note', (tester) async {
      final store = MemoryListingStore()..pick = _note(age: const Duration(hours: 2));
      await start(tester, store);

      expect(find.text('home'), findsOneWidget);
      expect(store.pick, isNull);
    });
  });
}
