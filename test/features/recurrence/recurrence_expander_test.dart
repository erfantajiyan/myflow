import 'package:flutter_test/flutter_test.dart';
import 'package:myflow/core/date_time/jalali_date_parts.dart';
import 'package:myflow/core/date_time/jalali_date_service.dart';
import 'package:myflow/features/recurrence/domain/event_occurrence.dart';
import 'package:myflow/features/recurrence/domain/recurrence_expander.dart';
import 'package:myflow/features/recurrence/domain/recurrence_rule.dart';
import 'package:myflow/shared/enums/app_enums.dart';

const JalaliDateService dates = JalaliDateService();

DateTime jalali(int year, int month, int day, [int hour = 0, int minute = 0]) =>
    dates.toDateTime(
      JalaliDateParts(year: year, month: month, day: day),
      hour: hour,
      minute: minute,
    );

RecurrenceRule rule({
  RecurrenceFrequency frequency = RecurrenceFrequency.weekly,
  DateTime? start,
  int startMinutes = 10 * 60,
  int interval = 1,
  Set<int> weekdays = const <int>{},
  int? monthDay,
  int? monthOfYear,
  DateTime? until,
  int? countLimit,
}) {
  return RecurrenceRule(
    id: 'rule-1',
    frequency: frequency,
    startLocalDate: start ?? jalali(1405, 8, 1),
    startMinutes: startMinutes,
    timezoneId: 'Asia/Tehran',
    interval: interval,
    weekdays: weekdays,
    monthDay: monthDay,
    monthOfYear: monthOfYear,
    untilLocalDate: until,
    countLimit: countLimit,
  );
}

List<EventOccurrence> expand(
  RecurrenceRule value, {
  DateTime? rangeStart,
  DateTime? rangeEnd,
  Duration duration = const Duration(hours: 1),
  Map<String, OccurrenceException> exceptions =
      const <String, OccurrenceException>{},
}) {
  final DateTime start = value.startLocalDate;
  return expandOccurrences(
    rule: value,
    masterEventId: 'evt-master',
    masterStartAtUtc: DateTime(
      start.year,
      start.month,
      start.day,
      value.startMinutes ~/ 60,
      value.startMinutes % 60,
    ).toUtc(),
    masterEndAtUtc: DateTime(
      start.year,
      start.month,
      start.day,
      value.startMinutes ~/ 60,
      value.startMinutes % 60,
    ).toUtc().add(duration),
    rangeStartLocal: rangeStart ?? jalali(1405, 8, 1),
    rangeEndLocal: rangeEnd ?? jalali(1405, 9, 1),
    dates: dates,
    exceptions: exceptions,
  );
}

int jalaliDay(EventOccurrence occurrence) =>
    dates.partsOf(occurrence.startLocal).day;

