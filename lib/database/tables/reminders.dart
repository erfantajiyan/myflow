import 'package:drift/drift.dart';

import 'events.dart';
import 'tasks.dart';
export '../../shared/enums/app_enums.dart';

/// یادآوری‌ها — جدول `reminders` (بخش ۱۰.۸ سند).
///
/// قید مهم: هر یادآوری دقیقاً یک والد دارد؛ یا رویداد یا وظیفه (بخش ۲۰.۱۰).
@DataClassName('ReminderRow')
@TableIndex(name: 'idx_reminders_remind_at', columns: {#remindAtUtc, #isEnabled})
class Reminders extends Table {
  @override
  String get tableName => 'reminders';

  TextColumn get id => text()();

  TextColumn get eventId => text()
      .named('event_id')
      .nullable()
      .references(Events, #id, onDelete: KeyAction.cascade)();

  TextColumn get taskId => text()
      .named('task_id')
      .nullable()
      .references(Tasks, #id, onDelete: KeyAction.cascade)();

  DateTimeColumn get remindAtUtc => dateTime().named('remind_at_utc')();

  IntColumn get minutesBefore => integer().named('minutes_before').nullable()();

  BoolColumn get isEnabled =>
      boolean().named('is_enabled').withDefault(const Constant(true))();

  IntColumn get notificationId =>
      integer().named('notification_id').nullable()();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column> get primaryKey => <Column>{id};

  @override
  List<String> get customConstraints => <String>[
    'CHECK ((event_id IS NOT NULL AND task_id IS NULL) OR '
        '(event_id IS NULL AND task_id IS NOT NULL))',
  ];
}
