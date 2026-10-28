import 'dart:typed_data';

import 'package:darna/core/time_ago.dart';
import 'package:darna/features/auth/login_screen.dart';
import 'package:darna/features/listings/listing_repository.dart';
import 'package:darna/features/properties/format.dart';
import 'package:darna/features/properties/models.dart';
import 'package:darna/features/properties/property_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizePhone', () {
    test('accepts the formats people actually type', () {
      expect(normalizePhone('0599123456'), '+970599123456');
      expect(normalizePhone('0599 123 456'), '+970599123456');
      expect(normalizePhone('599123456'), '+970599123456');
      expect(normalizePhone('00970599123456'), '+970599123456');
      expect(normalizePhone('+970599123456'), '+970599123456');
      expect(normalizePhone('+962791234567'), '+962791234567');
    });

    test('rejects what the backend would reject', () {
      expect(normalizePhone(''), isNull);
      expect(normalizePhone('12345'), isNull);
      expect(normalizePhone('+0123456789'), isNull);
    });
  });

  group('listing models and formatting', () {
    final json = <String, dynamic>{
      'id': 'a1',
      'title': 'شقة للبيع',
      'purpose': 'RENT',
      'propertyType': 'APARTMENT',
      'price': '1500.00',
      'currency': 'ILS',
      'rentPeriod': 'MONTHLY',
      'areaSqm': '120.50',
      'bedrooms': 3,
      'bathrooms': null,
      'coverThumbnailUrl': null,
      'location': {'id': 'l1', 'nameAr': 'رام الله', 'breadcrumbAr': 'رام الله والبيرة › رام الله'},
      'office': null,
      'publishedAt': '2026-10-26T10:00:00.000Z',
    };

    test('parses a card from the API response', () {
      final p = PropertyCard.fromJson(json);
      expect(p.bedrooms, 3);
      expect(p.bathrooms, isNull);
      expect(p.location!.breadcrumbAr, contains('رام الله'));
      expect(p.isFavorite, isFalse); // absent for anonymous callers
    });

    test('formats prices with currency and rent period', () {
      expect(formatPrice(PropertyCard.fromJson(json)), '1,500 ₪ / شهرياً');
      final sale = PropertyCard.fromJson({...json, 'purpose': 'SALE', 'rentPeriod': null, 'price': '250000.00', 'currency': 'USD'});
      expect(formatPrice(sale), r'250,000 $');
      expect(formatArea('120.50'), '120.5 م²');
    });
  });

  group('sniffImageType', () {
    test('recognises the three accepted formats by their first bytes', () {
      expect(sniffImageType(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0])), 'image/jpeg');
      expect(sniffImageType(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])), 'image/png');
      expect(
        sniffImageType(Uint8List.fromList([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits])),
        'image/webp',
      );
    });

    test('rejects anything else, whatever the file name says', () {
      expect(sniffImageType(Uint8List.fromList('GIF89a....'.codeUnits)), isNull);
      expect(sniffImageType(Uint8List(0)), isNull);
    });
  });

  group('timeAgoAr', () {
    final now = DateTime(2026, 10, 28, 12);
    test('uses the Arabic forms for one, two and several', () {
      expect(timeAgoAr(now.subtract(const Duration(seconds: 20)), now: now), 'الآن');
      expect(timeAgoAr(now.subtract(const Duration(minutes: 1)), now: now), 'قبل دقيقة');
      expect(timeAgoAr(now.subtract(const Duration(minutes: 2)), now: now), 'قبل دقيقتين');
      expect(timeAgoAr(now.subtract(const Duration(minutes: 5)), now: now), 'قبل 5 دقائق');
      expect(timeAgoAr(now.subtract(const Duration(hours: 3)), now: now), 'قبل 3 ساعات');
      expect(timeAgoAr(now.subtract(const Duration(days: 2)), now: now), 'قبل يومين');
    });

    test('falls back to a date after a week', () {
      expect(timeAgoAr(now.subtract(const Duration(days: 10)), now: now), '2026/10/18');
    });
  });

  group('SearchFilters', () {
    test('counts only the filters from the sheet', () {
      expect(const SearchFilters(purpose: 'SALE', locationId: 'x').activeCount, 0);
      final f = const SearchFilters().copyWith(
        propertyTypes: {'HOUSE'},
        minPrice: '1000',
        minBedrooms: 2,
        sort: 'price_asc',
      );
      expect(f.activeCount, 4);
    });

    test('clearing the sheet keeps the purpose and location', () {
      final f = const SearchFilters(purpose: 'RENT', locationId: 'x', locationName: 'نابلس')
          .copyWith(propertyTypes: {'APARTMENT'}, maxPrice: '900', sort: 'price_desc');
      final cleared = f.clearedSheet();
      expect(cleared.activeCount, 0);
      expect(cleared.purpose, 'RENT');
      expect(cleared.locationName, 'نابلس');
    });
  });
}
