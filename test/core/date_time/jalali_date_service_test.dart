import 'package:flutter_test/flutter_test.dart';
import 'package:myflow/core/date_time/jalali_date_parts.dart';
import 'package:myflow/core/date_time/jalali_date_service.dart';

void main() {
  const JalaliDateService dates = JalaliDateService();

  group('طول ماه‌ها', () {
    test('شش ماه اول ۳۱ روز دارند', () {
      for (int month = 1; month <= 6; month++) {
        expect(dates.daysInMonth(1404, month), 31, reason: 'ماه $month');
      }
    });

    test('مهر تا بهمن ۳۰ روز دارند', () {
      for (int month = 7; month <= 11; month++) {
        expect(dates.daysInMonth(1404, month), 30, reason: 'ماه $month');
      }
    });

    test('اسفند در سال کبیسه ۳۰ و در سال غیرکبیسه ۲۹ روز است', () {
      expect(dates.daysInMonth(1399, 12), 30);
      expect(dates.daysInMonth(1403, 12), 30);
      expect(dates.daysInMonth(1400, 12), 29);
      expect(dates.daysInMonth(1404, 12), 29);
    });
  });

  group('سال کبیسه', () {
    test('۱۳۹۹ و ۱۴۰۳ کبیسه‌اند', () {
      expect(dates.isLeapYear(1399), isTrue);
      expect(dates.isLeapYear(1403), isTrue);
    });

    test('۱۴۰۰ تا ۱۴۰۲ و ۱۴۰۴ کبیسه نیستند', () {
      for (final int year in <int>[1400, 1401, 1402, 1404]) {
        expect(dates.isLeapYear(year), isFalse, reason: 'سال $year');
      }
    });
  });

  group('جفت‌های مرجع تبدیل', () {
    final Map<JalaliDateParts, DateTime> references =
        <JalaliDateParts, DateTime>{
          const JalaliDateParts(year: 1399, month: 12, day: 30):
              DateTime(2021, 3, 20),
          const JalaliDateParts(year: 1400, month: 1, day: 1):
              DateTime(2021, 3, 21),
          const JalaliDateParts(year: 1403, month: 1, day: 1):
              DateTime(2024, 3, 20),
          const JalaliDateParts(year: 1403, month: 12, day: 30):
              DateTime(2025, 3, 20),
          const JalaliDateParts(year: 1404, month: 1, day: 1):
              DateTime(2025, 3, 21),
        };

    references.forEach((JalaliDateParts parts, DateTime gregorian) {
      test('$parts ↔ ${gregorian.toIso8601String().split('T').first}', () {
        expect(dates.toDateTime(parts), gregorian);
        expect(dates.partsOf(gregorian), parts);
      });
    });
  });

  group('تبدیل رفت‌وبرگشت', () {
    test('همه‌ی روزهای ۱۳۹۰ تا ۱۴۲۰ بدون تغییر برمی‌گردند', () {
      for (int year = 1390; year <= 1420; year++) {
        for (int month = 1; month <= 12; month++) {
          final int monthLength = dates.daysInMonth(year, month);
          for (int day = 1; day <= monthLength; day++) {
            final JalaliDateParts parts = JalaliDateParts(
              year: year,
              month: month,
              day: day,
            );
            expect(dates.partsOf(dates.toDateTime(parts)), parts);
          }
        }
      }
    });
  });

  group('اعتبارسنجی', () {
    test('روز ناموجود در اسفند غیرکبیسه معتبر نیست', () {
      expect(dates.isValid(1404, 12, 29), isTrue);
      expect(dates.isValid(1404, 12, 30), isFalse);
      expect(dates.isValid(1403, 12, 30), isTrue);
    });

    test('ماه و روز بیرون از محدوده معتبر نیستند', () {
      expect(dates.isValid(1404, 13, 1), isFalse);
      expect(dates.isValid(1404, 0, 1), isFalse);
      expect(dates.isValid(1404, 1, 0), isFalse);
      expect(dates.isValid(1404, 1, 32), isFalse);
    });

    test('ساخت تاریخ نامعتبر خطا می‌دهد', () {
      expect(
        () => dates.toDateTime(
          const JalaliDateParts(year: 1404, month: 12, day: 30),
        ),
        throwsArgumentError,
      );
    });
  });

  group('هفته‌ی شمسی', () {
    test('شروع هفته شنبه است', () {
      final DateTime friday = DateTime(2025, 3, 21); // ۱ فروردین ۱۴۰۴
      final DateTime saturday = dates.startOfWeek(friday);
      expect(dates.weekdayIndex(saturday), 0);
      expect(dates.weekDayName(saturday), 'شنبه');
      expect(dates.isSameJalaliDay(saturday, DateTime(2025, 3, 15)), isTrue);
    });

    test('اختلاف شروع هفته با روز جاری بین ۰ تا ۶ روز است', () {
      for (int offset = 0; offset < 14; offset++) {
        final DateTime day = DateTime(2025, 3, 21).add(Duration(days: offset));
        final DateTime start = dates.startOfWeek(day);
        expect(dates.weekdayIndex(start), 0);
        expect(day.difference(start).inDays, inInclusiveRange(0, 6));
      }
    });
  });

  group('شبکه‌ی ماه', () {
    test('هر سطر هفت خانه دارد و از شنبه شروع می‌شود', () {
      final List<List<JalaliMonthCell>> weeks = dates.monthGrid(1404, 8);
      expect(weeks, isNotEmpty);
      for (final List<JalaliMonthCell> week in weeks) {
        expect(week.length, 7);
        expect(dates.weekdayIndex(week.first.date), 0);
      }
    });

    test('تعداد روزهای ماه داخل شبکه با طول ماه برابر است', () {
      for (int month = 1; month <= 12; month++) {
        final List<JalaliMonthCell> cells = dates
            .monthGrid(1404, month)
            .expand((List<JalaliMonthCell> week) => week)
            .toList();
        final List<JalaliMonthCell> inMonthCells = cells
            .where((JalaliMonthCell c) => c.isInMonth)
            .toList();
        expect(
          inMonthCells.length,
          dates.daysInMonth(1404, month),
          reason: 'ماه $month',
        );
        expect(inMonthCells.first.parts.day, 1, reason: 'ماه $month');
        expect(
          inMonthCells.last.parts.day,
          dates.daysInMonth(1404, month),
          reason: 'ماه $month',
        );
      }
    });

    test('روزهای ماه قبل و بعد کم‌رنگ (isInMonth=false) علامت می‌خورند', () {
      final List<List<JalaliMonthCell>> weeks = dates.monthGrid(1404, 8);
      final List<JalaliMonthCell> firstWeek = weeks.first;
      if (firstWeek.first.parts.month == 8) {
        expect(firstWeek.first.isInMonth, isTrue);
      } else {
        expect(firstWeek.first.isInMonth, isFalse);
      }
    });
  });

  group('جابه‌جایی ماه', () {
    test('روز ۳۱ به ماه ۳۰ روزه می‌رود و روی آخرین روز تنظیم می‌شود', () {
      final DateTime endOfShahrivar = dates.toDateTime(
        const JalaliDateParts(year: 1404, month: 6, day: 31),
        hour: 10,
      );
      final DateTime nextMonth = dates.addMonths(endOfShahrivar, 1);
      expect(
        dates.partsOf(nextMonth),
        const JalaliDateParts(year: 1404, month: 7, day: 30),
      );
      expect(nextMonth.hour, 10, reason: 'ساعت باید حفظ شود');
    });

    test('عبور از اسفند به فروردین سال بعد درست است', () {
      final DateTime lastDayOfYear = dates.toDateTime(
        const JalaliDateParts(year: 1404, month: 12, day: 29),
      );
      expect(
        dates.partsOf(dates.addMonths(lastDayOfYear, 1)),
        const JalaliDateParts(year: 1405, month: 1, day: 29),
      );
    });

    test('رفتن به ماه قبل از فروردین، سال را کاهش می‌دهد', () {
      final DateTime firstDay = dates.toDateTime(
        const JalaliDateParts(year: 1404, month: 1, day: 31),
      );
      expect(
        dates.partsOf(dates.addMonths(firstDay, -1)),
        const JalaliDateParts(year: 1403, month: 12, day: 30),
      );
    });
  });

  group('مرز نیمه‌شب', () {
    test('ساعت ۰۰:۳۰ و ۲۳:۳۰ هر دو در همان روز شمسی هستند', () {
      final DateTime earlyMorning = DateTime(2025, 3, 20, 0, 30);
      final DateTime lateNight = DateTime(2025, 3, 20, 23, 30);
      expect(
        dates.partsOf(earlyMorning),
        const JalaliDateParts(year: 1403, month: 12, day: 30),
      );
      expect(
        dates.partsOf(lateNight),
        const JalaliDateParts(year: 1403, month: 12, day: 30),
      );
      expect(dates.isSameJalaliDay(earlyMorning, lateNight), isTrue);
    });

    test('یک ساعت بعد از نیمه‌شب، روز شمسی عوض می‌شود', () {
      expect(
        dates.partsOf(DateTime(2025, 3, 21, 0, 30)),
        const JalaliDateParts(year: 1404, month: 1, day: 1),
      );
      expect(
        dates.partsOf(DateTime(2025, 3, 21, 0, 0)),
        const JalaliDateParts(year: 1404, month: 1, day: 1),
      );
      expect(
        dates.partsOf(DateTime(2025, 3, 20, 23, 59)),
        const JalaliDateParts(year: 1403, month: 12, day: 30),
      );
    });
  });

  group('نمایش', () {
    test('قالب کوتاه و بلند با ارقام فارسی', () {
      final DateTime newYear = DateTime(2025, 3, 21); // ۱ فروردین ۱۴۰۴
      expect(dates.formatShort(newYear), '۱۴۰۴/۰۱/۰۱');
      expect(dates.formatLong(newYear), '۱ فروردین ۱۴۰۴');
      expect(dates.formatMonthYear(1404, 8), 'آبان ۱۴۰۴');
    });

    test('نام ماه و روز هفته', () {
      expect(dates.monthName(1), 'فروردین');
      expect(dates.monthName(12), 'اسفند');
      expect(dates.weekDayName(DateTime(2025, 3, 21)), 'جمعه');
    });

    test('قالب ساعت دو رقمی', () {
      expect(dates.formatTime(DateTime(2025, 3, 21, 9, 5)), '۰۹:۰۵');
      expect(
        dates.formatTime(DateTime(2025, 3, 21, 9, 5), usePersianDigits: false),
        '09:05',
      );
    });
  });
}
