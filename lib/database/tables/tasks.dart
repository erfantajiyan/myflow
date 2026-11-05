import 'package:drift/drift.dart';

export '../../shared/enums/app_enums.dart';
import 'projects.dart';
import 'responsibilities.dart';

/// وظایف — جدول `tasks` (بخش ۱۰.۵ سند).
///
/// `due_date` تاریخ بدون ساعت است و هرگز به timestamp تبدیل نمی‌شود
/// (بخش ۲۰.۴)؛ ساعت اختیاری در `due_time_local` نگه داشته می‌شود.
@DataClassName('TaskRow')
@TableIndex(name: 'idx_tasks_status_due', columns: {#status, #dueDate})
@TableIndex(name: 'idx_tasks_responsibility_status', columns: {
  #responsibilityId,
  #status,
})
@TableIndex(name: 'idx_tasks_project', columns: {#projectId})
@TableIndex(name: 'idx_tasks_project_status_due', columns: {
  #projectId,
  #status,
  #dueDate,
})
class Tasks extends Table {
  @override
  String get tableName => 'tasks';

  TextColumn get id => text()();

  TextColumn get responsibilityId => text()
      .named('responsibility_id')
      .references(Responsibilities, #id, onDelete: KeyAction.restrict)();

  TextColumn get projectId => text()
      .named('project_id')
      .nullable()
      .references(Projects, #id, onDelete: KeyAction.setNull)();

  TextColumn get title => text().withLength(min: 1, max: 200)();

  TextColumn get description => text().nullable()();

  TextColumn get priority => text()
      .map(const PriorityConverter())
      .withDefault(const Constant('medium'))();

  TextColumn get status => text()
      .map(const TaskStatusConverter())
      .withDefault(const Constant('todo'))();

  /// تاریخ سررسید Gregorian بدون ساعت: `YYYY-MM-DD`.
  TextColumn get dueDate => text().named('due_date').nullable()();

  /// ساعت اختیاری سررسید: `HH:mm:ss`. NULL یعنی فقط تاریخ.
  TextColumn get dueTimeLocal => text().named('due_time_local').nullable()();

  IntColumn get estimatedMinutes =>
      integer().named('estimated_minutes').nullable()();

  DateTimeColumn get completedAtUtc =>
      dateTime().named('completed_at_utc').nullable()();

  IntColumn get sortOrder =>
      integer().named('sort_order').withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  DateTimeColumn get archivedAt => dateTime().named('archived_at').nullable()();

  @override
  Set<Column> get primaryKey => <Column>{id};

  @override
  List<String> get customConstraints => <String>[
    'CHECK (estimated_minutes IS NULL OR estimated_minutes > 0)',
    "CHECK (status != 'completed' OR completed_at_utc IS NOT NULL)",
  ];
}
