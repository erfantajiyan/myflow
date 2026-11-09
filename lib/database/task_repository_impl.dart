import 'package:drift/drift.dart';

import '../core/date_time/date_only.dart';
import '../shared/enums/app_enums.dart';
import 'app_database.dart';
import 'row_id.dart';

/// خطاهای لایه‌ی وظیفه.
sealed class TaskRepositoryException implements Exception {
  const TaskRepositoryException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

final class TaskValidationException extends TaskRepositoryException {
  const TaskValidationException(super.message);
}

final class TaskNotFoundException extends TaskRepositoryException {
  const TaskNotFoundException(this.id) : super('وظیفه با شناسه‌ی «$id» پیدا نشد.');

  final String id;
}

/// فیلترهای فهرست وظایف (بخش ۷.۴ سند).
enum TaskFilter {
  all('همه'),
  today('امروز'),
  upcoming('آینده'),
  overdue('عقب‌افتاده'),
  completed('تکمیل‌شده');

  const TaskFilter(this.label);

  final String label;
}

/// مدل دامنه‌ی وظیفه.
///
/// `dueDate` تاریخ بدون ساعت میلادی (`YYYY-MM-DD`) است و `dueTime` ساعت
/// اختیاری (`HH:mm:ss`)؛ دقیقاً مطابق ستون‌های جدول `tasks`.
class Task {
  const Task({
    required this.id,
    required this.responsibilityId,
    required this.title,
    required this.priority,
    required this.status,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.projectId,
    this.description,
    this.dueDate,
    this.dueTime,
    this.estimatedMinutes,
    this.completedAtUtc,
    this.archivedAt,
  });

  final String id;
  final String responsibilityId;
  final String? projectId;
  final String title;
  final String? description;
  final Priority priority;
  final TaskStatus status;

  /// `YYYY-MM-DD` میلادی محلی یا `null`.
  final String? dueDate;

  /// `HH:mm:ss` یا `null`.
  final String? dueTime;

  final int? estimatedMinutes;
  final DateTime? completedAtUtc;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  bool get isCompleted => status == TaskStatus.completed;

  bool get isCancelled => status == TaskStatus.cancelled;

  bool get isArchived => archivedAt != null;

  /// آیا وظیفه ساعت دارد؟ (بدون ساعت، تاریخ سررسید هم می‌تواند داشته باشد)
  bool get hasTime => dueTime != null;

  DateTime? get dueDateLocal => parseDateOnly(dueDate);

  /// سررسید گذشته و انجام‌نشده.
  bool isOverdue(DateTime today) {
    final DateTime? due = dueDateLocal;
    if (due == null || isCompleted || isCancelled) {
      return false;
    }
    return due.isBefore(DateTime(today.year, today.month, today.day));
  }

  bool isDueToday(DateTime today) {
    final DateTime? due = dueDateLocal;
    if (due == null) {
      return false;
    }
    return due.year == today.year &&
        due.month == today.month &&
        due.day == today.day;
  }
}

abstract class TaskRepository {
  /// وظایف فیلترشده، مرتب بر اساس سررسید (بدون سررسید در انتها).
  Future<List<Task>> getTasks({
    TaskFilter filter = TaskFilter.all,
    String? responsibilityId,
    String? projectId,
    DateTime? today,
  });

  Future<Task?> getTaskById(String id);

  /// همه‌ی وظایف یک پروژه (برای محاسبه‌ی پیشرفت).
  Future<List<Task>> getTasksForProject(String projectId);

  /// وظایف بایگانی‌نشده‌ای که تاریخ سررسیدشان بین [fromDay] و [toDay]
  /// (شامل هر دو سر) است، مرتب بر اساس تاریخ و ساعت.
  ///
  /// وظایف بدون تاریخ سررسید در این بازه نمی‌گنجند؛ تقویم فقط کارهای
  /// تاریخ‌دار را نشان می‌دهد (بخش ۱۰.۵: تاریخ بدون ساعت، timestamp نیست).
  Future<List<Task>> getTasksDueBetween({
    required DateTime fromDay,
    required DateTime toDay,
  });

