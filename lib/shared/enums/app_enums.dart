import 'package:drift/drift.dart';

/// مقادیر متنی enumها در دیتابیس دقیقاً مطابق بخش ۱۰ سند انتخاب شده‌اند
/// (مثلاً `in_progress` و نه `inProgress`) تا داده‌ی ذخیره‌شده با طراحی سند
/// یکی باشد. تبدیل فقط در لایه‌ی Data انجام می‌شود.

enum Priority {
  low('low'),
  medium('medium'),
  high('high');

  const Priority(this.dbValue);

  final String dbValue;
}

enum TaskStatus {
  todo('todo'),
  inProgress('in_progress'),
  completed('completed'),
  cancelled('cancelled');

  const TaskStatus(this.dbValue);

  final String dbValue;
}

enum EventStatus {
  planned('planned'),
  completed('completed'),
  cancelled('cancelled');

  const EventStatus(this.dbValue);

  final String dbValue;
}

enum ProjectStatus {
  planned('planned'),
  active('active'),
  paused('paused'),
  completed('completed'),
  archived('archived');

  const ProjectStatus(this.dbValue);

  final String dbValue;
}

enum ProgressMode {
  automatic('automatic'),
  manual('manual');

  const ProgressMode(this.dbValue);

  final String dbValue;
}

enum RecurrenceFrequency {
  daily('daily'),
  weekly('weekly'),
  monthly('monthly'),
  yearly('yearly');

  const RecurrenceFrequency(this.dbValue);

  final String dbValue;
}

/// تبدیل‌گرهای Drift: ستون در SQLite متن است، در Dart enum.
class PriorityConverter extends TypeConverter<Priority, String> {
  const PriorityConverter();

  @override
  Priority fromSql(String fromDb) => Priority.values.firstWhere(
    (Priority value) => value.dbValue == fromDb,
    orElse: () => throw ArgumentError('اولویت نامعتبر در دیتابیس: $fromDb'),
  );

  @override
  String toSql(Priority value) => value.dbValue;
}

class TaskStatusConverter extends TypeConverter<TaskStatus, String> {
  const TaskStatusConverter();

  @override
  TaskStatus fromSql(String fromDb) => TaskStatus.values.firstWhere(
    (TaskStatus value) => value.dbValue == fromDb,
    orElse: () => throw ArgumentError('وضعیت وظیفه‌ی نامعتبر: $fromDb'),
  );

  @override
  String toSql(TaskStatus value) => value.dbValue;
}

class EventStatusConverter extends TypeConverter<EventStatus, String> {
  const EventStatusConverter();

  @override
  EventStatus fromSql(String fromDb) => EventStatus.values.firstWhere(
    (EventStatus value) => value.dbValue == fromDb,
    orElse: () => throw ArgumentError('وضعیت رویداد نامعتبر: $fromDb'),
  );

  @override
  String toSql(EventStatus value) => value.dbValue;
}

class ProjectStatusConverter extends TypeConverter<ProjectStatus, String> {
  const ProjectStatusConverter();

  @override
  ProjectStatus fromSql(String fromDb) => ProjectStatus.values.firstWhere(
    (ProjectStatus value) => value.dbValue == fromDb,
    orElse: () => throw ArgumentError('وضعیت پروژه نامعتبر: $fromDb'),
  );

  @override
  String toSql(ProjectStatus value) => value.dbValue;
}

class ProgressModeConverter extends TypeConverter<ProgressMode, String> {
  const ProgressModeConverter();

  @override
  ProgressMode fromSql(String fromDb) => ProgressMode.values.firstWhere(
    (ProgressMode value) => value.dbValue == fromDb,
    orElse: () => throw ArgumentError('روش پیشرفت نامعتبر: $fromDb'),
  );

  @override
  String toSql(ProgressMode value) => value.dbValue;
}

class RecurrenceFrequencyConverter
    extends TypeConverter<RecurrenceFrequency, String> {
  const RecurrenceFrequencyConverter();

  @override
  RecurrenceFrequency fromSql(String fromDb) =>
      RecurrenceFrequency.values.firstWhere(
        (RecurrenceFrequency value) => value.dbValue == fromDb,
        orElse: () => throw ArgumentError('فرکانس تکرار نامعتبر: $fromDb'),
      );

  @override
  String toSql(RecurrenceFrequency value) => value.dbValue;
}
