/// "الآن", "قبل 5 دقائق", "قبل ساعتين", "قبل 3 أيام", then a plain date.
String timeAgoAr(DateTime when, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(when.toLocal());
  if (diff.inSeconds < 60) return 'الآن';
  if (diff.inMinutes < 60) return 'قبل ${_unit(diff.inMinutes, 'دقيقة', 'دقيقتين', 'دقائق')}';
  if (diff.inHours < 24) return 'قبل ${_unit(diff.inHours, 'ساعة', 'ساعتين', 'ساعات')}';
  if (diff.inDays < 7) return 'قبل ${_unit(diff.inDays, 'يوم', 'يومين', 'أيام')}';
  return formatDate(when);
}

/// 2026/10/28. Built by hand: DateFormat needs its locale data loaded first, and a
/// missing load is a runtime crash rather than a compile error.
String formatDate(DateTime when) {
  final d = when.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}/${two(d.month)}/${two(d.day)}';
}

// Arabic counts: 1 and 2 have their own forms; 3-10 plural; above that the singular noun.
String _unit(int n, String one, String two, String few) {
  if (n == 1) return one;
  if (n == 2) return two;
  if (n <= 10) return '$n $few';
  return '$n $one';
}
