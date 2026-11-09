import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../core/date_time/jalali_date_parts.dart';
import '../core/date_time/jalali_date_service.dart';
import '../features/recurrence/domain/event_occurrence.dart';
import '../features/recurrence/domain/recurrence_expander.dart';
import '../features/recurrence/domain/recurrence_rule.dart';
import '../shared/enums/app_enums.dart';
import 'app_database.dart';
import 'row_id.dart';

/// خطاهای لایه‌ی رویداد.
///
/// همه از یک پایه‌ی `sealed` ارث می‌برند تا UI بتواند پیام فارسی روشن
/// نشان دهد و تست‌ها با `isA` دقیقاً همان نوع را بررسی کنند.
sealed class EventRepositoryException implements Exception {
  const EventRepositoryException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// ورودی رویداد نامعتبر است (عنوان خالی، پایان قبل از شروع، …).
final class EventValidationException extends EventRepositoryException {
  const EventValidationException(super.message);
}

/// رویداد درخواستی وجود ندارد یا حذف شده است.
final class EventNotFoundException extends EventRepositoryException {
  const EventNotFoundException(this.id)
      : super('رویداد با شناسه‌ی «$id» پیدا نشد.');

  final String id;
}

/// مدل دامنه‌ی رویداد.
///
/// لحظه‌ها در دیتابیس **UTC** ذخیره می‌شوند (ستون‌های `*_utc` بخش ۱۰.۴ سند)
/// و UI همیشه از [startLocal] و [endLocal] استفاده می‌کند؛ بنابراین رویداد
/// ساعت ۰۰:۳۰ به روز قبل نمی‌رود (بخش ۱۲.۱).
class Event {
  const Event({
    required this.id,
    required this.responsibilityId,
    required this.title,
    required this.startAtUtc,
    required this.endAtUtc,
    required this.timezoneId,
    required this.allDay,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.location,
    this.projectId,
    this.recurrenceRuleId,
    this.recurrenceInstanceKey,
  });

  final String id;
  final String responsibilityId;
  final String title;
  final String? description;
  final String? location;
  final DateTime startAtUtc;
  final DateTime endAtUtc;
  final String timezoneId;
  final bool allDay;
  final EventStatus status;
  final String? projectId;
  final String? recurrenceRuleId;
  final String? recurrenceInstanceKey;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// شروع به وقت محلی دستگاه — همان چیزی که به کاربر نشان داده می‌شود.
  DateTime get startLocal => startAtUtc.toLocal();

  /// پایان به وقت محلی (بازه نیم‌باز: پایان شامل رویداد نیست).
  DateTime get endLocal => endAtUtc.toLocal();

  Duration get duration => endAtUtc.difference(startAtUtc);

  bool get isCancelled => status == EventStatus.cancelled;

  bool get isCompleted => status == EventStatus.completed;

  /// این ردیف یکی از نمونه‌های یک سری تکراری است (شناسه‌ی نمایشی دارد).
  bool get isOccurrence => recurrenceInstanceKey != null;

  /// شناسه‌ی رویداد اصلی سری؛ برای رویداد معمولی همان [id] است.
  String get masterId {
    final int index = id.indexOf('@');
    return index <= 0 ? id : id.substring(0, index);
  }

  /// آیا این رویداد با روز محلی داده‌شده هم‌پوشانی دارد؟
  ///
  /// قاعده نیم‌باز: رویدادی که دقیقاً ساعت ۰۰:۰۰ تمام می‌شود به روز بعد
  /// سرریز نمی‌کند، ولی رویداد ۲۳:۰۰ تا ۰۰:۳۰ در هر دو روز دیده می‌شود.
  bool overlapsDay(DateTime localDay) {
    final DateTime dayStart = DateTime(
      localDay.year,
      localDay.month,
      localDay.day,
    ).toUtc();
    final DateTime dayEnd = DateTime(
      localDay.year,
      localDay.month,
      localDay.day + 1,
    ).toUtc();
    return startAtUtc.isBefore(dayEnd) && endAtUtc.isAfter(dayStart);
  }
}

/// قرارداد repository رویدادها.
///
/// ورودی‌های زمانی این لایه **محلی** هستند و تبدیل به UTC داخل همین لایه
/// انجام می‌شود تا هیچ جای UI مجبور به کار با UTC نشود.
abstract class EventRepository {
  /// رویدادهایی که با این روز محلی هم‌پوشانی دارند، مرتب بر اساس شروع.
  Future<List<Event>> getEventsForDay(DateTime localDay);

  /// رویدادهای حذف‌نشده‌ای که با بازه‌ی روزهای محلی [fromDay] تا [toDay]
  /// (شامل هر دو سر) هم‌پوشانی دارند، مرتب بر اساس شروع.
  ///
  /// این کوئری شبکه‌ی ماه و نمای هفتگی را با **یک** رفت‌وبرگشت به دیتابیس
  /// پر می‌کند؛ به‌ازای هر خانه کوئری جدا زده نمی‌شود.
  Future<List<Event>> getEventsInRange({
    required DateTime fromDay,
    required DateTime toDay,
  });

