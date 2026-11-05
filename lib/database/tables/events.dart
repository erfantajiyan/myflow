import 'package:drift/drift.dart';

export '../../shared/enums/app_enums.dart';
import 'projects.dart';
import 'recurrence_rules.dart';
import 'responsibilities.dart';
import 'tasks.dart';

/// رویدادها — جدول `events` (بخش ۱۰.۴ سند).
///
/// یک رویداد تکراری، ردیف master همین جدول است؛ نمونه‌های عادی ذخیره
/// نمی‌شوند و فقط استثناها (با `recurrence_instance_key`) ردیف واقعی دارند.
@DataClassName('EventRow')
@TableIndex(name: 'idx_events_start_at', columns: {#startAtUtc})
@TableIndex(name: 'idx_events_end_at', columns: {#endAtUtc})
@TableIndex(name: 'idx_events_responsibility_start', columns: {
  #responsibilityId,
  #startAtUtc,
})
@TableIndex(name: 'idx_events_project_start', columns: {
  #projectId,
  #startAtUtc,
})
class Events extends Table {
  @override
  String get tableName => 'events';

  TextColumn get id => text()();

  TextColumn get responsibilityId => text()
      .named('responsibility_id')
      .references(Responsibilities, #id, onDelete: KeyAction.restrict)();

  TextColumn get title => text().withLength(min: 1, max: 200)();

  TextColumn get description => text().nullable()();

  TextColumn get location => text().nullable()();

  DateTimeColumn get startAtUtc => dateTime().named('start_at_utc')();

  DateTimeColumn get endAtUtc => dateTime().named('end_at_utc')();

  /// شناسه‌ی IANA منطقه‌ی زمانی زمان دیواری رویداد.
  TextColumn get timezoneId => text().named('timezone_id')();

  BoolColumn get allDay =>
      boolean().named('all_day').withDefault(const Constant(false))();

  TextColumn get status => text()
      .map(const EventStatusConverter())
      .withDefault(const Constant('planned'))();

  TextColumn get recurrenceRuleId => text()
      .named('recurrence_rule_id')
      .nullable()
      .references(RecurrenceRules, #id, onDelete: KeyAction.setNull)();

  /// کلید نمونه‌ی استثنا: تاریخ محلی `YYYY-MM-DD`. در ردیف master مقدار NULL.
  TextColumn get recurrenceInstanceKey =>
      text().named('recurrence_instance_key').nullable()();

  TextColumn get projectId => text()
      .named('project_id')
      .nullable()
      .references(Projects, #id, onDelete: KeyAction.setNull)();

  TextColumn get sourceTaskId => text()
      .named('source_task_id')
      .nullable()
      .references(Tasks, #id, onDelete: KeyAction.setNull)();

  DateTimeColumn get actualStartAtUtc =>
      dateTime().named('actual_start_at_utc').nullable()();

  DateTimeColumn get actualEndAtUtc =>
      dateTime().named('actual_end_at_utc').nullable()();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();

  @override
  Set<Column> get primaryKey => <Column>{id};

  @override
  List<String> get customConstraints => <String>[
    'CHECK (end_at_utc > start_at_utc)',
  ];
}
