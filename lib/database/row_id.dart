import 'dart:math' as math;

int _sequence = 0;
final math.Random _random = math.Random();

/// شناسه‌ی یکتای ردیف‌های جدید.
///
/// فقط `DateTime.now()` کافی نیست: ساعت ویندوز دقت میلی‌ثانیه دارد، پس دو
/// درج سریع (مثلاً ذخیره‌ی چند وظیفه در یک تست یا ثبت پشت‌سرهم) می‌تواند
/// شناسه‌ی یکسان بسازد و با `UNIQUE constraint failed: *.id` بشکند. ترکیب
/// زمان + شمارنده‌ی فرایند + عدد تصادفی این برخورد را عملاً حذف می‌کند.
String newRowId(String prefix) {
  _sequence = (_sequence + 1) & 0xFFFFFF;
  final String stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final String random = _random.nextInt(1 << 20).toRadixString(36);
  return '$prefix-$stamp-$random-${_sequence.toRadixString(36)}';
}
