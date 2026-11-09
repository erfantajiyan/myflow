import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../database/database_providers.dart';
import '../../../database/event_repository_impl.dart';
import '../../../database/reminder_repository_impl.dart';
import '../../../database/settings_repository_impl.dart';
import '../../../database/task_repository_impl.dart';
import '../../events/data/events_controller.dart';
import '../../settings/data/settings_controller.dart';
import '../../settings/domain/app_settings.dart';
import '../../tasks/data/tasks_controller.dart';
import '../domain/reminder.dart';
import '../domain/reminder_plan.dart';
import 'flutter_notification_gateway.dart';
import 'notification_gateway.dart';

/// نتیجه‌ی یک بازسازی پنجره‌ی اعلان.
class ReminderSyncResult {
  const ReminderSyncResult({
    required this.scheduledCount,
    this.disabled = false,
    this.permissionDenied = false,
  });

  final int scheduledCount;
  final bool disabled;
  final bool permissionDenied;
}

/// بازسازی پنجره‌ی لغزان اعلان‌ها (بخش ۱۱.۹ سند).
///
/// در شروع برنامه، بعد از هر تغییر داده (ایجاد/ویرایش/حذف) و پس از تغییر
/// تنظیمات صدا زده می‌شود. هر بار همه‌ی اعلان‌های معلق لغو و از نو ساخته
/// می‌شوند تا اعلانِ والدِ حذف‌شده باقی نماند.
class ReminderSyncService {
  ReminderSyncService({
    required this.reminderRepository,
    required this.eventRepository,
    required this.taskRepository,
    required this.settingsRepository,
    required this.gateway,
    required this.now,
  });

  final ReminderRepository reminderRepository;
  final EventRepository eventRepository;
  final TaskRepository taskRepository;
  final SettingsRepository settingsRepository;
  final NotificationGateway gateway;
  final DateTime Function() now;

  ReminderSyncResult? lastResult;

  Future<ReminderSyncResult> sync() async {
    final AppSettings settings = await settingsRepository.load();
    if (!settings.notificationsEnabled) {
      await gateway.cancelAll();
      return lastResult = const ReminderSyncResult(
        scheduledCount: 0,
        disabled: true,
      );
    }

    final DateTime current = now();
    final DateTime today = DateTime(
      current.year,
      current.month,
      current.day,
    );
    final DateTime windowEnd = current.add(reminderWindow);

    final List<ReminderTarget> targets = <ReminderTarget>[
      ...await _eventTargets(
        settings,
        today: today,
        windowEnd: windowEnd,
      ),
      ...await _taskTargets(settings, today: today, windowEnd: windowEnd),
    ];

    final List<PlannedReminder> plan = buildReminderPlan(
      targets: targets,
      now: current,
    );

    await gateway.cancelAll();
    if (plan.isNotEmpty) {
      final bool granted = await gateway.requestPermission();
      if (!granted) {
        return lastResult = ReminderSyncResult(
          scheduledCount: 0,
          permissionDenied: true,
        );
      }
    }
    await gateway.scheduleAll(plan);
    return lastResult = ReminderSyncResult(scheduledCount: plan.length);
  }

  Future<List<ReminderTarget>> _eventTargets(
    AppSettings settings, {
    required DateTime today,
    required DateTime windowEnd,
  }) async {
    final List<Reminder> reminders = await reminderRepository
        .enabledForEvents();
    if (reminders.isEmpty) {
      return const <ReminderTarget>[];
    }

    final List<Event> events = await eventRepository.getEventsInRange(
      fromDay: today,
      toDay: windowEnd,
    );
    final Map<String, List<Event>> byMaster = <String, List<Event>>{};
    for (final Event event in events) {
      if (event.isCancelled) {
        continue;
      }
      byMaster.putIfAbsent(event.masterId, () => <Event>[]).add(event);
    }

    final List<ReminderTarget> targets = <ReminderTarget>[];
    for (final Reminder reminder in reminders) {
      final List<Event> group = byMaster[reminder.eventId] ?? <Event>[];
      if (group.isEmpty) {
        continue;
      }
      final Event reference = group.first;
      final bool allDay = reference.allDay;
      final List<ReminderOccurrence> occurrences = <ReminderOccurrence>[
        for (final Event event in group)
          ReminderOccurrence(
            instanceKey: event.recurrenceInstanceKey ?? event.id,
            startLocal: allDay
                ? DateTime(
                    event.startLocal.year,
                    event.startLocal.month,
                    event.startLocal.day,
                    allDayReminderBaseMinutes ~/ 60,
                    allDayReminderBaseMinutes % 60,
                  )
                : event.startLocal,
          ),
      ];
      final String body = allDay
          ? 'رویداد تمام‌روز — ${reference.title}'
          : 'شروع ${settings.formatTime(reference.startLocal)} — '
                '${reference.title}';
      targets.add(
        ReminderTarget(
          reminderId: reminder.id,
          parentId: reference.masterId,
          title: reference.title,
          body: body,
          minutesBefore: reminder.effectiveMinutesBefore,
          occurrences: occurrences,
        ),
      );
    }
    return targets;
  }

