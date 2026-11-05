/// مقیاس فاصله‌گذاری و گردی گوشه‌ها — بخش ۶.۳ سند.
///
/// واحد پایه ۴dp است و همه‌ی فاصله‌ها مضربی از آن هستند.
abstract final class AppSpacing {
  static const double unit = 4;

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;

  /// padding داخلی کارت‌ها (سند: ۱۲ تا ۱۶)
  static const double cardPadding = 16;

  /// فاصله بین بخش‌های صفحه (سند: ۱۶ تا ۲۴)
  static const double sectionGap = 20;

  /// حداقل ارتفاع کنترل لمسی (سند: ۴۴ تا ۴۸)
  static const double minTouchTarget = 48;
}

/// شعاع گوشه‌ها — بخش ۶.۳ سند (۱۲ تا ۱۶ برای کارت).
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 999;
}