  Future<Task> insertTask({
    String? id,
    required String responsibilityId,
    required String title,
    String? projectId,
    String? description,
    Priority priority = Priority.medium,
    TaskStatus status = TaskStatus.todo,
    DateTime? dueDate,
    String? dueTime,
    int? estimatedMinutes,
    int sortOrder = 0,
  });

  Future<void> updateTask({
    required String id,
    String? responsibilityId,
    String? projectId,
    String? title,
    String? description,
    Priority? priority,
    TaskStatus? status,
    DateTime? dueDate,
    String? dueTime,
    int? estimatedMinutes,
    int? sortOrder,
    bool clearProjectId = false,
    bool clearDueDate = false,
    bool clearDueTime = false,
  });

  /// تکمیل: وضعیت `completed` و ثبت `completedAtUtc` (قید CHECK جدول).
  Future<void> completeTask(String id);

  /// بازگشایی: وضعیت `todo` و پاک کردن `completedAtUtc`.
  Future<void> reopenTask(String id);

  /// بایگانی (حذف نرم): از فهرست‌ها بیرون می‌رود ولی داده می‌ماند.
  Future<void> archiveTask(String id);

  Future<void> permanentlyDeleteTask(String id);
}

Task _fromRow(TaskRow row) {
  return Task(
    id: row.id,
    responsibilityId: row.responsibilityId,
    projectId: row.projectId,
    title: row.title,
    description: row.description,
    priority: row.priority,
    status: row.status,
    dueDate: row.dueDate,
    dueTime: row.dueTimeLocal,
    estimatedMinutes: row.estimatedMinutes,
    completedAtUtc: row.completedAtUtc?.toUtc(),
    sortOrder: row.sortOrder,
    createdAt: row.createdAt.toUtc(),
    updatedAt: row.updatedAt.toUtc(),
    archivedAt: row.archivedAt?.toUtc(),
  );
}

String _validateTitle(String title) {
  final String trimmed = title.trim();
  if (trimmed.isEmpty) {
    throw const TaskValidationException('عنوان وظیفه نمی‌تواند خالی باشد.');
  }
  if (trimmed.length > 200) {
    throw const TaskValidationException(
      'عنوان وظیفه نباید بیشتر از ۲۰۰ کاراکتر باشد.',
    );
  }
  return trimmed;
}

int? _validateEstimate(int? minutes) {
  if (minutes == null) {
    return null;
  }
  if (minutes <= 0) {
    throw const TaskValidationException(
      'زمان تخمینی باید بیشتر از صفر دقیقه باشد.',
    );
  }
  return minutes;
}

/// `HH:mm` یا `HH:mm:ss` را به `HH:mm:ss` نرمال می‌کند.
String? _normalizeTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }
  final List<String> parts = raw.trim().split(':');
  if (parts.length < 2 || parts.length > 3) {
    throw const TaskValidationException('ساعت را به شکل ۱۰:۳۰ وارد کنید.');
  }
  final int? hour = int.tryParse(parts[0]);
  final int? minute = int.tryParse(parts[1]);
  final int second = parts.length == 3 ? (int.tryParse(parts[2]) ?? 0) : 0;
  if (hour == null || minute == null) {
    throw const TaskValidationException('ساعت را به شکل ۱۰:۳۰ وارد کنید.');
  }
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    throw const TaskValidationException('ساعت نامعتبر است.');
  }
  final String hh = hour.toString().padLeft(2, '0');
  final String mm = minute.toString().padLeft(2, '0');
  final String ss = second.toString().padLeft(2, '0');
  return '$hh:$mm:$ss';
}

/// پیاده‌سازی [TaskRepository] روی Drift.
class DriftTaskRepository implements TaskRepository {
  DriftTaskRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<Task>> getTasks({
    TaskFilter filter = TaskFilter.all,
    String? responsibilityId,
    String? projectId,
    DateTime? today,
  }) async {
    final DateTime todayDate = today ?? DateTime.now();
    final String todayText = formatDateOnly(todayDate);

    final query = _db.select(_db.tasks)
      ..where((t) => t.archivedAt.isNull());

    if (responsibilityId != null) {
      query.where((t) => t.responsibilityId.equals(responsibilityId));
    }
    if (projectId != null) {
      query.where((t) => t.projectId.equals(projectId));
    }

    switch (filter) {
      case TaskFilter.all:
        break;
      case TaskFilter.today:
        query.where((t) => t.dueDate.equals(todayText));
      case TaskFilter.upcoming:
        query.where((t) => t.dueDate.isBiggerThanValue(todayText));
        query.where((t) => t.status.equalsValue(TaskStatus.completed).not());
      case TaskFilter.overdue:
        query.where((t) => t.dueDate.isSmallerThanValue(todayText));
        query.where((t) => t.status.equalsValue(TaskStatus.completed).not());
      case TaskFilter.completed:
        query.where((t) => t.status.equalsValue(TaskStatus.completed));
    }

    final List<TaskRow> rows = await query.get();
    final List<Task> tasks = rows.map(_fromRow).toList();
    tasks.sort(_compareTasks);
    return tasks;
  }

