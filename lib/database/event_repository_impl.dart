import 'package:drift/drift.dart';

import '../shared/enums/app_enums.dart';
import 'app_database.dart';

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

  /// حذف نرم؛ ردیف برای بازیابی می‌ماند.
  Future<void> deleteEvent(String id);

  Future<void> permanentlyDeleteEvent(String id);
}

Event _fromRow(EventRow row) {
  return Event(
    id: row.id,
    responsibilityId: row.responsibilityId,
    title: row.title,
    description: row.description,
    location: row.location,
    startAtUtc: row.startAtUtc.toUtc(),
    endAtUtc: row.endAtUtc.toUtc(),
    timezoneId: row.timezoneId,
    allDay: row.allDay,
    status: row.status,
    projectId: row.projectId,
    recurrenceRuleId: row.recurrenceRuleId,
    recurrenceInstanceKey: row.recurrenceInstanceKey,
    createdAt: row.createdAt.toUtc(),
    updatedAt: row.updatedAt.toUtc(),
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
  Future<List<Event>> getEventsForDay(DateTime localDay) async {
    final DateTime dayStartUtc = _startOfDay(localDay).toUtc();
    final DateTime dayEndUtc = _nextDayStart(localDay).toUtc();

    final rows = await (_db.select(_db.events)
          ..where((t) => t.deletedAt.isNull())
          ..where(
            (t) => t.startAtUtc.isSmallerThanValue(dayEndUtc),
          )
          ..where((t) => t.endAtUtc.isBiggerThanValue(dayStartUtc))
          ..orderBy([
            (t) => OrderingTerm.asc(t.startAtUtc),
            (t) => OrderingTerm.asc(t.title),
          ]))
        .get();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<Event?> getEventById(String id) async {
    final EventRow? row = await (_db.select(_db.events)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
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

    final query = _db.select(_db.events)
      ..where((t) => t.deletedAt.isNull())
      ..where((t) => t.startAtUtc.isSmallerThanValue(endUtc))
      ..where((t) => t.endAtUtc.isBiggerThanValue(startUtc))
      ..where(
        (t) => t.status.equalsValue(EventStatus.cancelled).not(),
      )
      ..orderBy([
        (t) => OrderingTerm.asc(t.startAtUtc),
      ]);
    if (excludeEventId != null) {
      query.where((t) => t.id.equals(excludeEventId).not());
    }

    final List<EventRow> rows = await query.get();
    return rows.map(_fromRow).toList();
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

  String _newId() {
    final int stamp = DateTime.now().microsecondsSinceEpoch;
    return 'evt-${stamp.toRadixString(36)}';
  }
}
