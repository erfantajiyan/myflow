import 'package:drift/drift.dart';

import 'tables/app_metadata.dart';
import 'tables/events.dart';
import 'tables/projects.dart';
import 'tables/recurrence_rules.dart';
import 'tables/reminders.dart';
import 'tables/responsibilities.dart';
import 'tables/settings.dart';
import 'tables/tasks.dart';

part 'app_database.g.dart';

/// دیتابیس محلی MyFlow — هسته‌ی ذخیره‌سازی آفلاین (بخش ۱۰ سند).
///
/// ترتیب ساخت جدول‌ها در migration مطابق سند است:
/// `responsibilities` → `projects` → `recurrence_rules` → `events` → `tasks`
/// → `reminders` → `settings` → `app_metadata`.
@DriftDatabase(
  tables: <Type>[
    Responsibilities,
    Projects,
    RecurrenceRules,
    Events,
    Tasks,
    Reminders,
    Settings,
    AppMetadata,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();

      // قید یکتایی نمونه‌های استثنا (بخش ۲۰.۹ سند): برای هر قاعده، هر کلید
      // نمونه فقط یک ردیف واقعی می‌تواند داشته باشد. ایندکس جزئی است تا
      // ردیف‌های عادی (با کلید NULL) تحت تأثیر قرار نگیرند.
      await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS '
        'idx_events_recurrence_instance_unique '
        'ON events (recurrence_rule_id, recurrence_instance_key) '
        'WHERE recurrence_rule_id IS NOT NULL '
        'AND recurrence_instance_key IS NOT NULL',
      );

      // ردیف فراداده‌ی نسخه‌ی schema، پایه‌ی migrationهای بعدی.
      await customStatement(
        "INSERT OR IGNORE INTO app_metadata (key, value, updated_at) "
        "VALUES ('database_version', '1', ${DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000})",
      );
    },
    beforeOpen: (OpeningDetails details) async {
      // SQLite بدون این pragma روابط را enforce نمی‌کند (بخش ۲۰.۱۲ سند).
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
