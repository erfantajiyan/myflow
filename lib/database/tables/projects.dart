import 'package:drift/drift.dart';

import '../../shared/enums/app_enums.dart';
export '../../shared/enums/app_enums.dart';
import 'responsibilities.dart';

/// پروژه‌ها — جدول `projects` (بخش ۱۰.۶ سند).
///
/// از اولین migration ساخته می‌شود تا `tasks.project_id` و `events.project_id`
/// از روز اول FK واقعی داشته باشند (بخش ۲۰.۱).
@DataClassName('ProjectRow')
@TableIndex(name: 'idx_projects_responsibility_status', columns: {
  #responsibilityId,
  #status,
})
@TableIndex(name: 'idx_projects_due_date', columns: {#dueDate})
@TableIndex(name: 'idx_projects_updated_at', columns: {#updatedAt})
class Projects extends Table {
  @override
  String get tableName => 'projects';

  TextColumn get id => text()();

  TextColumn get responsibilityId => text()
      .named('responsibility_id')
      .references(Responsibilities, #id, onDelete: KeyAction.restrict)();

  TextColumn get title => text().withLength(min: 1, max: 120)();

  TextColumn get description => text().nullable()();

  TextColumn get status => text()
      .map(const ProjectStatusConverter())
      .withDefault(const Constant('planned'))();

  TextColumn get priority => text()
      .map(const PriorityConverter())
      .withDefault(const Constant('medium'))();

  /// تاریخ بدون ساعت، میلادیِ محلی به شکل `YYYY-MM-DD` (بخش ۲۰.۴).
  TextColumn get startDate => text().named('start_date').nullable()();

  TextColumn get dueDate => text().named('due_date').nullable()();

  TextColumn get colorHex =>
      text().named('color_hex').withLength(min: 7, max: 9).nullable()();

  TextColumn get iconKey => text().named('icon_key').nullable()();

  TextColumn get progressMode => text()
      .named('progress_mode')
      .map(const ProgressModeConverter())
      .withDefault(const Constant('automatic'))();

  IntColumn get manualProgress =>
      integer().named('manual_progress').nullable()();

  DateTimeColumn get completedAtUtc =>
      dateTime().named('completed_at_utc').nullable()();

  DateTimeColumn get createdAt => dateTime().named('created_at_utc')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at_utc')();

  DateTimeColumn get archivedAt => dateTime().named('archived_at_utc').nullable()();

  @override
  Set<Column> get primaryKey => <Column>{id};

  @override
  List<String> get customConstraints => <String>[
    // برای امکان composite FK در آینده (بخش ۲۰.۲)
    'UNIQUE (id, responsibility_id)',
    'CHECK (due_date IS NULL OR start_date IS NULL OR due_date >= start_date)',
    'CHECK (manual_progress IS NULL OR '
        '(manual_progress >= 0 AND manual_progress <= 100))',
    "CHECK ((progress_mode = 'manual' AND manual_progress IS NOT NULL) OR "
        "(progress_mode = 'automatic' AND manual_progress IS NULL))",
    "CHECK (status != 'archived' OR archived_at_utc IS NOT NULL)",
  ];
}
