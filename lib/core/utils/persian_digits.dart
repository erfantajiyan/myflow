/// ارقام فارسی — برای نمایش ساعت، تاریخ و شمارنده‌ها.
///
/// تبدیل فقط در لایه‌ی نمایش انجام می‌شود؛ مقادیر ذخیره‌شده همیشه لاتین
/// باقی می‌مانند تا منطق و دیتابیس مستقل از قالب نمایش بماند.
abstract final class PersianDigits {
  static const List<String> _digits = [
    '۰',
    '۱',
    '۲',
    '۳',
    '۴',
    '۵',
    '۶',
    '۷',
    '۸',
    '۹',
  ];

  /// ارقام لاتین را به فارسی تبدیل می‌کند و بقیه‌ی نویسه‌ها را دست نمی‌زند.
  static String convert(String input) {
    final StringBuffer buffer = StringBuffer();
    for (final int codeUnit in input.codeUnits) {
      if (codeUnit >= 0x30 && codeUnit <= 0x39) {
        buffer.write(_digits[codeUnit - 0x30]);
      } else {
        buffer.writeCharCode(codeUnit);
      }
    }
    return buffer.toString();
  }

  /// عدد را به رشته‌ی فارسی تبدیل می‌کند (بدون جداکننده‌ی هزارگان).
  static String fromInt(int value) => convert(value.toString());

  /// ارقام فارسی/عربی را به لاتین برمی‌گرداند تا `int.tryParse` و پارسرهای
  /// تاریخ/ساعت بتوانند ورودی کاربر را بخوانند.
  ///
  /// [convert] یک‌طرفه است (لاتین به فارسی)؛ بدون این تابع، ساعت «۱۰:۱۵»
  /// واردشده توسط کاربر قابل تجزیه نبود و فرم خطای «ساعت را به شکل ۱۰:۳۰
  /// وارد کنید» می‌داد.
  static String toLatin(String input) {
    const String persian = '۰۱۲۳۴۵۶۷۸۹';
    const String arabic = '٠١٢٣٤٥٦٧٨٩';
    final StringBuffer buffer = StringBuffer();
    for (final int rune in input.runes) {
      final String char = String.fromCharCode(rune);
      final int persianIndex = persian.indexOf(char);
      if (persianIndex >= 0) {
        buffer.write(persianIndex);
        continue;
      }
      final int arabicIndex = arabic.indexOf(char);
      if (arabicIndex >= 0) {
        buffer.write(arabicIndex);
        continue;
      }
      buffer.write(char);
    }
    return buffer.toString();
  }

  /// دو رقم با صفر ابتدایی: `۵` می‌شود `۰۵`.
  static String padded2(int value) =>
      convert(value.toString().padLeft(2, '0'));
}
