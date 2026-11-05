import 'package:shamsi_date/shamsi_date.dart';

import '../utils/persian_digits.dart';
import 'jalali_date_parts.dart';

/// یک خانه از شبکه‌ی ماه شمسی.
class JalaliMonthCell {
  const JalaliMonthCell({
    required this.date,
    required this.parts,
    required this.isInMonth,
  });

  /// تاریخ میلادی محلی متناظر با این خانه (برای ذخیره و مقایسه).
  final DateTime date;

  /// اجزای تاریخ شمسی این خانه.
  final JalaliDateParts parts;

  /// آیا این خانه به ماه جاری تعلق دارد یا روزهای ماه قبل/بعد است.
  final bool isInMonth;

  @override
  String toString() => 'JalaliMonthCell($parts, inMonth: $isInMonth)';
}

/// تنها لایه‌ی مجاز برای کار با تقویم شمسی — بخش ۱۲.۱ و ۲۰.۱۳ سند.
///
/// هیچ بخش دیگری از برنامه نباید پکیج `shamsi_date` را import کند؛ بنابراین
/// تعویض کتابخانه فقط همین فایل را تغییر می‌دهد.
///
/// قاعده‌ی ثابت: همه‌ی تبدیل‌ها روی **تاریخ و ساعت محلی** انجام می‌شوند، نه
/// UTC؛ وگرنه رویداد ساعت ۰۰:۳۰ به روز قبل می‌رود (بخش ۱۲.۱).
class JalaliDateService {
  const JalaliDateService();

  /// ایندکس شنبه در هفته‌ی فارسی (۰ = شنبه ... ۶ = جمعه).
  static const int saturdayIndex = 0;

  /// تعداد روزهای هفته.
  static const int daysPerWeek = 7;

  // ---------------------------------------------------------------------------
  // تبدیل‌ها
  // ---------------------------------------------------------------------------

  /// اجزای شمسی یک لحظه‌ی محلی.
  JalaliDateParts partsOf(DateTime dateTime) {
    final Jalali jalali = Jalali.fromDateTime(dateTime);
    return JalaliDateParts(
      year: jalali.year,
      month: jalali.month,
      day: jalali.day,
    );
  }

  /// تاریخ میلادی محلی متناظر با اجزای شمسی.
  ///
  /// اگر تاریخ نامعتبر باشد [ArgumentError] پرتاب می‌شود؛ ورودی کاربر باید
  /// قبل از رسیدن به این لایه اعتبارسنجی شود.
  DateTime toDateTime(
    JalaliDateParts parts, {
    int hour = 0,
    int minute = 0,
    int second = 0,
  }) {
    if (!isValid(parts.year, parts.month, parts.day)) {
      throw ArgumentError.value(
        parts.toString(),
        'parts',
        'تاریخ شمسی نامعتبر است',
      );
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw ArgumentError('ساعت یا دقیقه‌ی نامعتبر: $hour:$minute');
    }
    return Jalali(
      parts.year,
      parts.month,
      parts.day,
      hour,
      minute,
      second,
    ).toDateTime();
  }

  /// آیا این تاریخ شمسی در تقویم وجود دارد؟
  bool isValid(int year, int month, int day) {
    if (year < 1 || month < 1 || month > 12 || day < 1) return false;
    return day <= daysInMonth(year, month);
  }

  // ---------------------------------------------------------------------------
  // پرس‌وجوهای تقویم
  // ---------------------------------------------------------------------------

