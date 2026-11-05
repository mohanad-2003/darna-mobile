import 'package:darna/core/auth/auth_controller.dart';
import 'package:darna/features/properties/models.dart';
import 'package:darna/features/properties/property_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Anon extends AuthController {
  @override
  Future<Me?> build() async => null;
}

PropertyDetail _detail({String? description, bool withCoords = true, bool canReveal = true}) => PropertyDetail(
      card: PropertyCard(
        id: 'p1',
        title: 'شقة مشمسة في رام الله',
        purpose: 'RENT',
        propertyType: 'APARTMENT',
        price: '1500',
        currency: 'USD',
        rentPeriod: 'MONTHLY',
        areaSqm: '120',
        bedrooms: 3,
        bathrooms: 2,
        location: LocationSummary(id: 'l1', nameAr: 'رام الله', breadcrumbAr: 'رام الله، الضفة الغربية'),
        office: OfficeSummary(id: 'o1', name: 'مكتب الأمل', verified: true),
        publishedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      description: description ?? 'شقة واسعة ومشمسة قريبة من الخدمات.',
      media: const [],
      floorNumber: 2,
      furnished: true,
      addressText: 'شارع الإرسال',
      canRevealPhone: canReveal,
      latitude: withCoords ? 31.9 : null,
      longitude: withCoords ? 35.2 : null,
    );

Widget _app(PropertyDetail detail) => ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_Anon.new),
        propertyDetailProvider('p1').overrideWith((ref) async => detail),
      ],
      child: MaterialApp(
        home: Directionality(textDirection: TextDirection.rtl, child: const PropertyDetailScreen(propertyId: 'p1')),
      ),
    );

void main() {
  testWidgets('shows the listing facts, location and contact actions', (tester) async {
    await tester.pumpWidget(_app(_detail()));
    await tester.pumpAndSettle();

    expect(find.text('شقة مشمسة في رام الله'), findsWidgets);
    expect(find.text('1,500 \$ / شهرياً'), findsWidgets);
    expect(find.text('للإيجار'), findsWidgets);
    expect(find.text('مكتب موثّق'), findsOneWidget);
    expect(find.text('غرف نوم'), findsOneWidget);
    expect(find.text('مفروشة'), findsOneWidget);
    expect(find.text('إظهار الرقم'), findsOneWidget);
    expect(find.text('استفسار'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('عرض على الخريطة'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('عرض على الخريطة'), findsOneWidget);
    expect(find.text('مكتب الأمل'), findsOneWidget);
  });

  testWidgets('hides the map button without coordinates and the phone button when not allowed', (tester) async {
    await tester.pumpWidget(_app(_detail(withCoords: false, canReveal: false)));
    await tester.pumpAndSettle();

    expect(find.text('إظهار الرقم'), findsNothing);
    expect(find.text('استفسار'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('الموقع'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('عرض على الخريطة'), findsNothing);
  });

  testWidgets('a long description can be expanded and collapsed', (tester) async {
    await tester.pumpWidget(_app(_detail(description: List.filled(60, 'وصف طويل جداً للعقار').join(' '))));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('عرض المزيد'), 200, scrollable: find.byType(Scrollable).first);
    // Bring it to mid-screen, clear of the pinned header and the contact bar, before tapping.
    for (var i = 0; i < 5; i++) {
      final y = tester.getCenter(find.text('عرض المزيد')).dy;
      if (y > 150 && y < 450) break;
      await tester.drag(find.byType(Scrollable).first, Offset(0, y > 450 ? -100 : 100));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('عرض المزيد'));
    await tester.pumpAndSettle();
    expect(find.text('عرض أقل'), findsOneWidget);
  });
}