  /// یک رویداد حذف‌نشده.
  Future<Event?> getEventById(String id);

  /// رویدادهای حذف‌نشده‌ای که با بازه‌ی داده‌شده تداخل دارند.
  ///
  /// رویدادهای لغوشده تداخل حساب نمی‌شوند و [excludeEventId] برای ویرایش
  /// استفاده می‌شود تا ردیف خودِ رویداد با خودش تداخل نکند.
  Future<List<Event>> findConflicts({
    required DateTime startAt,
    required DateTime endAt,
    String? excludeEventId,
  });

  Future<Event> insertEvent({
    String? id,
    required String responsibilityId,
    required String title,
    required DateTime startAt,
    required DateTime endAt,
    bool allDay = false,
    String? description,
    String? location,
    EventStatus status = EventStatus.planned,
    String? timezoneId,
    String? projectId,
    String? sourceTaskId,
  });

  Future<void> updateEvent({
    required String id,
    String? responsibilityId,
    String? title,
    String? description,
    String? location,
    DateTime? startAt,
    DateTime? endAt,
    bool? allDay,
    EventStatus? status,
  });

  /// قاعده‌ی تکرار یک سری.
  Future<RecurrenceRule?> getRecurrenceRule(String id);

  /// ساخت رویداد تکراری: یک ردیف قاعده + یک ردیف master.
  ///
  /// نمونه‌ها ذخیره نمی‌شوند و هنگام خواندن بازه محاسبه می‌گردند
  /// (بخش ۱۱.۶ سند).
  Future<Event> createRecurringEvent({
    String? id,
    required String responsibilityId,
    required String title,
    required DateTime startAt,
    required DateTime endAt,
    required RecurrenceFrequency frequency,
    int interval = 1,
    Set<int> weekdays = const <int>{},
    int? monthDay,
    int? monthOfYear,
    DateTime? untilLocalDate,
    int? countLimit,
    bool allDay = false,
    String? description,
    String? location,
    String? projectId,
    String? timezoneId,
  });

  /// ویرایش یک نمونه از سری با دامنه‌ی [scope] (بخش ۱۱.۹).
  Future<void> updateOccurrence({
    required String occurrenceId,
    required RecurrenceEditScope scope,
    String? responsibilityId,
    String? title,
    String? description,
    String? location,
    DateTime? startAt,
    DateTime? endAt,
    bool? allDay,
    EventStatus? status,
  });

  /// حذف یک نمونه یا کل سری با دامنه‌ی [scope].
  Future<void> deleteOccurrence({
    required String occurrenceId,
    required RecurrenceEditScope scope,
  });

  /// حذف نرم؛ ردیف برای بازیابی می‌ماند.
  Future<void> deleteEvent(String id);

