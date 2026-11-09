import 'package:drift/drift.dart';

import '../features/reminders/domain/reminder.dart';
import '../features/reminders/domain/reminder_plan.dart';
import 'app_database.dart';
import 'tables/reminders.dart';

/// قید «هر یادآوری دقیقاً یک والد» در این لایه هم اعمال می‌شود تا خطای
/// CHECK دیتابیس به پیام قابل‌فهم تبدیل شود (بخش ۱۰.۸ سند).
abstract class ReminderRepository {
  Future<Reminder?> forEvent(String eventId);

  Future<Reminder?> forTask(String taskId);

  /// یادآوری‌های فعال رویدادها، برای بازسازی پنجره‌ی اعلان‌ها.
  Future<List<Reminder>> enabledForEvents();

  Future<List<Reminder>> enabledForTasks();

  /// ساخت یا به‌روزرسانی یادآوری یک رویداد.
  ///
  /// [eventStartLocal] شروع نمونه‌ی مرجع است؛ برای رویداد تمام‌روز، پایه‌ی
  /// یادآوری ساعت ۹ صبح همان روز در نظر گرفته می‌شود، وگرنه نیمه‌شب.
  Future<Reminder> setForEvent({
    required String eventId,
    required DateTime eventStartLocal,
    bool allDay = false,
    required int? minutesBefore,
    bool isEnabled = true,
    bool isRecurring = false,
  });

  Future<Reminder> setForTask({
    required String taskId,
    required DateTime dueLocal,
    required int? minutesBefore,
    bool isEnabled = true,
  });

  /// حذف یادآوری رویداد/وظیفه (هنگام خاموش کردن یادآوری).
  Future<void> clearForEvent(String eventId);

  Future<void> clearForTask(String taskId);

  Future<void> setEnabled(String id, bool enabled);
}

/// ساعت پایه‌ی یادآوری رویداد تمام‌روز — بخش ۱۱.۹.
const int allDayReminderBaseMinutes = 9 * 60;

/// ساعت پایه‌ی یادآوری وظیفه‌ی بدون ساعت.
const int taskDefaultReminderBaseMinutes = 9 * 60;

