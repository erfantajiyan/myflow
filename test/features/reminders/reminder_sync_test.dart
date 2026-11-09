import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myflow/database/app_database.dart';
import 'package:myflow/database/event_repository_impl.dart';
import 'package:myflow/database/reminder_repository_impl.dart';
import 'package:myflow/database/responsibility_repository_impl.dart';
import 'package:myflow/database/settings_repository_impl.dart';
import 'package:myflow/database/task_repository_impl.dart';
import 'package:myflow/features/recurrence/domain/recurrence_rule.dart';
import 'package:myflow/features/reminders/data/notification_gateway.dart';
import 'package:myflow/features/reminders/data/reminder_sync_service.dart';
import 'package:myflow/features/reminders/domain/reminder.dart';
import 'package:myflow/features/reminders/domain/reminder_plan.dart';
import 'package:myflow/features/settings/domain/app_settings.dart';
import 'package:myflow/shared/enums/app_enums.dart';

void main() {
  const String respId = 'resp-sync';

  late AppDatabase db;
  late DriftEventRepository events;
  late DriftTaskRepository tasks;
  late DriftReminderRepository reminders;
  late DriftSettingsRepository settings;
  late NoopNotificationGateway gateway;
  late ReminderSyncService sync;

  final DateTime now = DateTime(2026, 3, 22, 8);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    events = DriftEventRepository(db);
    tasks = DriftTaskRepository(db);
    reminders = DriftReminderRepository(db);
    settings = DriftSettingsRepository(db);
    gateway = NoopNotificationGateway();
    sync = ReminderSyncService(
      reminderRepository: reminders,
      eventRepository: events,
      taskRepository: tasks,
      settingsRepository: settings,
      gateway: gateway,
      now: () => now,
    );
    await DriftResponsibilityRepository(db).insertResponsibility(
      id: respId,
      name: 'تحصیل',
      color: const Color(0xFF5BA8FF),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('نمونه‌های سری داخل پنجره زمان‌بندی می‌شوند', () async {
    final Event master = await events.createRecurringEvent(
      responsibilityId: respId,
      title: 'کلاس هفتگی',
      startAt: DateTime(2026, 3, 21, 10),
      endAt: DateTime(2026, 3, 21, 11),
      frequency: RecurrenceFrequency.weekly,
    );
    await reminders.setForEvent(
      eventId: master.id,
      eventStartLocal: master.startLocal,
      minutesBefore: 10,
      isRecurring: true,
    );

    final ReminderSyncResult result = await sync.sync();

    expect(result.disabled, isFalse);
    expect(gateway.cancelAllCalls, 1);
    expect(result.scheduledCount, 2, reason: '۲۸ مارس و ۴ آوریل');
    expect(gateway.lastScheduled, hasLength(2));
    expect(
      gateway.lastScheduled.first.whenLocal,
      DateTime(2026, 3, 28, 9, 50),
    );
    expect(gateway.lastScheduled.first.title, 'کلاس هفتگی');
    expect(gateway.lastScheduled.first.body, contains('شروع'));
  });

  test('حذف رویداد، اعلان باقی‌مانده نمی‌گذارد', () async {
    final Event event = await events.insertEvent(
      responsibilityId: respId,
      title: 'جلسه',
      startAt: DateTime(2026, 3, 25, 10),
      endAt: DateTime(2026, 3, 25, 11),
    );
    await reminders.setForEvent(
      eventId: event.id,
      eventStartLocal: event.startLocal,
      minutesBefore: 15,
    );
    expect((await sync.sync()).scheduledCount, 1);

    await events.deleteEvent(event.id);
    final ReminderSyncResult afterDelete = await sync.sync();

    expect(afterDelete.scheduledCount, 0);
    expect(gateway.lastScheduled, isEmpty);
  });

  test('خاموش‌کردن اعلان‌ها همه‌ی اعلان‌ها را لغو می‌کند', () async {
    final Event event = await events.insertEvent(
      responsibilityId: respId,
      title: 'جلسه',
      startAt: DateTime(2026, 3, 25, 10),
      endAt: DateTime(2026, 3, 25, 11),
    );
    await reminders.setForEvent(
      eventId: event.id,
      eventStartLocal: event.startLocal,
      minutesBefore: 0,
    );
    await settings.save(const AppSettings(notificationsEnabled: false));

    final ReminderSyncResult result = await sync.sync();

    expect(result.disabled, isTrue);
    expect(result.scheduledCount, 0);
    expect(gateway.lastScheduled, isEmpty);
  });

  test('یادآوری وظیفه با ساعت سررسید زمان‌بندی می‌شود', () async {
    final Task task = await tasks.insertTask(
      responsibilityId: respId,
      title: 'ارسال گزارش',
      dueDate: DateTime(2026, 3, 23),
      dueTime: '14:30',
    );
    await reminders.setForTask(
      taskId: task.id,
      dueLocal: DateTime(2026, 3, 23, 14, 30),
      minutesBefore: 30,
    );

    final ReminderSyncResult result = await sync.sync();

    expect(result.scheduledCount, 1);
    expect(gateway.lastScheduled.single.whenLocal, DateTime(2026, 3, 23, 14));
    expect(gateway.lastScheduled.single.body, contains('ارسال گزارش'));

    await tasks.completeTask(task.id);
    expect((await sync.sync()).scheduledCount, 0);
  });

  test('نمونه‌ی لغوشده اعلان نمی‌گیرد', () async {
    final Event master = await events.createRecurringEvent(
      responsibilityId: respId,
      title: 'کلاس هفتگی',
      startAt: DateTime(2026, 3, 21, 10),
      endAt: DateTime(2026, 3, 21, 11),
      frequency: RecurrenceFrequency.weekly,
    );
    await reminders.setForEvent(
      eventId: master.id,
      eventStartLocal: master.startLocal,
      minutesBefore: 0,
      isRecurring: true,
    );

    await events.deleteOccurrence(
      occurrenceId: '${master.id}@2026-03-28',
      scope: RecurrenceEditScope.thisOnly,
    );

    final ReminderSyncResult result = await sync.sync();

    expect(result.scheduledCount, 1);
    expect(gateway.lastScheduled.single.whenLocal, DateTime(2026, 4, 4, 10));
  });

  test('شکستن سری یادآوری را به master جدید منتقل می‌کند', () async {
    final Event master = await events.createRecurringEvent(
      responsibilityId: respId,
      title: 'کلاس هفتگی',
      startAt: DateTime(2026, 3, 21, 10),
      endAt: DateTime(2026, 3, 21, 11),
      frequency: RecurrenceFrequency.weekly,
    );
    await reminders.setForEvent(
      eventId: master.id,
      eventStartLocal: master.startLocal,
      minutesBefore: 10,
      isRecurring: true,
    );

    await events.updateOccurrence(
      occurrenceId: '${master.id}@2026-04-04',
      scope: RecurrenceEditScope.thisAndFollowing,
      title: 'کلاس جدید',
    );

    expect(await reminders.forEvent(master.id), isNull);
    final List<Reminder> enabled = await reminders.enabledForEvents();
    expect(enabled, hasLength(1));
    expect(enabled.single.eventId, isNot(master.id));

    final ReminderSyncResult result = await sync.sync();
    expect(result.scheduledCount, 1, reason: 'فقط نمونه‌ی ۴ آوریل در پنجره است');
    expect(
      gateway.lastScheduled.any(
        (PlannedReminder reminder) => reminder.title == 'کلاس جدید',
      ),
      isTrue,
    );
  });
}