  Future<void> permanentlyDeleteEvent(String id);
}

Event _fromRow(
  EventRow row, {
  String? occurrenceId,
  DateTime? startAtUtc,
  DateTime? endAtUtc,
  EventStatus? status,
  String? instanceKey,
}) {
  return Event(
    id: occurrenceId ?? row.id,
    responsibilityId: row.responsibilityId,
    title: row.title,
    description: row.description,
    location: row.location,
    startAtUtc: (startAtUtc ?? row.startAtUtc).toUtc(),
    endAtUtc: (endAtUtc ?? row.endAtUtc).toUtc(),
    timezoneId: row.timezoneId,
    allDay: row.allDay,
    status: status ?? row.status,
    projectId: row.projectId,
    recurrenceRuleId: row.recurrenceRuleId,
    recurrenceInstanceKey: instanceKey ?? row.recurrenceInstanceKey,
    createdAt: row.createdAt.toUtc(),
    updatedAt: row.updatedAt.toUtc(),
  );
}

/// خواندن تاریخ میلادیِ `YYYY-MM-DD` بدون ساعت.
DateTime _parseDateOnly(String value) {
  final List<String> parts = value.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

String _dateOnlyString(DateTime date) {
  final String month = date.month.toString().padLeft(2, '0');
  final String day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

/// `HH:mm[:ss]` → دقیقه‌ی روز.
int _minutesFromTime(String value) {
  final List<String> parts = value.split(':');
  final int hour = int.parse(parts[0]);
  final int minute = int.parse(parts[1]);
  return (hour * 60) + minute;
}

String _timeString(int minutes) {
  final String hour = (minutes ~/ 60).toString().padLeft(2, '0');
  final String minute = (minutes % 60).toString().padLeft(2, '0');
  return '$hour:$minute:00';
}

RecurrenceRule _ruleFromRow(RecurrenceRuleRow row) {
  final Set<int> weekdays = row.weekdaysJson == null
      ? <int>{}
      : (jsonDecode(row.weekdaysJson!) as List<dynamic>)
            .map((dynamic value) => value as int)
            .toSet();
  return RecurrenceRule(
    id: row.id,
    frequency: row.frequency,
    interval: row.intervalValue,
    weekdays: weekdays,
    monthDay: row.monthDay,
    monthOfYear: row.monthOfYear,
    startLocalDate: _parseDateOnly(row.startLocalDate),
    startMinutes: _minutesFromTime(row.localTime),
    timezoneId: row.timezoneId,
    untilLocalDate: row.untilLocalDate == null
        ? null
        : _parseDateOnly(row.untilLocalDate!),
    countLimit: row.countLimit,
  );
}

/// عنوان رویداد: `trim` شده و بین ۱ و ۲۰۰ کاراکتر (محدودیت جدول).
String _validateTitle(String title) {
  final String trimmed = title.trim();
  if (trimmed.isEmpty) {
    throw const EventValidationException('عنوان رویداد نمی‌تواند خالی باشد.');
  }
  if (trimmed.length > 200) {
    throw const EventValidationException(
      'عنوان رویداد نباید بیشتر از ۲۰۰ کاراکتر باشد.',
    );
  }
  return trimmed;
}

DateTime _startOfDay(DateTime dateTime) =>
    DateTime(dateTime.year, dateTime.month, dateTime.day);

DateTime _nextDayStart(DateTime dateTime) =>
    DateTime(dateTime.year, dateTime.month, dateTime.day + 1);

/// پیاده‌سازی [EventRepository] روی Drift.
class DriftEventRepository implements EventRepository {
  DriftEventRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<Event>> getEventsForDay(DateTime localDay) {
    return _occurrencesInRange(
      rangeStartLocal: _startOfDay(localDay),
      rangeEndLocal: _nextDayStart(localDay),
    );
  }

  @override
  Future<List<Event>> getEventsInRange({
    required DateTime fromDay,
    required DateTime toDay,
  }) async {
    final DateTime rangeStart = _startOfDay(fromDay);
    final DateTime rangeEnd = _nextDayStart(toDay);
    if (!rangeEnd.isAfter(rangeStart)) {
      throw const EventValidationException('بازه‌ی تاریخ نامعتبر است.');
    }
    return _occurrencesInRange(
      rangeStartLocal: rangeStart,
      rangeEndLocal: rangeEnd,
    );
  }

  /// همه‌ی رویدادهای یک بازه: رویدادهای معمولی، نمونه‌های تکراری محاسبه‌شده
  /// و ردیف‌های استثنا (بخش ۱۱.۶).
  Future<List<Event>> _occurrencesInRange({
    required DateTime rangeStartLocal,
    required DateTime rangeEndLocal,
  }) async {
    final DateTime rangeStartUtc = rangeStartLocal.toUtc();
    final DateTime rangeEndUtc = rangeEndLocal.toUtc();

    final List<EventRow> plainRows = await (_db.select(_db.events)
          ..where((t) => t.deletedAt.isNull())
          ..where((t) => t.recurrenceRuleId.isNull())
          ..where((t) => t.startAtUtc.isSmallerThanValue(rangeEndUtc))
          ..where((t) => t.endAtUtc.isBiggerThanValue(rangeStartUtc)))
        .get();

    final List<EventRow> masters = await (_db.select(_db.events)
          ..where((t) => t.deletedAt.isNull())
          ..where((t) => t.recurrenceRuleId.isNotNull())
          ..where((t) => t.recurrenceInstanceKey.isNull()))
        .get();

    final List<Event> result = plainRows.map((EventRow row) => _fromRow(row)).toList();
    if (masters.isEmpty) {
      _sortEvents(result);
      return result;
    }

    final List<String> ruleIds = masters
        .map((EventRow row) => row.recurrenceRuleId!)
        .toSet()
        .toList();
    final List<RecurrenceRuleRow> ruleRows = await (_db.select(
      _db.recurrenceRules,
    )..where((t) => t.id.isIn(ruleIds)))
        .get();
    final Map<String, RecurrenceRuleRow> rulesById = <String, RecurrenceRuleRow>{
      for (final RecurrenceRuleRow row in ruleRows) row.id: row,
    };
    final List<EventRow> exceptionRows = await (_db.select(_db.events)
          ..where((t) => t.deletedAt.isNull())
          ..where((t) => t.recurrenceInstanceKey.isNotNull())
          ..where((t) => t.recurrenceRuleId.isIn(ruleIds)))
        .get();
    final Map<String, List<EventRow>> exceptionsByRule =
        <String, List<EventRow>>{};
    for (final EventRow row in exceptionRows) {
      (exceptionsByRule[row.recurrenceRuleId!] ??= <EventRow>[]).add(row);
    }

    const JalaliDateService dates = JalaliDateService();
    for (final EventRow master in masters) {
      final RecurrenceRuleRow? ruleRow = rulesById[master.recurrenceRuleId];
      if (ruleRow == null) {
        continue;
      }
      final RecurrenceRule rule = _ruleFromRow(ruleRow);
      final List<EventRow> ruleExceptions =
          exceptionsByRule[rule.id] ?? const <EventRow>[];
      final Map<String, OccurrenceException> exceptions =
          <String, OccurrenceException>{
            for (final EventRow row in ruleExceptions)
              row.recurrenceInstanceKey!: OccurrenceException(
                eventId: row.id,
                instanceKey: row.recurrenceInstanceKey!,
                startAtUtc: row.startAtUtc.toUtc(),
                endAtUtc: row.endAtUtc.toUtc(),
                status: row.status,
              ),
          };

      final List<EventOccurrence> occurrences = expandOccurrences(
        rule: rule,
        masterEventId: master.id,
        masterStartAtUtc: master.startAtUtc.toUtc(),
        masterEndAtUtc: master.endAtUtc.toUtc(),
        rangeStartLocal: rangeStartLocal,
        rangeEndLocal: rangeEndLocal,
        dates: dates,
        exceptions: exceptions,
      );

      for (final EventOccurrence occurrence in occurrences) {
        EventRow base = master;
        if (occurrence.sourceEventId != null) {
          for (final EventRow row in ruleExceptions) {
            if (row.id == occurrence.sourceEventId) {
              base = row;
              break;
            }
          }
        }
        result.add(
          _fromRow(
            base,
            occurrenceId: occurrence.id,
            startAtUtc: occurrence.startAtUtc,
            endAtUtc: occurrence.endAtUtc,
            status: occurrence.status,
            instanceKey: occurrence.instanceKey,
          ),
        );
      }
    }

    _sortEvents(result);
    return result;
  }

  void _sortEvents(List<Event> events) {
    events.sort((Event a, Event b) {
      final int byStart = a.startAtUtc.compareTo(b.startAtUtc);
      return byStart != 0 ? byStart : a.title.compareTo(b.title);
    });
  }

  @override
  Future<Event?> getEventById(String id) async {
    if (id.contains('@')) {
      return _getOccurrenceById(id);
    }
    final EventRow? row = await (_db.select(_db.events)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  /// خواندن یک نمونه‌ی تکراری با شناسه‌ی نمایشی `{master}@{key}`.
  Future<Event?> _getOccurrenceById(String displayId) async {
    final int separator = displayId.indexOf('@');
    final String masterId = displayId.substring(0, separator);
    final String instanceKey = displayId.substring(separator + 1);

    final EventRow? master = await (_db.select(_db.events)
          ..where((t) => t.id.equals(masterId) & t.deletedAt.isNull()))
        .getSingleOrNull();
    if (master == null) {
      return null;
    }
    final String? ruleId = master.recurrenceRuleId;
    if (ruleId == null) {
      return null;
    }

    final EventRow? exception = await (_db.select(_db.events)
          ..where(
            (t) =>
                t.recurrenceRuleId.equals(ruleId) &
                t.recurrenceInstanceKey.equals(instanceKey) &
                t.deletedAt.isNull(),
          ))
        .getSingleOrNull();
    if (exception != null) {
      return _fromRow(
        exception,
        occurrenceId: displayId,
        instanceKey: instanceKey,
      );
    }

    // نمونه ذخیره نشده است؛ همان بازه‌ی روز نمونه را می‌سازیم.
    final DateTime keyDate = _parseDateOnly(instanceKey);
    final List<Event> inRange = await _occurrencesInRange(
      rangeStartLocal: keyDate.subtract(const Duration(days: 1)),
      rangeEndLocal: keyDate.add(const Duration(days: 2)),
    );
    for (final Event event in inRange) {
      if (event.id == displayId) {
        return event;
      }
    }
    return null;
  }

  @override
  Future<List<Event>> findConflicts({
    required DateTime startAt,
    required DateTime endAt,
    String? excludeEventId,
  }) async {
    final DateTime startUtc = startAt.toUtc();
    final DateTime endUtc = endAt.toUtc();
    if (!endUtc.isAfter(startUtc)) {
      throw const EventValidationException(
        'پایان رویداد باید بعد از شروع آن باشد.',
      );
    }

    // تداخل باید نمونه‌های تکراری را هم ببیند (بخش ۱۱.۶: مصرف‌کنندگان
    // expand)، پس از همان مسیر بازه‌ای خوانده می‌شود.
    final List<Event> candidates = await _occurrencesInRange(
      rangeStartLocal: _startOfDay(startAt),
      rangeEndLocal: _nextDayStart(endAt),
    );
    return candidates.where((Event event) {
      if (event.status == EventStatus.cancelled) {
        return false;
      }
      if (excludeEventId != null &&
          (event.id == excludeEventId || event.masterId == excludeEventId)) {
        return false;
      }
      return event.startAtUtc.isBefore(endUtc) &&
          event.endAtUtc.isAfter(startUtc);
    }).toList();
  }

  @override
  Future<Event> insertEvent({
    String? id,
    required String responsibilityId,
    required String title,
    required DateTime startAt,
    required DateTime endAt,
    bool allDay = false,
    String? description,
    String? location,
    EventStatus status = EventStatus.planned,
    String? timezoneId,
    String? projectId,
    String? sourceTaskId,
  }) async {
    final String eventId = id ?? _newId();
    final String validatedTitle = _validateTitle(title);
    final DateTime now = DateTime.now().toUtc();

    DateTime startUtc;
    DateTime endUtc;
    if (allDay) {
      startUtc = _startOfDay(startAt).toUtc();
      endUtc = _nextDayStart(startAt).toUtc();
    } else {
      startUtc = startAt.toUtc();
      endUtc = endAt.toUtc();
      if (!endUtc.isAfter(startUtc)) {
        throw const EventValidationException(
          'پایان رویداد باید بعد از شروع آن باشد.',
        );
      }
    }

    await _db.into(_db.events).insert(
          EventsCompanion.insert(
            id: eventId,
            responsibilityId: responsibilityId,
            title: validatedTitle,
            startAtUtc: startUtc,
            endAtUtc: endUtc,
            timezoneId: timezoneId ?? DateTime.now().timeZoneName,
            description: Value<String?>(description),
            location: Value<String?>(location),
            allDay: Value<bool>(allDay),
            status: Value<EventStatus>(status),
            projectId: Value<String?>(projectId),
            sourceTaskId: Value<String?>(sourceTaskId),
            createdAt: now,
            updatedAt: now,
          ),
        );

    final Event? inserted = await getEventById(eventId);
    if (inserted == null) {
      throw EventNotFoundException(eventId);
    }
    return inserted;
  }

  @override
  Future<void> updateEvent({
    required String id,
    String? responsibilityId,
    String? title,
    String? description,
    String? location,
    DateTime? startAt,
    DateTime? endAt,
    bool? allDay,
    EventStatus? status,
  }) async {
    final Event? existing = await getEventById(id);
    if (existing == null) {
      throw EventNotFoundException(id);
    }

    final bool nextAllDay = allDay ?? existing.allDay;
    final bool changesTime =
        startAt != null || endAt != null || allDay != null;

    DateTime? startUtc;
    DateTime? endUtc;
    if (changesTime) {
      final DateTime baseStart = startAt ?? existing.startLocal;
      final DateTime baseEnd = endAt ?? existing.endLocal;
      if (nextAllDay) {
        startUtc = _startOfDay(baseStart).toUtc();
        endUtc = _nextDayStart(baseStart).toUtc();
      } else {
        startUtc = baseStart.toUtc();
        endUtc = baseEnd.toUtc();
        if (!endUtc.isAfter(startUtc)) {
          throw const EventValidationException(
            'پایان رویداد باید بعد از شروع آن باشد.',
          );
        }
      }
    }

    await (_db.update(_db.events)..where((t) => t.id.equals(id)))
        .write(
      EventsCompanion(
        responsibilityId: responsibilityId != null
            ? Value<String>(responsibilityId)
            : const Value<String>.absent(),
        title: title != null
            ? Value<String>(_validateTitle(title))
            : const Value<String>.absent(),
        description: description != null
            ? Value<String?>(description)
            : const Value<String?>.absent(),
        location: location != null
            ? Value<String?>(location)
            : const Value<String?>.absent(),
        startAtUtc: startUtc != null
            ? Value<DateTime>(startUtc)
            : const Value<DateTime>.absent(),
        endAtUtc: endUtc != null
            ? Value<DateTime>(endUtc)
            : const Value<DateTime>.absent(),
        allDay: changesTime
            ? Value<bool>(nextAllDay)
            : const Value<bool>.absent(),
        status: status != null
            ? Value<EventStatus>(status)
            : const Value<EventStatus>.absent(),
        updatedAt: Value<DateTime>(DateTime.now().toUtc()),
      ),
    );
  }

  @override
  Future<void> deleteEvent(String id) async {
    final Event? existing = await getEventById(id);
    if (existing == null) {
      throw EventNotFoundException(id);
    }
    await (_db.update(_db.events)..where((t) => t.id.equals(id)))
        .write(
      EventsCompanion(
        deletedAt: Value<DateTime>(DateTime.now().toUtc()),
        updatedAt: Value<DateTime>(DateTime.now().toUtc()),
      ),
    );
  }

  @override
  Future<void> permanentlyDeleteEvent(String id) async {
    await (_db.delete(_db.events)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<RecurrenceRule?> getRecurrenceRule(String id) async {
    final RecurrenceRuleRow? row = await (_db.select(_db.recurrenceRules)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _ruleFromRow(row);
  }

  @override
  Future<Event> createRecurringEvent({
    String? id,
    required String responsibilityId,
    required String title,
    required DateTime startAt,
    required DateTime endAt,
    required RecurrenceFrequency frequency,
    int interval = 1,
    Set<int> weekdays = const <int>{},
    int? monthDay,
    int? monthOfYear,
    DateTime? untilLocalDate,
    int? countLimit,
    bool allDay = false,
    String? description,
    String? location,
    String? projectId,
    String? timezoneId,
  }) async {
    if (interval < 1) {
      throw const EventValidationException('بازه‌ی تکرار باید حداقل ۱ باشد.');
    }
    final String validatedTitle = _validateTitle(title);
    final DateTime startLocal = _startOfDay(startAt);
    final int startMinutes = allDay
        ? 0
        : (startAt.hour * 60) + startAt.minute;
    final DateTime effectiveEnd = allDay ? _nextDayStart(startAt) : endAt;
    if (!effectiveEnd.isAfter(startAt)) {
      throw const EventValidationException(
        'پایان رویداد باید بعد از شروع آن باشد.',
      );
    }

    const JalaliDateService dates = JalaliDateService();
    final JalaliDateParts startParts = dates.partsOf(startAt);
    if (frequency == RecurrenceFrequency.yearly && monthOfYear == null) {
      throw const EventValidationException(
        'برای تکرار سالانه باید ماه شمسی مشخص شود.',
      );
    }
    final Set<int> effectiveWeekdays = frequency == RecurrenceFrequency.weekly
        ? (weekdays.isEmpty ? <int>{dates.weekdayIndex(startAt)} : weekdays)
        : const <int>{};

    final String ruleId = newRowId('rule');
    final String eventId = id ?? _newId();
    final String tz = timezoneId ?? DateTime.now().timeZoneName;
    final DateTime now = DateTime.now().toUtc();

    await _db.transaction(() async {
      await _db.into(_db.recurrenceRules).insert(
            RecurrenceRulesCompanion.insert(
              id: ruleId,
              frequency: frequency,
              intervalValue: Value<int>(interval),
              startLocalDate: _dateOnlyString(startLocal),
              localTime: _timeString(startMinutes),
              timezoneId: tz,
              startAtUtc: startAt.toUtc(),
              createdAt: now,
              weekdaysJson: Value<String?>(
                effectiveWeekdays.isEmpty
                    ? null
                    : jsonEncode(effectiveWeekdays.toList()..sort()),
              ),
              monthDay: Value<int?>(
                frequency == RecurrenceFrequency.monthly ||
                        frequency == RecurrenceFrequency.yearly
                    ? (monthDay ?? startParts.day)
                    : null,
              ),
              monthOfYear: Value<int?>(
                frequency == RecurrenceFrequency.yearly
                    ? (monthOfYear ?? startParts.month)
                    : null,
              ),
              untilLocalDate: Value<String?>(
                untilLocalDate == null
                    ? null
                    : _dateOnlyString(untilLocalDate),
              ),
              countLimit: Value<int?>(countLimit),
            ),
          );
      await _db.into(_db.events).insert(
            EventsCompanion.insert(
              id: eventId,
              responsibilityId: responsibilityId,
              title: validatedTitle,
              startAtUtc: allDay ? startLocal.toUtc() : startAt.toUtc(),
              endAtUtc: effectiveEnd.toUtc(),
              timezoneId: tz,
              description: Value<String?>(description),
              location: Value<String?>(location),
              allDay: Value<bool>(allDay),
              projectId: Value<String?>(projectId),
              recurrenceRuleId: Value<String?>(ruleId),
              createdAt: now,
              updatedAt: now,
            ),
          );
    });

    final Event? inserted = await getEventById(eventId);
    if (inserted == null) {
      throw EventNotFoundException(eventId);
    }
    return inserted;
  }

  @override
  Future<void> updateOccurrence({
    required String occurrenceId,
    required RecurrenceEditScope scope,
    String? responsibilityId,
    String? title,
    String? description,
    String? location,
    DateTime? startAt,
    DateTime? endAt,
    bool? allDay,
    EventStatus? status,
  }) async {
    final Event? occurrence = await getEventById(occurrenceId);
    if (occurrence == null || !occurrence.isOccurrence) {
      throw EventNotFoundException(occurrenceId);
    }
    final Event? master = await getEventById(occurrence.masterId);
    if (master == null || master.recurrenceRuleId == null) {
      throw EventNotFoundException(occurrenceId);
    }
    final RecurrenceRule? rule = await getRecurrenceRule(
      master.recurrenceRuleId!,
    );
    if (rule == null) {
      throw EventNotFoundException(occurrenceId);
    }

    switch (scope) {
      case RecurrenceEditScope.allSeries:
        await _db.transaction(() async {
          await updateEvent(
            id: master.id,
            responsibilityId: responsibilityId,
            title: title,
            description: description,
            location: location,
            startAt: startAt,
            endAt: endAt,
            allDay: allDay,
            status: status,
          );
          if (!(allDay ?? master.allDay) && startAt != null) {
            await (_db.update(
              _db.recurrenceRules,
            )..where((t) => t.id.equals(rule.id)))
                .write(
              RecurrenceRulesCompanion(
                localTime: Value<String>(
                  _timeString((startAt.hour * 60) + startAt.minute),
                ),
              ),
            );
          }
        });

      case RecurrenceEditScope.thisOnly:
        await _upsertException(
          master: master,
          occurrence: occurrence,
          title: title,
          responsibilityId: responsibilityId,
          description: description,
          location: location,
          startAt: startAt,
          endAt: endAt,
          allDay: allDay,
          status: status ?? EventStatus.planned,
        );

      case RecurrenceEditScope.thisAndFollowing:
        await _splitSeries(
          master: master,
          rule: rule,
          occurrence: occurrence,
          title: title,
          responsibilityId: responsibilityId,
          description: description,
          location: location,
          startAt: startAt,
          endAt: endAt,
          allDay: allDay,
          status: status,
        );
    }
  }

  @override
  Future<void> deleteOccurrence({
    required String occurrenceId,
    required RecurrenceEditScope scope,
  }) async {
    final Event? occurrence = await getEventById(occurrenceId);
    if (occurrence == null) {
      throw EventNotFoundException(occurrenceId);
    }
    if (!occurrence.isOccurrence) {
      await deleteEvent(occurrenceId);
      return;
    }
    final Event? master = await getEventById(occurrence.masterId);
    if (master == null || master.recurrenceRuleId == null) {
      await deleteEvent(occurrence.masterId);
      return;
    }
    final String ruleId = master.recurrenceRuleId!;

    switch (scope) {
      case RecurrenceEditScope.allSeries:
        await _db.transaction(() async {
          await deleteEvent(master.id);
          await (_db.update(_db.events)..where(
                (t) =>
                    t.recurrenceRuleId.equals(ruleId) & t.deletedAt.isNull(),
              ))
              .write(
            EventsCompanion(
              deletedAt: Value<DateTime>(DateTime.now().toUtc()),
              updatedAt: Value<DateTime>(DateTime.now().toUtc()),
            ),
          );
        });

      case RecurrenceEditScope.thisOnly:
        await _upsertException(
          master: master,
          occurrence: occurrence,
          status: EventStatus.cancelled,
        );

      case RecurrenceEditScope.thisAndFollowing:
        final String? key = occurrence.recurrenceInstanceKey;
        if (key == null) {
          return;
        }
        final DateTime boundary = _parseDateOnly(key);
        await _db.transaction(() async {
          await _closeRuleBefore(ruleId, boundary);
          await (_db.update(_db.events)..where(
                (t) =>
                    t.recurrenceRuleId.equals(ruleId) &
                    t.recurrenceInstanceKey.isBiggerOrEqualValue(key) &
                    t.deletedAt.isNull(),
              ))
              .write(
            EventsCompanion(
              deletedAt: Value<DateTime>(DateTime.now().toUtc()),
              updatedAt: Value<DateTime>(DateTime.now().toUtc()),
            ),
          );
        });
    }
  }

  /// ذخیره‌ی ردیف استثنا برای یک نمونه (ساخت/ویرایش/لغو).
  Future<void> _upsertException({
    required Event master,
    required Event occurrence,
    String? responsibilityId,
    String? title,
    String? description,
    String? location,
    DateTime? startAt,
    DateTime? endAt,
    bool? allDay,
    required EventStatus status,
  }) async {
    final String ruleId = master.recurrenceRuleId!;
    final String key =
        occurrence.recurrenceInstanceKey ??
        _dateOnlyString(occurrence.startLocal);
    final bool nextAllDay = allDay ?? master.allDay;
    DateTime startLocal = startAt ?? occurrence.startLocal;
    DateTime endLocal = endAt ?? occurrence.endLocal;
    if (nextAllDay) {
      startLocal = _startOfDay(startLocal);
      endLocal = _nextDayStart(startLocal);
    }
    if (!endLocal.isAfter(startLocal)) {
      throw const EventValidationException(
        'پایان رویداد باید بعد از شروع آن باشد.',
      );
    }

    final EventRow? existing = await (_db.select(_db.events)..where(
          (t) =>
              t.recurrenceRuleId.equals(ruleId) &
              t.recurrenceInstanceKey.equals(key) &
              t.deletedAt.isNull(),
        ))
        .getSingleOrNull();
    final DateTime now = DateTime.now().toUtc();

    if (existing == null) {
      await _db.into(_db.events).insert(
            EventsCompanion.insert(
              id: newRowId('exc'),
              responsibilityId: responsibilityId ?? master.responsibilityId,
              title: _validateTitle(title ?? master.title),
              startAtUtc: startLocal.toUtc(),
              endAtUtc: endLocal.toUtc(),
              timezoneId: master.timezoneId,
              description: Value<String?>(description ?? master.description),
              location: Value<String?>(location ?? master.location),
              allDay: Value<bool>(nextAllDay),
              status: Value<EventStatus>(status),
              projectId: Value<String?>(master.projectId),
              recurrenceRuleId: Value<String?>(ruleId),
              recurrenceInstanceKey: Value<String?>(key),
              createdAt: now,
              updatedAt: now,
            ),
          );
      return;
    }

    await (_db.update(_db.events)..where((t) => t.id.equals(existing.id)))
        .write(
      EventsCompanion(
        responsibilityId: responsibilityId == null
            ? const Value<String>.absent()
            : Value<String>(responsibilityId),
        title: title == null
            ? const Value<String>.absent()
            : Value<String>(_validateTitle(title)),
        description: description == null
            ? const Value<String?>.absent()
            : Value<String?>(description),
        location: location == null
            ? const Value<String?>.absent()
            : Value<String?>(location),
        startAtUtc: Value<DateTime>(startLocal.toUtc()),
        endAtUtc: Value<DateTime>(endLocal.toUtc()),
        allDay: Value<bool>(nextAllDay),
        status: Value<EventStatus>(status),
        updatedAt: Value<DateTime>(now),
      ),
    );
  }

  /// پایان دادن سری قبل از روز [boundary] (برای «این و بعدی‌ها»).
  Future<void> _closeRuleBefore(String ruleId, DateTime boundary) async {
    final DateTime lastDay = DateTime(
      boundary.year,
      boundary.month,
      boundary.day - 1,
    );
    await (_db.update(
      _db.recurrenceRules,
    )..where((t) => t.id.equals(ruleId)))
        .write(
      RecurrenceRulesCompanion(
        untilLocalDate: Value<String?>(_dateOnlyString(lastDay)),
      ),
    );
  }

  /// شکستن سری در نمونه‌ی [occurrence]: سری قبلی بسته و سری تازه ساخته
  /// می‌شود (بخش ۱۱.۹ سند).
  Future<void> _splitSeries({
    required Event master,
    required RecurrenceRule rule,
    required Event occurrence,
    String? responsibilityId,
    String? title,
    String? description,
    String? location,
    DateTime? startAt,
    DateTime? endAt,
    bool? allDay,
    EventStatus? status,
  }) async {
    final String key = occurrence.recurrenceInstanceKey!;
    final DateTime boundary = _parseDateOnly(key);
    final bool nextAllDay = allDay ?? master.allDay;
    DateTime newStart = startAt ?? occurrence.startLocal;
    DateTime newEnd = endAt ?? occurrence.endLocal;
    if (nextAllDay) {
      newStart = _startOfDay(newStart);
      newEnd = _nextDayStart(newStart);
    }
    if (!newEnd.isAfter(newStart)) {
      throw const EventValidationException(
        'پایان رویداد باید بعد از شروع آن باشد.',
      );
    }

    final int? remaining = rule.countLimit == null
        ? null
        : math.max(
            1,
            rule.countLimit! -
                await _countOccurrencesBefore(rule, master, boundary),
          );

    final String newRuleId = newRowId('rule');
    final String newMasterId = newRowId('evt');
    final DateTime now = DateTime.now().toUtc();

    await _db.transaction(() async {
      await _closeRuleBefore(rule.id, boundary);

      await _db.into(_db.recurrenceRules).insert(
            RecurrenceRulesCompanion.insert(
              id: newRuleId,
              frequency: rule.frequency,
              intervalValue: Value<int>(rule.interval),
              startLocalDate: _dateOnlyString(_startOfDay(newStart)),
              localTime: _timeString(
                nextAllDay ? 0 : (newStart.hour * 60) + newStart.minute,
              ),
              timezoneId: rule.timezoneId,
              startAtUtc: newStart.toUtc(),
              createdAt: now,
              weekdaysJson: Value<String?>(
                rule.weekdays.isEmpty
                    ? null
                    : jsonEncode(rule.weekdays.toList()..sort()),
              ),
              monthDay: Value<int?>(rule.monthDay),
              monthOfYear: Value<int?>(rule.monthOfYear),
              untilLocalDate: Value<String?>(
                rule.untilLocalDate == null
                    ? null
                    : _dateOnlyString(rule.untilLocalDate!),
              ),
              countLimit: Value<int?>(remaining),
            ),
          );

      await _db.into(_db.events).insert(
            EventsCompanion.insert(
              id: newMasterId,
              responsibilityId: responsibilityId ?? master.responsibilityId,
              title: _validateTitle(title ?? master.title),
              startAtUtc: newStart.toUtc(),
              endAtUtc: newEnd.toUtc(),
              timezoneId: master.timezoneId,
              description: Value<String?>(description ?? master.description),
              location: Value<String?>(location ?? master.location),
              allDay: Value<bool>(nextAllDay),
              status: Value<EventStatus>(status ?? master.status),
              projectId: Value<String?>(master.projectId),
              recurrenceRuleId: Value<String?>(newRuleId),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // استثناهای بعد از مرز به سری جدید منتقل می‌شوند؛ استثنای خودِ مرز
      // با master جدید جایگزین شده است.
      await (_db.delete(_db.events)..where(
            (t) =>
                t.recurrenceRuleId.equals(rule.id) &
                t.recurrenceInstanceKey.equals(key),
          ))
          .go();
      await (_db.update(_db.events)..where(
            (t) =>
                t.recurrenceRuleId.equals(rule.id) &
                t.recurrenceInstanceKey.isBiggerThanValue(key) &
                t.deletedAt.isNull(),
          ))
          .write(
        EventsCompanion(recurrenceRuleId: Value<String?>(newRuleId)),
      );
    });
  }

  /// تعداد نمونه‌های برنامه‌ریزی‌شده‌ی قبل از [boundary]، برای محاسبه‌ی
  /// count_limit باقی‌مانده هنگام شکستن سری.
  Future<int> _countOccurrencesBefore(
    RecurrenceRule rule,
    Event master,
    DateTime boundary,
  ) async {
    final List<EventOccurrence> occurrences = expandOccurrences(
      rule: rule,
      masterEventId: master.id,
      masterStartAtUtc: master.startAtUtc,
      masterEndAtUtc: master.endAtUtc,
      rangeStartLocal: rule.startLocalDate,
      rangeEndLocal: boundary,
      dates: const JalaliDateService(),
    );
    return occurrences.length;
  }

  String _newId() => newRowId('evt');
}