  /// تعداد روزهای یک ماه شمسی: ۳۱ برای شش ماه اول، ۳۰ برای مهر تا بهمن و
  /// ۲۹ یا ۳۰ برای اسفند (بسته به کبیسه بودن سال).
  int daysInMonth(int year, int month) {
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'ماه باید بین ۱ و ۱۲ باشد');
    }
    return Jalali(year, month, 1).monthLength;
  }

  /// کبیسه بودن سال شمسی (۱۳۹۹ و ۱۴۰۳ کبیسه‌اند).
  bool isLeapYear(int year) => Jalali(year, 1, 1).isLeapYear();

  /// ایندکس روز هفته با شروع شنبه: ۰ = شنبه ... ۶ = جمعه.
  int weekdayIndex(DateTime dateTime) =>
      Jalali.fromDateTime(dateTime).weekDay - 1;

  /// ابتدای هفته‌ی شمسی (شنبه) برای تاریخ داده‌شده، با حفظ ساعت.
  DateTime startOfWeek(DateTime dateTime) {
    final int offset = weekdayIndex(dateTime);
    return addDays(dateTime, -offset);
  }

  /// افزودن روز با حفظ ساعت دیواری.
  DateTime addDays(DateTime dateTime, int days) {
    if (days == 0) return dateTime;
    return Jalali.fromDateTime(dateTime).addDays(days).toDateTime();
  }

  /// افزودن ماه در تقویم شمسی.
  ///
  /// اگر روز جاری در ماه مقصد وجود نداشته باشد (مثلاً ۳۱ فروردین + ۱ ماه),
  /// مطابق سیاست سند (بخش ۱۱.۴) روی آخرین روز معتبر همان ماه تنظیم می‌شود.
  DateTime addMonths(DateTime dateTime, int months) {
    final Jalali jalali = Jalali.fromDateTime(dateTime);
    final int zeroBasedMonth = (jalali.year * 12) + (jalali.month - 1) + months;
    final int targetYear = zeroBasedMonth ~/ 12;
    final int targetMonth = (zeroBasedMonth % 12) + 1;
    final int targetDay = jalali.day.clamp(1, daysInMonth(targetYear, targetMonth));
    return Jalali(
      targetYear,
      targetMonth,
      targetDay,
      jalali.hour,
      jalali.minute,
      jalali.second,
    ).toDateTime();
  }

  /// شبکه‌ی ماه شمسی، سطرها از شنبه تا جمعه.
  ///
  /// خروجی هفته‌های کامل است (۵ یا ۶ سطر) و روزهای ماه قبل/بعد هم داخل آن
  /// هستند تا تقویم همیشه مستطیل بماند.
  List<List<JalaliMonthCell>> monthGrid(int year, int month) {
    final int monthLength = daysInMonth(year, month);
    final DateTime firstDay = toDateTime(
      JalaliDateParts(year: year, month: month, day: 1),
    );
    final int leadingDays = weekdayIndex(firstDay);
    final int totalCells = leadingDays + monthLength;
    final int weekCount = (totalCells / daysPerWeek).ceil();

    final List<List<JalaliMonthCell>> weeks = <List<JalaliMonthCell>>[];
    DateTime cursor = addDays(firstDay, -leadingDays);
    for (int week = 0; week < weekCount; week++) {
      final List<JalaliMonthCell> days = <JalaliMonthCell>[];
      for (int day = 0; day < daysPerWeek; day++) {
        final JalaliDateParts parts = partsOf(cursor);
        days.add(
          JalaliMonthCell(
            date: cursor,
            parts: parts,
            isInMonth: parts.year == year && parts.month == month,
          ),
        );
        cursor = addDays(cursor, 1);
      }
      weeks.add(days);
    }
    return weeks;
  }

  /// آیا دو لحظه در یک روز شمسی محلی قرار دارند؟
  bool isSameJalaliDay(DateTime a, DateTime b) {
    final JalaliDateParts first = partsOf(a);
    final JalaliDateParts second = partsOf(b);
    return first == second;
  }

  // ---------------------------------------------------------------------------
  // نمایش
  // ---------------------------------------------------------------------------

  /// نام ماه شمسی، مثلاً «آبان».
  String monthName(int month) {
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'ماه باید بین ۱ و ۱۲ باشد');
    }
    return Jalali(1400, month, 1).formatter.mN;
  }

  /// نام روز هفته، مثلاً «یک‌شنبه» (با نیم‌فاصله).
  String weekDayName(DateTime dateTime) =>
      Jalali.fromDateTime(dateTime).formatter.wN.replaceAll(' ', '\u200C');

  /// `۱۴۰۴/۰۸/۱۰`
  String formatShort(DateTime dateTime, {bool usePersianDigits = true}) {
    final Jalali jalali = Jalali.fromDateTime(dateTime);
    final String value =
        '${jalali.formatter.yyyy}/${jalali.formatter.mm}/${jalali.formatter.dd}';
    return usePersianDigits ? PersianDigits.convert(value) : value;
  }

  /// `۱۰ آبان ۱۴۰۴`
  String formatLong(DateTime dateTime, {bool usePersianDigits = true}) {
    final Jalali jalali = Jalali.fromDateTime(dateTime);
    final String value =
        '${jalali.formatter.d} ${jalali.formatter.mN} ${jalali.formatter.yyyy}';
    return usePersianDigits ? PersianDigits.convert(value) : value;
  }

  /// `آبان ۱۴۰۴`
  String formatMonthYear(int year, int month, {bool usePersianDigits = true}) {
    final String value = '${monthName(month)} $year';
    return usePersianDigits ? PersianDigits.convert(value) : value;
  }

  /// `۰۹:۳۰` یا `۹:۳۰` — قالب ۲۴ ساعته‌ی پایه.
  String formatTime(
    DateTime dateTime, {
    bool usePersianDigits = true,
    bool padHour = true,
  }) {
    final String hour = padHour
        ? dateTime.hour.toString().padLeft(2, '0')
        : dateTime.hour.toString();
    final String value = '$hour:${dateTime.minute.toString().padLeft(2, '0')}';
    return usePersianDigits ? PersianDigits.convert(value) : value;
  }
}