  Future<List<ReminderTarget>> _taskTargets(
    AppSettings settings, {
    required DateTime today,
    required DateTime windowEnd,
  }) async {
    final List<Reminder> reminders = await reminderRepository
        .enabledForTasks();
    if (reminders.isEmpty) {
      return const <ReminderTarget>[];
    }
    final List<Task> tasks = await taskRepository.getTasksDueBetween(
      fromDay: today,
      toDay: windowEnd,
    );
    final Map<String, Task> byId = <String, Task>{
      for (final Task task in tasks)
        if (!task.isCompleted && !task.isCancelled && !task.isArchived)
          task.id: task,
    };
    final List<ReminderTarget> targets = <ReminderTarget>[];
    for (final Reminder reminder in reminders) {
      final Task? task = byId[reminder.taskId];
      final DateTime? due = task?.dueDateLocal;
      if (task == null || due == null) {
        continue;
      }
      final int? dueMinutes = _parseTimeOfDay(task.dueTime);
      final DateTime start = dueMinutes == null
          ? DateTime(
              due.year,
              due.month,
              due.day,
              taskDefaultReminderBaseMinutes ~/ 60,
              taskDefaultReminderBaseMinutes % 60,
            )
          : DateTime(
              due.year,
              due.month,
              due.day,
              dueMinutes ~/ 60,
              dueMinutes % 60,
            );
      targets.add(
        ReminderTarget(
          reminderId: reminder.id,
          parentId: task.id,
          title: 'یادآوری وظیفه',
          body: task.title +
              (dueMinutes == null ? '' : ' — ${settings.formatTime(start)}'),
          minutesBefore: reminder.effectiveMinutesBefore,
          occurrences: <ReminderOccurrence>[
            ReminderOccurrence(instanceKey: task.id, startLocal: start),
          ],
        ),
      );
    }
    return targets;
  }

  static int? _parseTimeOfDay(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final List<String> parts = raw.split(':');
    if (parts.length < 2) {
      return null;
    }
    final int? hour = int.tryParse(parts[0]);
    final int? minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    return (hour * 60) + minute;
  }
}

/// درگاه اعلان مناسب پلتفرم فعلی.
final Provider<NotificationGateway> notificationGatewayProvider =
    Provider<NotificationGateway>((Ref ref) {
      if (kIsWeb) {
        return NoopNotificationGateway();
      }
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
        case TargetPlatform.iOS:
          return FlutterNotificationGateway();
        case TargetPlatform.linux:
        case TargetPlatform.macOS:
        case TargetPlatform.windows:
        case TargetPlatform.fuchsia:
          return NoopNotificationGateway();
      }
    });

final Provider<ReminderRepository> reminderRepositoryProvider =
    Provider<ReminderRepository>((Ref ref) {
      return DriftReminderRepository(ref.watch(appDatabaseProvider));
    });

/// سرویس مشترک بازسازی اعلان‌ها.
final Provider<ReminderSyncService> reminderSyncProvider =
    Provider<ReminderSyncService>((Ref ref) {
      return ReminderSyncService(
        reminderRepository: ref.watch(reminderRepositoryProvider),
        eventRepository: ref.watch(eventRepositoryProvider),
        taskRepository: ref.watch(taskRepositoryProvider),
        settingsRepository: ref.watch(settingsRepositoryProvider),
        gateway: ref.watch(notificationGatewayProvider),
        now: () => ref.read(nowProvider)(),
      );
    });
