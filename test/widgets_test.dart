import 'package:darna/core/auth/auth_controller.dart';
import 'package:darna/core/widgets/darna_logo.dart';
import 'package:darna/core/widgets/skeleton.dart';
import 'package:darna/features/properties/models.dart';
import 'package:darna/features/properties/property_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:darna/app/theme.dart';
import 'package:flutter_test/flutter_test.dart';

// The real controller reads the device keystore; tests browse as an anonymous visitor.
class _AnonymousAuth extends AuthController {
  @override
  Future<Me?> build() async => null;
}

Widget _app(Widget child) => ProviderScope(
      overrides: [authControllerProvider.overrideWith(_AnonymousAuth.new)],
      child: MaterialApp(
        home: Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: child)),
      ),
    );

PropertyCard _card({bool verified = false}) => PropertyCard.fromJson({
      'id': 'a1',
      'title': 'شقة مشمسة في رام الله',
      'purpose': 'SALE',
      'propertyType': 'APARTMENT',
      'price': '135000.00',
      'currency': 'USD',
      'areaSqm': '140.00',
      'bedrooms': 3,
      'bathrooms': 2,
      'coverThumbnailUrl': null,
      'location': {'id': 'l1', 'nameAr': 'رام الله', 'breadcrumbAr': 'رام الله والبيرة › رام الله'},
      'office': verified ? {'id': 'o1', 'name': 'مكتب النور', 'verified': true} : null,
    });

void main() {
  testWidgets('listing card shows price, title, place, badges and rooms', (tester) async {
    await tester.pumpWidget(_app(PropertyCardTile(property: _card())));
    await tester.pump();

    expect(find.text(r'135,000 $'), findsOneWidget);
    expect(find.text('شقة مشمسة في رام الله'), findsOneWidget);
    expect(find.text('رام الله والبيرة › رام الله'), findsOneWidget);
    expect(find.text('للبيع'), findsOneWidget);
    expect(find.text('شقة'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // bedrooms
    expect(find.text('مكتب موثّق'), findsNothing);
  });

  testWidgets('listing card marks verified offices', (tester) async {
    await tester.pumpWidget(_app(PropertyCardTile(property: _card(verified: true))));
    await tester.pump();
    expect(find.text('مكتب موثّق'), findsOneWidget);
  });

  testWidgets('skeletons render and animate without errors', (tester) async {
    await tester.pumpWidget(_app(const SingleChildScrollView(child: Column(children: [
      PropertyCardSkeleton(),
      SizedBox(height: 600, child: PropertyDetailSkeleton()),
    ]))));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(Skeleton), findsWidgets);
  });

  testWidgets('logo shows the 3D house with readable text on light and dark backgrounds', (tester) async {
    Color? wordmarkColor() => tester.widget<Text>(find.text('دارنا')).style?.color;

    Future<void> show(ThemeData theme, {bool? onLight}) async {
      await tester.pumpWidget(MaterialApp(theme: theme, home: Scaffold(body: DarnaLogo(onLight: onLight))));
      await tester.pumpAndSettle(); // MaterialApp animates theme changes
    }

    await show(ThemeData(brightness: Brightness.light));
    expect(wordmarkColor(), brandPrimary);
    final house = tester.widget<Image>(find.byType(Image));
    expect((house.image as AssetImage).assetName, 'assets/branding/darna_house_mark.png');
    await show(ThemeData(brightness: Brightness.dark));
    expect(wordmarkColor(), brandIvory);
    // a fixed light background wins over the theme
    await show(ThemeData(brightness: Brightness.dark), onLight: true);
    expect(wordmarkColor(), brandPrimary);
  });
}
