import '../../../shared/enums/app_enums.dart';

/// دامنه‌ی اعمال ویرایش/حذف روی یک سری تکراری (بخش ۱۱.۶ و ۱۱.۹ سند).
enum RecurrenceEditScope {
  /// فقط همین نمونه؛ با یک ردیف استثنا ذخیره می‌شود.
  thisOnly('این مورد'),

  /// این نمونه و نمونه‌های بعدی؛ سری در روز قبل از این نمونه پایان می‌یابد
  /// و سری جدیدی از همین نمونه شروع می‌شود.
  thisAndFollowing('این و بعدی‌ها'),

  /// کل سری؛ ردیف master و قاعده به‌روزرسانی می‌شوند.
  allSeries('کل سری');

  const RecurrenceEditScope(this.label);

  final String label;
}

/// قاعده‌ی تکرار در لایه‌ی دامنه (بخش ۱۰.۷ و ۱۱.۶).
///
/// [startLocalDate] تاریخ محلی اولین نمونه است (بدون ساعت) و [startMinutes]
/// ساعت دیواری شروع به دقیقه‌ی روز. تکرار ماهانه/سالانه بر اساس تقویم شمسی
/// محاسبه می‌شود، پس [monthDay] و [monthOfYear] هم شمسی هستند.
class RecurrenceRule {
  const RecurrenceRule({
    required this.id,
    required this.frequency,
    required this.startLocalDate,
    required this.startMinutes,
    required this.timezoneId,
    this.interval = 1,
    this.weekdays = const <int>{},
    this.monthDay,
    this.monthOfYear,
    this.untilLocalDate,
    this.countLimit,
  });

  final String id;
  final RecurrenceFrequency frequency;

  /// تاریخ محلی اولین نمونه (بدون ساعت).
  final DateTime startLocalDate;

  /// ساعت دیواری شروع، به دقیقه‌ی روز (۰ تا ۱۴۳۹).
  final int startMinutes;

  /// هر چند واحد تکرار شود (`interval_value`؛ حداقل ۱).
  final int interval;

  /// روزهای هفته برای تکرار هفتگی؛ ۰ = شنبه … ۶ = جمعه.
  ///
  /// خالی یعنی همان روز هفته‌ی [startLocalDate].
  final Set<int> weekdays;

  /// روز ماه شمسی؛ خالی یعنی روز [startLocalDate].
  final int? monthDay;

  /// ماه شمسی برای تکرار سالانه (۱ تا ۱۲).
  final int? monthOfYear;

  /// آخرین روز مجاز سری (شامل خودش)؛ `null` یعنی بدون پایان.
  final DateTime? untilLocalDate;

  /// سقف تعداد نمونه‌ها از ابتدای سری؛ `null` یعنی بی‌نهایت.
  final int? countLimit;

  final String timezoneId;

  bool get isWeekly => frequency == RecurrenceFrequency.weekly;

  bool get hasEnd => untilLocalDate != null || countLimit != null;

  /// برچسب فارسی کوتاه برای نمایش در جزئیات رویداد.
  String get frequencyLabel {
    final String unit = switch (frequency) {
      RecurrenceFrequency.daily => 'روز',
      RecurrenceFrequency.weekly => 'هفته',
      RecurrenceFrequency.monthly => 'ماه',
      RecurrenceFrequency.yearly => 'سال',
    };
    return interval == 1 ? 'هر $unit' : 'هر $interval $unit';
  }
}
