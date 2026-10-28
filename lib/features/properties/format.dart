import 'package:intl/intl.dart';

import 'models.dart';

const _currencySymbols = {'ILS': '₪', 'USD': r'$', 'JOD': 'د.أ'};
const _rentSuffix = {'DAILY': 'يومياً', 'WEEKLY': 'أسبوعياً', 'MONTHLY': 'شهرياً', 'YEARLY': 'سنوياً'};

const propertyTypeNames = {
  'APARTMENT': 'شقة',
  'HOUSE': 'منزل',
  'VILLA': 'فيلا',
  'LAND': 'أرض',
  'COMMERCIAL': 'محل تجاري',
  'OFFICE': 'مكتب',
  'WAREHOUSE': 'مستودع',
  'BUILDING': 'عمارة',
  'FARM': 'مزرعة',
  'OTHER': 'أخرى',
};

String formatPrice(PropertyCard p) {
  final amount = NumberFormat('#,##0.##', 'en').format(double.parse(p.price));
  final symbol = _currencySymbols[p.currency] ?? p.currency;
  final suffix = p.rentPeriod != null ? ' / ${_rentSuffix[p.rentPeriod] ?? ''}' : '';
  return '$amount $symbol$suffix';
}

String purposeName(String purpose) => purpose == 'RENT' ? 'للإيجار' : 'للبيع';

String formatArea(String sqm) => '${NumberFormat('#,##0.##', 'en').format(double.parse(sqm))} م²';
