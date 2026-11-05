// The same limits the backend enforces on PATCH /me, with messages for the form.

const maxNameLength = 120;
const maxEmailLength = 254;

// The pattern the backend's validator uses, so the form accepts what the server accepts.
final _email = RegExp(
  r"^(?!\.)(?!.*\.\.)([A-Z0-9_'+\-\.]*)[A-Z0-9_+-]@([A-Z0-9][A-Z0-9\-]*\.)+[A-Z]{2,}$",
  caseSensitive: false,
);

String? validateFullName(String? value) {
  final name = (value ?? '').trim();
  if (name.isEmpty) return 'أدخل اسمك';
  if (name.length < 2) return 'الاسم قصير جداً، أدخل حرفين على الأقل';
  if (name.length > maxNameLength) {
    return 'الاسم طويل جداً، الحد الأقصى $maxNameLength حرفاً';
  }
  return null;
}

/// The email is optional: an empty field is valid and means "no email".
String? validateEmail(String? value) {
  final email = (value ?? '').trim();
  if (email.isEmpty) return null;
  if (email.length > maxEmailLength) return 'البريد الإلكتروني طويل جداً';
  if (!_email.hasMatch(email)) {
    return 'صيغة البريد الإلكتروني غير صحيحة، مثل name@example.com';
  }
  return null;
}
