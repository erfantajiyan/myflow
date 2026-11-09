import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myflow/database/app_database.dart';
import 'package:myflow/database/event_repository_impl.dart';
import 'package:myflow/database/reminder_repository_impl.dart';
import 'package:myflow/database/responsibility_repository_impl.dart';
import 'package:myflow/database/task_repository_impl.dart';
import 'package:myflow/shared/enums/app_enums.dart';
import 'package:myflow/features/reminders/domain/reminder.dart';

void main() {
  const String respId = 'resp-reminders';

  late AppDatabase db;
  late DriftReminderRepository reminders;
  late DriftEventRepository events;
  late DriftTaskRepository tasks;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    reminders = DriftReminderRepository(db);
    events = DriftEventRepository(db);
    tasks = DriftTaskRepository(db);
    await DriftResponsibilityRepository(db).insertResponsibility(
      id: respId,
      name: 'کار',
      color: const Color(0xFF5BA8FF),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<Event> createEvent({DateTime? start}) {
    return events.insertEvent(
      responsibilityId: respId,
      title: 'جلسه',
      startAt: start ?? DateTime(2026, 11, 10, 10),
      endAt: (start ?? DateTime(2026, 11, 10, 10)).add(
        const Duration(hours: 1),
      ),
    );
  }

  test('یادآوری رویداد ساخته و دوباره به‌روزرسانی می‌شود', () async {
    final Event event = await createEvent();

    final Reminder first = await reminders.setForEvent(
      eventId: event.id,
      eventStartLocal: event.startLocal,
      minutesBefore: 15,
    );
    expect(first.eventId, event.id);
    expect(first.taskId, isNull);
    expect(first.minutesBefore, 15);
    expect(first.notificationId, isNotNull);

    final Reminder second = await reminders.setForEvent(
      eventId: event.id,
      eventStartLocal: event.startLocal,
      minutesBefore: 30,
    );
    expect(second.id, first.id, reason: 'نباید ردیف تکراری ساخته شود');
    expect(second.minutesBefore, 30);

    final Reminder? loaded = await reminders.forEvent(event.id);
    expect(loaded?.minutesBefore, 30);
    expect((await reminders.enabledForEvents()), hasLength(1));
  });

  test('رویداد تمام‌روز از ساعت ۹ صبح یادآوری می‌شود', () async {
    final Event event = await events.insertEvent(
      responsibilityId: respId,
      title: 'تعطیل',
      startAt: DateTime(2026, 11, 10),
      endAt: DateTime(2026, 11, 11),
      allDay: true,
    );

    final Reminder reminder = await reminders.setForEvent(
      eventId: event.id,
      eventStartLocal: event.startLocal,
      allDay: true,
      minutesBefore: 0,
    );

    expect(reminder.remindAtUtc.toLocal(), DateTime(2026, 11, 10, 9));
  });

  test('رویداد تکراری شناسه‌ی اعلان ثابت ندارد', () async {
    final Event master = await events.createRecurringEvent(
      responsibilityId: respId,
      title: 'کلاس هفتگی',
      startAt: DateTime(2026, 11, 7, 10),
      endAt: DateTime(2026, 11, 7, 11),
      frequency: RecurrenceFrequency.weekly,
    );

    final Reminder reminder = await reminders.setForEvent(
      eventId: master.id,
      eventStartLocal: master.startLocal,
      minutesBefore: 10,
      isRecurring: true,
    );

    expect(reminder.notificationId, isNull);
    expect(reminder.eventId, master.id);
  });

  test('حذف رویداد یادآوری را هم پاک می‌کند', () async {
    final Event event = await createEvent();
    await reminders.setForEvent(
      eventId: event.id,
      eventStartLocal: event.startLocal,
      minutesBefore: 10,
    );

    await events.deleteEvent(event.id);

    expect(await reminders.forEvent(event.id), isNull);
    expect(await reminders.enabledForEvents(), isEmpty);
  });

  test('یادآوری وظیفه با ساعت سررسید', () async {
    final Task task = await tasks.insertTask(
      responsibilityId: respId,
      title: 'ارسال گزارش',
      dueDate: DateTime(2026, 11, 12),
      dueTime: '14:30',
    );

    final Reminder reminder = await reminders.setForTask(
      taskId: task.id,
      dueLocal: DateTime(2026, 11, 12, 14, 30),
      minutesBefore: 30,
    );

    expect(reminder.taskId, task.id);
    expect(reminder.eventId, isNull);
    expect(reminder.remindAtUtc.toLocal(), DateTime(2026, 11, 12, 14));
    expect(await reminders.enabledForTasks(), hasLength(1));

    await reminders.clearForTask(task.id);
    expect(await reminders.forTask(task.id), isNull);
  });

  test('فاصله‌ی نامعتبر رد می‌شود', () async {
    final Event event = await createEvent();

    expect(
      () => reminders.setForEvent(
        eventId: event.id,
        eventStartLocal: event.startLocal,
        minutesBefore: -1,
      ),
      throwsA(isA<ReminderValidationException>()),
    );
    expect(
      () => reminders.setForEvent(
        eventId: event.id,
        eventStartLocal: event.startLocal,
        minutesBefore: maxReminderOffsetMinutes + 1,
      ),
      throwsA(isA<ReminderValidationException>()),
    );
  });
}
