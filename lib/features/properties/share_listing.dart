import 'package:share_plus/share_plus.dart';

import 'format.dart';
import 'models.dart';

/// Shares the title, price and place only. The phone number is never included: it is
/// revealed to signed-in users through the contact button.
Future<ShareResult> shareListing(PropertyCard p) {
  final where = p.location?.breadcrumbAr;
  final text = [
    p.title,
    formatPrice(p),
    ?where,
    'عبر تطبيق دارنا',
  ].join('\n');
  return SharePlus.instance.share(ShareParams(text: text));
}
