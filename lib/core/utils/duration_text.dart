import 'persian_digits.dart';

/// «۲ ساعت و ۱۵ دقیقه» برای مدت‌های دقیقه‌ای.
///
/// یک منبع واحد تا تایم‌لاین و داشبورد یک بازه را با دو قالب متفاوت نشان
/// ندهند.
String formatDurationLabel(int minutes) {
  if (minutes <= 0) {
    return '۰ دقیقه';
  }
  final int hours = minutes ~/ 60;
  final int rest = minutes % 60;
  final List<String> parts = <String>[
    if (hours > 0) '${PersianDigits.fromInt(hours)} ساعت',
    if (rest > 0) '${PersianDigits.fromInt(rest)} دقیقه',
  ];
  return parts.join(' و ');
}
