import '../../../core/date_time/jalali_date_service.dart';
import '../../../shared/enums/app_enums.dart';
import 'event_occurrence.dart';
import 'recurrence_rule.dart';

/// ردیف استثنا در قالب حداقلی که تابع expand لازم دارد.
///
/// Repository این را از جدول `events` می‌سازد؛ expander خودش به دیتابیس
/// دسترسی ندارد (بخش ۱۱.۶: تابع خالص دامنه).
class OccurrenceException {
  const OccurrenceException({
    required this.eventId,
    required this.instanceKey,
    required this.startAtUtc,
    required this.endAtUtc,
    required this.status,
  });

  final String eventId;
  final String instanceKey;
  final DateTime startAtUtc;
  final DateTime endAtUtc;
  final EventStatus status;
}

/// محاسبه‌ی نمونه‌های یک سری تکراری داخل بازه‌ی درخواستی (بخش ۱۱.۶ سند).
///
/// - فقط در [rangeStartLocal، rangeEndLocal) محاسبه می‌کند، نه بی‌پایان.
/// - تکرار ماهانه/سالانه بر اساس تقویم شمسی است و اگر روز انتخابی در ماه
///   وجود نداشته باشد، آن ماه نمونه ندارد.
/// - [countLimit] از ابتدای سری شمرده می‌شود، نه از ابتدای بازه.
/// - استثناها با کلید نمونه ادغام می‌شوند: نمونه‌ی محاسبه‌شده حذف و ردیف
///   استثنا (حتی اگر به روز دیگری منتقل شده باشد) با زمان خودش برمی‌گردد.
/// - نمونه‌های لغوشده (استثنای `cancelled`) در خروجی نیستند.
List<EventOccurrence> expandOccurrences({
  required RecurrenceRule rule,
  required String masterEventId,
  required DateTime masterStartAtUtc,
  required DateTime masterEndAtUtc,
  required DateTime rangeStartLocal,
  required DateTime rangeEndLocal,
  required JalaliDateService dates,
  Map<String, OccurrenceException> exceptions =
      const <String, OccurrenceException>{},
  int maxIterations = 20000,
}) {
  final DateTime rangeStartUtc = rangeStartLocal.toUtc();
  final DateTime rangeEndUtc = rangeEndLocal.toUtc();
  final Duration duration = masterEndAtUtc.difference(masterStartAtUtc);
  final DateTime anchor = _dateOnly(rule.startLocalDate);
  final DateTime? until = rule.untilLocalDate == null
      ? null
      : _dateOnly(rule.untilLocalDate!);
  final int anchorWeekday = dates.weekdayIndex(anchor);
  final Set<int> weekdays = rule.weekdays.isEmpty
      ? <int>{anchorWeekday}
      : rule.weekdays;
  final int anchorDay = dates.partsOf(anchor).day;
  final int anchorMonth = dates.partsOf(anchor).month;
  final int targetDay = rule.monthDay ?? anchorDay;
  final int targetMonth = rule.monthOfYear ?? anchorMonth;

  final List<EventOccurrence> computed = <EventOccurrence>[];
  final Set<String> computedKeys = <String>{};

  int emitted = 0;
  for (int index = 0; index <= maxIterations; index++) {
    final DateTime candidate = dates.addDays(anchor, index);
    if (until != null && candidate.isAfter(until)) {
      break;
    }

    final DateTime localStart = DateTime(
      candidate.year,
      candidate.month,
      candidate.day,
      rule.startMinutes ~/ 60,
      rule.startMinutes % 60,
    );

    // نمونه‌ها زمان‌محور و صعودی ساخته می‌شوند؛ عبور از پایان بازه یعنی
    // نمونه‌ی بعدی هم بیرون است.
    if (!localStart.isBefore(rangeEndLocal)) {
      break;
    }

    if (!_matches(
      rule: rule,
      index: index,
      candidate: candidate,
      anchor: anchor,
      anchorDay: anchorDay,
      targetDay: targetDay,
      targetMonth: targetMonth,
      weekdays: weekdays,
      dates: dates,
    )) {
      continue;
    }

    emitted += 1;
    if (rule.countLimit != null && emitted > rule.countLimit!) {
      break;
    }

    final DateTime startUtc = localStart.toUtc();
    final DateTime endUtc = startUtc.add(duration);
    if (startUtc.isBefore(rangeEndUtc) && endUtc.isAfter(rangeStartUtc)) {
      final String key = _instanceKey(candidate);
      computedKeys.add(key);
      computed.add(
        EventOccurrence(
          masterEventId: masterEventId,
          instanceKey: key,
          startAtUtc: startUtc,
          endAtUtc: endUtc,
          status: EventStatus.planned,
        ),
      );
    }
  }

  // استثناها: نمونه‌ی محاسبه‌شده‌ی همان کلید کنار می‌رود و به‌جایش ردیف
  // استثنا با زمان و وضعیت خودش می‌آید (حتی اگر جابه‌جا شده باشد).
  final List<EventOccurrence> result = <EventOccurrence>[
    ...computed.where(
      (EventOccurrence occurrence) =>
          !exceptions.containsKey(occurrence.instanceKey),
    ),
  ];

  for (final OccurrenceException exception in exceptions.values) {
    if (exception.status == EventStatus.cancelled) {
      continue;
    }
    final EventOccurrence occurrence = EventOccurrence(
      masterEventId: masterEventId,
      instanceKey: exception.instanceKey,
      startAtUtc: exception.startAtUtc,
      endAtUtc: exception.endAtUtc,
      status: exception.status,
      isException: true,
      sourceEventId: exception.eventId,
    );
    if (occurrence.overlapsWindow(rangeStartUtc, rangeEndUtc)) {
      result.add(occurrence);
    }
  }

  result.sort((EventOccurrence a, EventOccurrence b) {
    final int byStart = a.startAtUtc.compareTo(b.startAtUtc);
    return byStart != 0 ? byStart : a.instanceKey.compareTo(b.instanceKey);
  });
  return result;
}

bool _matches({
  required RecurrenceRule rule,
  required int index,
  required DateTime candidate,
  required DateTime anchor,
  required int anchorDay,
  required int targetDay,
  required int targetMonth,
  required Set<int> weekdays,
  required JalaliDateService dates,
}) {
  switch (rule.frequency) {
    case RecurrenceFrequency.daily:
      return index % rule.interval == 0;

    case RecurrenceFrequency.weekly:
      final int weekIndex = index ~/ 7;
      return weekIndex % rule.interval == 0 &&
          weekdays.contains(dates.weekdayIndex(candidate));

    case RecurrenceFrequency.monthly:
      final int months = _monthsBetween(anchor, candidate, dates);
      if (months % rule.interval != 0) return false;
      return dates.partsOf(candidate).day == targetDay;

    case RecurrenceFrequency.yearly:
      final int months = _monthsBetween(anchor, candidate, dates);
      if (months % (rule.interval * 12) != 0) return false;
      final parts = dates.partsOf(candidate);
      return parts.month == targetMonth && parts.day == targetDay;
  }
}

int _monthsBetween(DateTime from, DateTime to, JalaliDateService dates) {
  final fromParts = dates.partsOf(from);
  final toParts = dates.partsOf(to);
  return ((toParts.year - fromParts.year) * 12) +
      (toParts.month - fromParts.month);
}

DateTime _dateOnly(DateTime dateTime) =>
    DateTime(dateTime.year, dateTime.month, dateTime.day);

String _instanceKey(DateTime date) {
  final String month = date.month.toString().padLeft(2, '0');
  final String day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
