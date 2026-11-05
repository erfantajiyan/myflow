import 'package:flutter/painting.dart';

/// پالت رنگ MyFlow — مطابق بخش ۶.۱ سند محصول.
///
/// تمام رنگ‌های رابط باید از این کلاس خوانده شوند تا در همه‌ی صفحات یکسان
/// بمانند. رنگ مسئولیت‌ها داده‌ی کاربر است و در دیتابیس ذخیره می‌شود؛
/// مقادیر اینجا فقط نقش «رنگ‌های پایه‌ی رابط» را دارند.
abstract final class AppColors {
  // پس‌زمینه و سطوح
  static const Color background = Color(0xFF0B0F14);
  static const Color surface = Color(0xFF141B24);
  static const Color surfaceHigh = Color(0xFF1B2633);

  // متن
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);

  // رنگ‌های معنایی
  static const Color accent = Color(0xFF5BA8FF);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // مرزها
  static const Color border = Color(0xFF263241);

  // رنگ متن/آیکون روی سطوح رنگی روشن
  static const Color onAccent = Color(0xFF06121F);
  static const Color onSuccess = Color(0xFF07160C);
  static const Color onWarning = Color(0xFF1A1204);
  static const Color onError = Color(0xFF1C0707);

  /// رنگ‌های پیشنهادی seed برای مسئولیت‌های اولیه (بخش ۵.۳ سند).
  /// این‌ها فقط مقادیر پیش‌فرض هنگام ساخت مسئولیت‌اند، نه ثابت‌های کد.
  static const Color responsibilityStudent = Color(0xFF3B82F6);
  static const Color responsibilityViceChancellor = Color(0xFF22A06B);
  static const Color responsibilityAssociation = Color(0xFFA855F7);
  static const Color responsibilityPersonal = Color(0xFF64748B);
}