  @override
  Future<Task?> getTaskById(String id) async {
    final TaskRow? row = await (_db.select(_db.tasks)
          ..where((t) => t.id.equals(id) & t.archivedAt.isNull()))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<List<Task>> getTasksForProject(String projectId) async {
    final List<TaskRow> rows = await (_db.select(_db.tasks)
          ..where(
            (t) => t.projectId.equals(projectId) & t.archivedAt.isNull(),
          ))
        .get();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<Task>> getTasksDueBetween({
    required DateTime fromDay,
    required DateTime toDay,
  }) async {
    final String fromText = formatDateOnly(fromDay);
    final String toText = formatDateOnly(toDay);

    final List<TaskRow> rows = await (_db.select(_db.tasks)
          ..where(
            (t) =>
                t.archivedAt.isNull() &
                t.dueDate.isBetweenValues(fromText, toText),
          ))
        .get();
    final List<Task> tasks = rows.map(_fromRow).toList();
    tasks.sort(_compareTasks);
    return tasks;
  }

  @override
  Future<Task> insertTask({
    String? id,
    required String responsibilityId,
    required String title,
    String? projectId,
    String? description,
    Priority priority = Priority.medium,
    TaskStatus status = TaskStatus.todo,
    DateTime? dueDate,
    String? dueTime,
    int? estimatedMinutes,
    int sortOrder = 0,
  }) async {
    final String taskId = id ?? _newId();
    final String? normalizedTime = _normalizeTime(dueTime);
    final DateTime now = DateTime.now().toUtc();

    if (normalizedTime != null && dueDate == null) {
      throw const TaskValidationException(
        'برای ثبت ساعت، تاریخ سررسید هم لازم است.',
      );
    }

    await _db.into(_db.tasks).insert(
          TasksCompanion.insert(
            id: taskId,
            responsibilityId: responsibilityId,
            title: _validateTitle(title),
            projectId: Value<String?>(projectId),
            description: Value<String?>(description),
            priority: Value<Priority>(priority),
            status: Value<TaskStatus>(status),
            dueDate: Value<String?>(
              dueDate == null ? null : formatDateOnly(dueDate),
            ),
            dueTimeLocal: Value<String?>(normalizedTime),
            estimatedMinutes: Value<int?>(_validateEstimate(estimatedMinutes)),
            // قید CHECK: وضعیت completed بدون completedAtUtc مجاز نیست.
            completedAtUtc: Value<DateTime?>(
              status == TaskStatus.completed ? now : null,
            ),
            sortOrder: Value<int>(sortOrder),
            createdAt: now,
            updatedAt: now,
          ),
        );

    final Task? inserted = await getTaskById(taskId);
    if (inserted == null) {
      throw TaskNotFoundException(taskId);
    }
    return inserted;
  }

  @override
  Future<void> updateTask({
    required String id,
    String? responsibilityId,
    String? projectId,
    String? title,
    String? description,
    Priority? priority,
    TaskStatus? status,
    DateTime? dueDate,
    String? dueTime,
    int? estimatedMinutes,
    int? sortOrder,
    bool clearProjectId = false,
    bool clearDueDate = false,
    bool clearDueTime = false,
  }) async {
    final Task? existing = await getTaskById(id);
    if (existing == null) {
      throw TaskNotFoundException(id);
    }

    final String? normalizedTime = _normalizeTime(dueTime);
    final String? nextDueDate = clearDueDate
        ? null
        : (dueDate == null ? existing.dueDate : formatDateOnly(dueDate));
    final String? nextTime = clearDueTime
        ? null
        : (normalizedTime ?? existing.dueTime);

    if (nextTime != null && nextDueDate == null) {
      throw const TaskValidationException(
        'وظیفه‌ی ساعت‌دار باید تاریخ سررسید داشته باشد.',
      );
    }

    final DateTime now = DateTime.now().toUtc();
    final TaskStatus? nextStatus = status;

    await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        responsibilityId: responsibilityId != null
            ? Value<String>(responsibilityId)
            : const Value<String>.absent(),
        projectId: clearProjectId
            ? const Value<String?>(null)
            : (projectId != null
                  ? Value<String?>(projectId)
                  : const Value<String?>.absent()),
        title: title != null
            ? Value<String>(_validateTitle(title))
            : const Value<String>.absent(),
        description: description != null
            ? Value<String?>(description)
            : const Value<String?>.absent(),
        priority: priority != null
            ? Value<Priority>(priority)
            : const Value<Priority>.absent(),
        status: nextStatus != null
            ? Value<TaskStatus>(nextStatus)
            : const Value<TaskStatus>.absent(),
        dueDate: (clearDueDate || dueDate != null)
            ? Value<String?>(nextDueDate)
            : const Value<String?>.absent(),
        dueTimeLocal: (clearDueTime || normalizedTime != null)
            ? Value<String?>(nextTime)
            : const Value<String?>.absent(),
        estimatedMinutes: estimatedMinutes != null
            ? Value<int?>(_validateEstimate(estimatedMinutes))
            : const Value<int?>.absent(),
        // با تغییر وضعیت، مهر تکمیل هم هم‌زمان درست می‌شود (قید CHECK).
        completedAtUtc: nextStatus == null
            ? const Value<DateTime?>.absent()
            : switch (nextStatus) {
                TaskStatus.completed =>
                  Value<DateTime?>(existing.completedAtUtc ?? now),
                _ => const Value<DateTime?>(null),
              },
        sortOrder: sortOrder != null
            ? Value<int>(sortOrder)
            : const Value<int>.absent(),
        updatedAt: Value<DateTime>(now),
      ),
    );
  }

