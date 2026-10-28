import 'package:dio/dio.dart';

/// An error from the backend (or from reaching it), already carrying a message
/// that can be shown to the user.
class ApiException implements Exception {
  ApiException({required this.status, required this.code, required this.message});

  final int status;
  final String code;
  final String message;

  bool get isNetwork => code == 'NETWORK';
  bool get isUnauthorized => status == 401;

  factory ApiException.fromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is Map) {
      final err = data['error'] as Map;
      final code = (err['code'] as String?) ?? 'UNKNOWN';
      return ApiException(
        status: e.response?.statusCode ?? 0,
        code: code,
        message: _arabic(code) ?? 'حدث خطأ غير متوقع',
      );
    }
    return ApiException(
      status: e.response?.statusCode ?? 0,
      code: 'NETWORK',
      message: 'تعذر الاتصال بالخادم، تحقق من الإنترنت وحاول مرة أخرى',
    );
  }

  @override
  String toString() => 'ApiException($status $code)';
}

/// User-facing messages for the backend's stable error codes.
String? _arabic(String code) => const {
      'VALIDATION_ERROR': 'البيانات المدخلة غير صحيحة',
      'OTP_INVALID': 'رمز التحقق غير صحيح',
      'OTP_EXPIRED': 'انتهت صلاحية الرمز، اطلب رمزاً جديداً',
      'OTP_ATTEMPTS_EXCEEDED': 'تجاوزت عدد المحاولات، اطلب رمزاً جديداً',
      'ACCOUNT_SUSPENDED': 'هذا الحساب موقوف',
      'RATE_LIMITED': 'محاولات كثيرة، انتظر قليلاً ثم حاول مرة أخرى',
      'UNAUTHORIZED': 'يجب تسجيل الدخول',
      'FORBIDDEN': 'غير مسموح لك بهذا الإجراء',
      'CONTACT_HIDDEN': 'المعلن يستقبل الاستفسارات داخل التطبيق فقط',
      'PROPERTY_NOT_FOUND': 'الإعلان غير موجود أو لم يعد منشوراً',
      'PROFILE_INCOMPLETE': 'أضف اسمك في حسابك أولاً',
      'STATUS_CHANGED': 'تغيّرت حالة الإعلان، حدّث الصفحة وحاول مجدداً',
      'INVALID_STATE_TRANSITION': 'هذا الإجراء غير مسموح في الحالة الحالية',
      'MEDIA_LIMIT_REACHED': 'وصلت إلى الحد الأقصى من الصور',
      'INTERNAL_ERROR': 'حدث خطأ في الخادم، حاول لاحقاً',
    }[code];