class DriftReminderRepository implements ReminderRepository {
  DriftReminderRepository(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  @override
  Future<Reminder?> forEvent(String eventId) async {
    final ReminderRow? row = await (_db.select(_db.reminders)..where(
          (Reminders t) => t.eventId.equals(eventId),
        ))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<Reminder?> forTask(String taskId) async {
    final ReminderRow? row = await (_db.select(_db.reminders)..where(
          (Reminders t) => t.taskId.equals(taskId),
        ))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<List<Reminder>> enabledForEvents() async {
    final List<ReminderRow> rows = await (_db.select(_db.reminders)
          ..where((Reminders t) => t.eventId.isNotNull() & t.isEnabled.equals(true))
          ..orderBy(<OrderClauseGenerator<$RemindersTable>>[
            ($RemindersTable t) => OrderingTerm(expression: t.remindAtUtc),
          ]))
        .get();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<Reminder>> enabledForTasks() async {
    final List<ReminderRow> rows = await (_db.select(_db.reminders)
          ..where((Reminders t) => t.taskId.isNotNull() & t.isEnabled.equals(true))
          ..orderBy(<OrderClauseGenerator<$RemindersTable>>[
            ($RemindersTable t) => OrderingTerm(expression: t.remindAtUtc),
          ]))
        .get();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<Reminder> setForEvent({
    required String eventId,
    required DateTime eventStartLocal,
    bool allDay = false,
    required int? minutesBefore,
    bool isEnabled = true,
    bool isRecurring = false,
  }) {
    final DateTime base = allDay
        ? DateTime(
            eventStartLocal.year,
            eventStartLocal.month,
            eventStartLocal.day,
            allDayReminderBaseMinutes ~/ 60,
            allDayReminderBaseMinutes % 60,
          )
        : eventStartLocal;
    final int offset = minutesBefore == null
        ? 0
        : validateReminderOffset(minutesBefore);
    final DateTime remindAtUtc = base
        .subtract(Duration(minutes: offset))
        .toUtc();
    return _upsert(
      eventId: eventId,
      taskId: null,
      remindAtUtc: remindAtUtc,
      minutesBefore: minutesBefore,
      isEnabled: isEnabled,
      isRecurring: isRecurring,
    );
  }

  @override
  Future<Reminder> setForTask({
    required String taskId,
    required DateTime dueLocal,
    required int? minutesBefore,
    bool isEnabled = true,
  }) {
    final DateTime base = dueLocal.hour == 0 && dueLocal.minute == 0
        ? DateTime(
            dueLocal.year,
            dueLocal.month,
            dueLocal.day,
            taskDefaultReminderBaseMinutes ~/ 60,
            taskDefaultReminderBaseMinutes % 60,
          )
        : dueLocal;
    final int offset = minutesBefore == null
        ? 0
        : validateReminderOffset(minutesBefore);
    final DateTime remindAtUtc = base
        .subtract(Duration(minutes: offset))
        .toUtc();
    return _upsert(
      eventId: null,
      taskId: taskId,
      remindAtUtc: remindAtUtc,
      minutesBefore: minutesBefore,
      isEnabled: isEnabled,
      isRecurring: false,
    );
  }

  @override
  Future<void> clearForEvent(String eventId) async {
    await (_db.delete(_db.reminders)..where(
          (Reminders t) => t.eventId.equals(eventId),
        ))
        .go();
  }

  @override
  Future<void> clearForTask(String taskId) async {
    await (_db.delete(_db.reminders)..where(
          (Reminders t) => t.taskId.equals(taskId),
        ))
        .go();
  }

  @override
  Future<void> setEnabled(String id, bool enabled) async {
    final int updated =
        await (_db.update(_db.reminders)
              ..where((Reminders t) => t.id.equals(id)))
            .write(
              RemindersCompanion(
                isEnabled: Value<bool>(enabled),
                updatedAt: Value<DateTime>(_now().toUtc()),
              ),
            );
    if (updated == 0) {
      throw const ReminderValidationException('یادآوری موردنظر پیدا نشد.');
    }
  }

  Future<Reminder> _upsert({
    required String? eventId,
    required String? taskId,
    required DateTime remindAtUtc,
    required int? minutesBefore,
    required bool isEnabled,
    required bool isRecurring,
  }) async {
    if ((eventId == null) == (taskId == null)) {
      throw const ReminderValidationException(
        'هر یادآوری باید دقیقاً به یک رویداد یا یک وظیفه وصل باشد.',
      );
    }
    final ReminderRow? existing = await _selectRow(
      eventId: eventId,
      taskId: taskId,
    );

    final String id = existing?.id ?? newReminderId();
    // شناسه‌ی اعلان فقط برای والد غیرتکراری معنا دارد (بخش ۱۰.۸).
    final int? notificationId = isRecurring
        ? null
        : notificationIdFor(id, eventId ?? taskId!);

    await _db
        .into(_db.reminders)
        .insertOnConflictUpdate(
          RemindersCompanion.insert(
            id: id,
            eventId: Value<String?>(eventId),
            taskId: Value<String?>(taskId),
            remindAtUtc: remindAtUtc,
            minutesBefore: Value<int?>(minutesBefore),
            isEnabled: Value<bool>(isEnabled),
            notificationId: Value<int?>(notificationId),
            createdAt: existing?.createdAt.toUtc() ?? _now().toUtc(),
            updatedAt: _now().toUtc(),
          ),
        );

    return Reminder(
      id: id,
      eventId: eventId,
      taskId: taskId,
      remindAtUtc: remindAtUtc,
      minutesBefore: minutesBefore,
      isEnabled: isEnabled,
      notificationId: notificationId,
    );
  }

  Future<ReminderRow?> _selectRow({
    required String? eventId,
    required String? taskId,
  }) {
    final SimpleSelectStatement<$RemindersTable, ReminderRow> query = _db
        .select(_db.reminders);
    if (eventId != null) {
      query.where((Reminders t) => t.eventId.equals(eventId));
    } else {
      query.where((Reminders t) => t.taskId.equals(taskId!));
    }
    return query.getSingleOrNull();
  }

  Reminder _fromRow(ReminderRow row) {
    return Reminder(
      id: row.id,
      eventId: row.eventId,
      taskId: row.taskId,
      remindAtUtc: row.remindAtUtc.toUtc(),
      minutesBefore: row.minutesBefore,
      isEnabled: row.isEnabled,
      notificationId: row.notificationId,
    );
  }
}
