/// تاریخ «بدون ساعت» — بخش ۲۰.۴ سند.
///
/// فیلدهای تاریخ‌محور (سررسید وظیفه، شروع/پایان پروژه) هرگز به timestamp و
/// نیمه‌شب UTC تبدیل نمی‌شوند؛ به شکل متن میلادی محلی `YYYY-MM-DD` ذخیره
/// می‌شوند تا منطقه‌ی زمانی روز را جابه‌جا نکند.
library;

/// `2026-11-05`
String formatDateOnly(DateTime date) {
  final String year = date.year.toString().padLeft(4, '0');
  final String month = date.month.toString().padLeft(2, '0');
  final String day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

/// تجزیه‌ی `YYYY-MM-DD` به تاریخ محلی؛ ورودی نامعتبر `null` می‌دهد.
DateTime? parseDateOnly(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  final List<String> parts = value.trim().split('-');
  if (parts.length != 3) {
    return null;
  }
  final int? year = int.tryParse(parts[0]);
  final int? month = int.tryParse(parts[1]);
  final int? day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) {
    return null;
  }
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    return null;
  }
  final DateTime parsed = DateTime(year, month, day);
  // ۲۰۲۶-۰۲-۳۱ نباید به ۳ مارس تبدیل شود.
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return parsed;
}