void main() {
  group('expandOccurrences', () {
    test('تکرار هفتگی همه‌ی شنبه‌های ماه را می‌سازد', () {
      // ۱۴۰۵/۰۸/۰۱ شنبه است.
      final List<EventOccurrence> occurrences = expand(
        rule(
          weekdays: <int>{0},
          start: jalali(1405, 8, 1),
        ),
      );

      expect(occurrences, hasLength(5)); // ۲، ۹، ۱۶، ۲۳ و ۳۰ آبان
      expect(
        occurrences.map((EventOccurrence o) => jalaliDay(o)),
        <int>[2, 9, 16, 23, 30],
      );
      expect(occurrences.first.startLocal.hour, 10);
      // کلید نمونه، تاریخ محلی میلادی با قالب YYYY-MM-DD است.
      expect(
        occurrences.first.instanceKey,
        matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')),
      );
      expect(occurrences.first.id, contains('evt-master@'));
    });

    test('interval در تکرار روزانه رعایت می‌شود', () {
      final List<EventOccurrence> occurrences = expand(
        rule(
          frequency: RecurrenceFrequency.daily,
          interval: 3,
          start: jalali(1405, 8, 1),
        ),
        rangeStart: jalali(1405, 8, 1),
        rangeEnd: jalali(1405, 8, 11),
      );

      expect(
        occurrences.map((EventOccurrence o) => jalaliDay(o)),
        <int>[1, 4, 7, 10],
      );
    });

    test('تکرار ماهانه روزی که در ماه وجود ندارد، آن ماه را رد می‌کند', () {
      // فقط فروردین تا شهریور ۳۱ روزه‌اند؛ روز ۳۱ در مهر تا اسفند وجود ندارد.
      final List<EventOccurrence> occurrences = expand(
        rule(
          frequency: RecurrenceFrequency.monthly,
          monthDay: 31,
          start: jalali(1405, 6, 31),
        ),
        rangeStart: jalali(1405, 6, 1),
        rangeEnd: jalali(1406, 2, 1),
      );

      expect(
        occurrences.map((EventOccurrence o) => dates.partsOf(o.startLocal).month),
        <int>[6, 1],
      );
    });

    test('تکرار سالانه با ماه و روز شمسی', () {
      final List<EventOccurrence> occurrences = expand(
        rule(
          frequency: RecurrenceFrequency.yearly,
          monthOfYear: 1,
          monthDay: 1,
          start: jalali(1405, 1, 1),
        ),
        rangeStart: jalali(1405, 1, 1),
        rangeEnd: jalali(1408, 1, 1),
      );

      expect(
        occurrences.map((EventOccurrence o) => dates.partsOf(o.startLocal).year),
        <int>[1405, 1406, 1407],
      );
    });

    test('count_limit از ابتدای سری شمرده می‌شود نه از بازه', () {
      final List<EventOccurrence> occurrences = expand(
        rule(
          frequency: RecurrenceFrequency.daily,
          start: jalali(1405, 8, 1),
          countLimit: 3,
        ),
        rangeStart: jalali(1405, 8, 10),
        rangeEnd: jalali(1405, 8, 20),
      );

      expect(occurrences, isEmpty);
    });

    test('until_local_date شامل خود روز است و بعد از آن نمونه‌ای نیست', () {
      final List<EventOccurrence> occurrences = expand(
        rule(
          frequency: RecurrenceFrequency.daily,
          start: jalali(1405, 8, 1),
          until: jalali(1405, 8, 3),
        ),
        rangeStart: jalali(1405, 8, 1),
        rangeEnd: jalali(1405, 9, 1),
      );

      expect(occurrences, hasLength(3));
    });

    test('استثنا جای نمونه‌ی محاسبه‌شده را می‌گیرد و لغوشده حذف می‌شود', () {
      final List<EventOccurrence> base = expand(
        rule(frequency: RecurrenceFrequency.daily, start: jalali(1405, 8, 1)),
        rangeStart: jalali(1405, 8, 1),
        rangeEnd: jalali(1405, 8, 4),
      );
      expect(base, hasLength(3));

      final String secondKey = base[1].instanceKey;
      final String thirdKey = base[2].instanceKey;

      final List<EventOccurrence> withException = expand(
        rule(frequency: RecurrenceFrequency.daily, start: jalali(1405, 8, 1)),
        rangeStart: jalali(1405, 8, 1),
        rangeEnd: jalali(1405, 8, 4),
        exceptions: <String, OccurrenceException>{
          secondKey: OccurrenceException(
            eventId: 'evt-exception',
            instanceKey: secondKey,
            startAtUtc: jalali(1405, 8, 2, 16).toUtc(),
            endAtUtc: jalali(1405, 8, 2, 17).toUtc(),
            status: EventStatus.planned,
          ),
          thirdKey: OccurrenceException(
            eventId: 'evt-cancelled',
            instanceKey: thirdKey,
            startAtUtc: jalali(1405, 8, 3, 10).toUtc(),
            endAtUtc: jalali(1405, 8, 3, 11).toUtc(),
            status: EventStatus.cancelled,
          ),
        },
      );

      expect(withException, hasLength(2));
      expect(withException[0].instanceKey, base[0].instanceKey);
      expect(withException[1].isException, isTrue);
      expect(withException[1].sourceEventId, 'evt-exception');
      expect(withException[1].startLocal.hour, 16);
    });

    test('نمونه‌ی منتقل‌شده در روز جدید دیده می‌شود، نه روز قبلی', () {
      final List<EventOccurrence> base = expand(
        rule(frequency: RecurrenceFrequency.weekly, start: jalali(1405, 8, 1)),
        rangeStart: jalali(1405, 8, 1),
        rangeEnd: jalali(1405, 8, 9),
      );
      expect(base, hasLength(2));

      final String key = base[1].instanceKey; // ۸ آبان
      final List<EventOccurrence> moved = expand(
        rule(frequency: RecurrenceFrequency.weekly, start: jalali(1405, 8, 1)),
        rangeStart: jalali(1405, 8, 10),
        rangeEnd: jalali(1405, 8, 12),
        exceptions: <String, OccurrenceException>{
          key: OccurrenceException(
            eventId: 'evt-moved',
            instanceKey: key,
            startAtUtc: jalali(1405, 8, 10, 9).toUtc(),
            endAtUtc: jalali(1405, 8, 10, 10).toUtc(),
            status: EventStatus.planned,
          ),
        },
      );

      expect(moved, hasLength(1));
      expect(jalaliDay(moved.single), 10);
      expect(moved.single.instanceKey, key);
    });

    test('سری عبوری از نیمه‌شب در هر دو روز پیدا می‌شود', () {
      final List<EventOccurrence> occurrences = expand(
        rule(
          frequency: RecurrenceFrequency.daily,
          start: jalali(1405, 8, 1),
          startMinutes: (23 * 60) + 30,
        ),
        rangeStart: jalali(1405, 8, 2),
        rangeEnd: jalali(1405, 8, 3),
        duration: const Duration(hours: 1, minutes: 30),
      );

      expect(occurrences, isNotEmpty);
      expect(jalaliDay(occurrences.first), 1);
      expect(dates.partsOf(occurrences.first.endLocal).day, 2);
    });

    test('سری بدون نمونه در بازه، لیست خالی می‌دهد', () {
      final List<EventOccurrence> occurrences = expand(
        rule(
          frequency: RecurrenceFrequency.yearly,
          monthOfYear: 1,
          monthDay: 1,
          start: jalali(1405, 1, 1),
        ),
        rangeStart: jalali(1405, 6, 1),
        rangeEnd: jalali(1405, 12, 1),
      );
      expect(occurrences, isEmpty);
    });
  });
}