  @override
  Future<void> completeTask(String id) async {
    final Task? existing = await getTaskById(id);
    if (existing == null) {
      throw TaskNotFoundException(id);
    }
    final DateTime now = DateTime.now().toUtc();
    await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        status: const Value<TaskStatus>(TaskStatus.completed),
        completedAtUtc: Value<DateTime?>(existing.completedAtUtc ?? now),
        updatedAt: Value<DateTime>(now),
      ),
    );
  }

  @override
  Future<void> reopenTask(String id) async {
    final Task? existing = await getTaskById(id);
    if (existing == null) {
      throw TaskNotFoundException(id);
    }
    await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        status: const Value<TaskStatus>(TaskStatus.todo),
        completedAtUtc: const Value<DateTime?>(null),
        updatedAt: Value<DateTime>(DateTime.now().toUtc()),
      ),
    );
  }

  @override
  Future<void> archiveTask(String id) async {
    final Task? existing = await getTaskById(id);
    if (existing == null) {
      throw TaskNotFoundException(id);
    }
    final DateTime now = DateTime.now().toUtc();
    await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        archivedAt: Value<DateTime>(now),
        updatedAt: Value<DateTime>(now),
      ),
    );
  }

  @override
  Future<void> permanentlyDeleteTask(String id) async {
    await (_db.delete(_db.tasks)..where((t) => t.id.equals(id))).go();
  }

  int _compareTasks(Task a, Task b) {
    final String? first = a.dueDate;
    final String? second = b.dueDate;
    if (first == null && second == null) {
      return a.sortOrder.compareTo(b.sortOrder);
    }
    if (first == null) {
      return 1;
    }
    if (second == null) {
      return -1;
    }
    final int byDate = first.compareTo(second);
    if (byDate != 0) {
      return byDate;
    }
    final int byTime = (a.dueTime ?? '').compareTo(b.dueTime ?? '');
    if (byTime != 0) {
      return byTime;
    }
    return a.sortOrder.compareTo(b.sortOrder);
  }

  String _newId() => newRowId('task');
}
