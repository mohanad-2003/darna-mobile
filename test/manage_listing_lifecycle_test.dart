import 'dart:async';

import 'package:darna/features/listings/manage_listing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/account_harness.dart';

Map<String, Object?> _listing(String status) => {
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

void main() {
  testWidgets('finishing an action after leaving the screen does not throw', (tester) async {
    final session = TestSession();
    final release = Completer<void>();
    session.api
      ..on('GET', '/properties/p1', (_) => {'data': _listing('PUBLISHED')})
      ..on('POST', '/properties/p1/pause', (_) async {
        await release.future; // the request stays pending until the test lets it finish
        return <String, dynamic>{};
      });

    await tester.pumpWidget(testApp(screen: const ManageListingScreen(propertyId: 'p1'), session: session));
    await tester.pumpAndSettle();
    await tester.tap(find.text('home')); // opens the screen on top of the home page
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إيقاف مؤقت'));
    await tester.pump(); // the pause request is now waiting

    GoRouter.of(tester.element(find.byType(ManageListingScreen))).pop(); // leave while it is still running
    await tester.pumpAndSettle();

    release.complete(); // the request finishes after the screen is gone
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
