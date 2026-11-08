import 'dart:convert';

import 'package:darna/features/listings/listing_form_screen.dart';
import 'package:darna/features/listings/listing_local_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/account_harness.dart';
import 'support/memory_listing_store.dart';

const _bannerText = 'لديك مسودة إعلان غير مكتملة على هذا الجهاز.';
const _titleLabel = 'عنوان الإعلان';

Map<String, Object?> _ownerListing() => {
      'id': 'p1',
      'listingStatus': 'DRAFT',
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

/// A complete draft: every step passes validation once it is restored.
Map<String, Object?> _fullDraft() => {
      'purpose': 'SALE',
      'type': 'APARTMENT',
      'currency': 'ILS',
      'rentPeriod': 'MONTHLY',
      'furnished': false,
      'showPhone': true,
      'allowWhatsapp': true,
      'locationId': 'l1',
      'locationName': 'رام الله',
      'title': 'شقة من ثلاث غرف',
      'description': 'شقة واسعة ومشمسة في حي هادئ قريب من الخدمات',
      'price': '90000',
      'area': '',
      'bedrooms': '3',
      'bathrooms': '1',
      'floor': '',
      'address': '',
      'phone': '+970599111222',
      'step': 0,
    };

class _Setup {
  _Setup({String accountId = 'u1', MemoryListingStore? store})
      : store = store ?? MemoryListingStore(),
        session = TestSession(user: userJson(id: accountId));

  final MemoryListingStore store;
  final TestSession session;

  Widget app({Widget screen = const ListingFormScreen(), ThemeMode themeMode = ThemeMode.light}) => testApp(
        screen: screen,
        session: session,
        themeMode: themeMode,
        extraOverrides: [listingLocalStoreProvider.overrideWithValue(store)],
        extraRoutes: [GoRoute(path: '/listing/:id', builder: (_, state) => Text('listing-${state.pathParameters['id']}'))],
      );

  Future<void> open(WidgetTester tester, {Widget screen = const ListingFormScreen(), ThemeMode themeMode = ThemeMode.light}) async {
    await tester.pumpWidget(app(screen: screen, themeMode: themeMode));
    await tester.pumpAndSettle();
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
  }
}

Future<void> _type(WidgetTester tester, String label, String text) async {
  await tester.enterText(find.widgetWithText(TextFormField, label), text);
  await tester.pump();
}

Future<void> _back(WidgetTester tester) async {
  await tester.binding.handlePopRoute(); // the system back button
  await tester.pumpAndSettle();
}

void main() {
  group('leaving a new listing', () {
    testWidgets('a blank form closes without asking', (tester) async {
      final t = _Setup();
      await t.open(tester);

      await _back(tester);

      expect(find.text('حفظ الإعلان كمسودة؟'), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('typing something and leaving asks, and "stay" keeps the form', (tester) async {
      final t = _Setup();
      await t.open(tester);
      await _type(tester, _titleLabel, 'شقة للبيع');

      await _back(tester);
      expect(find.text('حفظ الإعلان كمسودة؟'), findsOneWidget);

      await tester.tap(find.text('متابعة التعديل'));
      await tester.pumpAndSettle();
      expect(find.text('حفظ الإعلان كمسودة؟'), findsNothing);
      expect(find.text('شقة للبيع'), findsOneWidget);
    });

    testWidgets('"save and leave" stores a draft for this account, without tokens', (tester) async {
      final t = _Setup();
      await t.open(tester);
      await _type(tester, _titleLabel, 'شقة للبيع');

      await _back(tester);
      await tester.tap(find.text('حفظ ومغادرة'));
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
      final draft = t.store.drafts['u1']!;
      expect(draft['title'], 'شقة للبيع');
      // only form fields: nothing that identifies a session, no photo data
      expect(jsonEncode(draft), isNot(contains('access-1')));
      expect(jsonEncode(draft), isNot(contains('refresh-1')));
      expect(draft.keys, everyElement(isIn(_fullDraft().keys)));
    });

    testWidgets('"ignore" leaves and removes what was autosaved', (tester) async {
      final t = _Setup();
      await t.open(tester);
      await _type(tester, _titleLabel, 'شقة للبيع');
      await tester.pump(const Duration(seconds: 1)); // the draft is written shortly after typing
      expect(t.store.drafts['u1'], isNotNull);

      await _back(tester);
      await tester.tap(find.text('تجاهل'));
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
      expect(t.store.drafts, isEmpty);
    });
  });

  group('the draft', () {
    testWidgets('is written shortly after typing stops, not on every key', (tester) async {
      final t = _Setup();
      await t.open(tester);

      await _type(tester, _titleLabel, 'شقة');
      await tester.pump(const Duration(milliseconds: 300));
      expect(t.store.drafts, isEmpty);

      await tester.pump(const Duration(seconds: 1));
      expect(t.store.drafts['u1']!['title'], 'شقة');
    });

    testWidgets('is offered next time and restores every field', (tester) async {
      final store = MemoryListingStore()..drafts['u1'] = _fullDraft();
      final t = _Setup(store: store);
      await t.open(tester);

      expect(find.text(_bannerText), findsOneWidget);
      await tester.tap(find.text('استعادة المسودة'));
      await tester.pumpAndSettle();

      expect(find.text(_bannerText), findsNothing);
      expect(find.text('شقة من ثلاث غرف'), findsOneWidget);
      expect(find.text('رام الله'), findsOneWidget);
    });

    testWidgets('can be deleted from the banner', (tester) async {
      final store = MemoryListingStore()..drafts['u1'] = _fullDraft();
      final t = _Setup(store: store);
      await t.open(tester);

      await tester.tap(find.text('حذف المسودة'));
      await tester.pumpAndSettle();

      expect(find.text(_bannerText), findsNothing);
      expect(store.drafts, isEmpty);
    });

    testWidgets('belongs to the account that wrote it', (tester) async {
      final store = MemoryListingStore()..drafts['u1'] = _fullDraft();
      final other = _Setup(accountId: 'u2', store: store);
      await other.open(tester);

      expect(find.text(_bannerText), findsNothing);
      expect(store.drafts.keys, ['u1']); // and the other account did not touch it
    });

    testWidgets('typing before answering the banner does not overwrite the older draft', (tester) async {
      final store = MemoryListingStore()..drafts['u1'] = _fullDraft();
      final t = _Setup(store: store);
      await t.open(tester);

      await _type(tester, _titleLabel, 'عنوان جديد');
      await tester.pump(const Duration(seconds: 1));

      expect(store.drafts['u1']!['title'], 'شقة من ثلاث غرف');
    });

    testWidgets('ignores a damaged value instead of crashing', (tester) async {
      final store = MemoryListingStore()
        ..drafts['u1'] = {..._fullDraft(), 'purpose': 'NONSENSE', 'currency': 5, 'furnished': 'yes', 'step': 99};
      final t = _Setup(store: store);
      await t.open(tester);

      await tester.tap(find.text('استعادة المسودة'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('شقة من ثلاث غرف'), findsOneWidget);
    });

    testWidgets('is removed once the listing is created', (tester) async {
      final store = MemoryListingStore()..drafts['u1'] = _fullDraft();
      final t = _Setup(store: store);
      Object? sent;
      t.session.api.on('POST', '/properties', (body) {
        sent = body;
        return {'data': {..._ownerListing(), 'id': 'p9'}};
      });
      await t.open(tester);
      await tester.tap(find.text('استعادة المسودة'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('التالي: إضافة الصور'));
      await tester.pumpAndSettle();

      expect((sent as Map)['title'], 'شقة من ثلاث غرف');
      expect(find.text('listing-p9'), findsOneWidget);
      expect(store.drafts, isEmpty);
    });

    testWidgets('banner and dialog work in the dark theme', (tester) async {
      final store = MemoryListingStore()..drafts['u1'] = _fullDraft();
      final t = _Setup(store: store);
      await t.open(tester, themeMode: ThemeMode.dark);
      expect(find.text(_bannerText), findsOneWidget);

      await tester.tap(find.text('استعادة المسودة'));
      await tester.pumpAndSettle();
      await _back(tester);
      expect(find.text('حفظ الإعلان كمسودة؟'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('editing an existing listing', () {
    testWidgets('warns about unsaved edits, and never writes a draft', (tester) async {
      final t = _Setup();
      t.session.api.on('GET', '/properties/p1', (_) => {'data': _ownerListing()});
      await t.open(tester, screen: const ListingFormScreen(propertyId: 'p1'));

      await _back(tester);
      expect(find.text('تجاهل التعديلات؟'), findsNothing); // nothing changed yet

      await tester.tap(find.text('home'));
      await tester.pumpAndSettle();
      await _type(tester, _titleLabel, 'عنوان معدّل');
      await tester.pump(const Duration(seconds: 1));
      await _back(tester);

      expect(find.text('تجاهل التعديلات؟'), findsOneWidget);
      expect(find.text('حفظ ومغادرة'), findsNothing);
      expect(t.store.drafts, isEmpty);

      await tester.tap(find.text('تجاهل'));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });
  });
}
