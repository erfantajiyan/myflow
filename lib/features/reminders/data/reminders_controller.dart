import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/data_revision_provider.dart';
import '../../../database/event_repository_impl.dart';
import '../../../database/reminder_repository_impl.dart';
import '../../../database/task_repository_impl.dart';
import '../domain/reminder.dart';
import 'reminder_sync_service.dart';

/// یادآوری یک رویداد؛ پس از هر تغییر داده تازه خوانده می‌شود.
final eventReminderProvider =
    FutureProvider.family<Reminder?, String>((Ref ref, String eventId) {
      ref.watch(dataRevisionProvider);
      return ref.watch(reminderRepositoryProvider).forEvent(eventId);
    });

/// یادآوری یک وظیفه.
final taskReminderProvider =
    FutureProvider.family<Reminder?, String>((Ref ref, String taskId) {
      ref.watch(dataRevisionProvider);
      return ref.watch(reminderRepositoryProvider).forTask(taskId);
    });

/// عملیات یادآوری از سمت UI.
///
/// هر تغییر، پنجره‌ی اعلان‌ها را بازسازی می‌کند تا معیار «اعلان باقی‌مانده
/// پس از حذف نداشته باشیم» (فاز ۱۰ سند) برقرار بماند.
class ReminderActions {
  ReminderActions(this._ref);

  final Ref _ref;

  ReminderRepository get _repository => _ref.read(reminderRepositoryProvider);

  /// یادآوری رویداد را تنظیم یا (با `null`) حذف می‌کند.
  ///
  /// برای نمونه‌ی یک سری، یادآوری روی ردیف master می‌نشیند و برای همه‌ی
  /// نمونه‌های آینده اعمال می‌شود (بخش ۱۱.۹).
  Future<void> setEventReminder({
    required Event event,
    required int? minutesBefore,
  }) async {
    final String masterId = event.masterId;
    if (minutesBefore == null) {
      await _repository.clearForEvent(masterId);
    } else {
      await _repository.setForEvent(
        eventId: masterId,
        eventStartLocal: event.startLocal,
        allDay: event.allDay,
        minutesBefore: minutesBefore,
        isRecurring: event.isOccurrence || event.recurrenceRuleId != null,
      );
    }
    _ref.read(dataRevisionProvider.notifier).bump();
    await sync();
  }

  /// یادآوری وظیفه؛ بدون تاریخ سررسید معنا ندارد و پاک می‌شود.
  Future<void> setTaskReminder({
    required Task task,
    required int? minutesBefore,
  }) async {
    final DateTime? due = task.dueDateLocal;
    if (minutesBefore == null || due == null) {
      await _repository.clearForTask(task.id);
    } else {
      final int? dueMinutes = _parseTime(task.dueTime);
      await _repository.setForTask(
        taskId: task.id,
        dueLocal: dueMinutes == null
            ? due
            : DateTime(
                due.year,
                due.month,
                due.day,
                dueMinutes ~/ 60,
                dueMinutes % 60,
              ),
        minutesBefore: minutesBefore,
      );
    }
    _ref.read(dataRevisionProvider.notifier).bump();
    await sync();
  }

  /// بازسازی دستی پنجره‌ی اعلان (از صفحه‌ی تنظیمات).
  Future<ReminderSyncResult> sync() async {
    return _ref.read(reminderSyncProvider).sync();
  }

  static int? _parseTime(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final List<String> parts = raw.split(':');
    final int? hour = int.tryParse(parts.first);
    final int? minute = parts.length > 1 ? int.tryParse(parts[1]) : 0;
    if (hour == null || minute == null) {
      return null;
    }
    return (hour * 60) + minute;
  }
}

final Provider<ReminderActions> reminderActionsProvider =
    Provider<ReminderActions>((Ref ref) => ReminderActions(ref));
