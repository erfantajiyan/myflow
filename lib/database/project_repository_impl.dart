import 'package:drift/drift.dart';
import 'package:flutter/painting.dart';

import '../core/date_time/date_only.dart';
import '../shared/enums/app_enums.dart';
import 'app_database.dart';
import 'responsibility_repository_impl.dart'
    show hexToColor, ResponsibilityRepositoryException;

/// خطاهای لایه‌ی پروژه.
sealed class ProjectRepositoryException implements Exception {
  const ProjectRepositoryException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

final class ProjectValidationException extends ProjectRepositoryException {
  const ProjectValidationException(super.message);
}

final class ProjectNotFoundException extends ProjectRepositoryException {
  const ProjectNotFoundException(this.id)
    : super('پروژه با شناسه‌ی «$id» پیدا نشد.');

  final String id;
}

/// مدل دامنه‌ی پروژه.
class Project {
  const Project({
    required this.id,
    required this.responsibilityId,
    required this.title,
    required this.status,
    required this.priority,
    required this.progressMode,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.startDate,
    this.dueDate,
    this.colorHex,
    this.iconKey,
    this.manualProgress,
    this.completedAtUtc,
    this.archivedAt,
  });

  final String id;
  final String responsibilityId;
  final String title;
  final String? description;
  final ProjectStatus status;
  final Priority priority;

  /// `YYYY-MM-DD` میلادی محلی.
  final String? startDate;
  final String? dueDate;

  final String? colorHex;
  final String? iconKey;
  final ProgressMode progressMode;

  /// فقط در حالت دستی مقدار دارد (قید CHECK جدول).
  final int? manualProgress;

  final DateTime? completedAtUtc;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  bool get isArchived =>
      status == ProjectStatus.archived || archivedAt != null;

  bool get isCompleted => status == ProjectStatus.completed;

  DateTime? get startDateLocal => parseDateOnly(startDate);

  DateTime? get dueDateLocal => parseDateOnly(dueDate);

  Color? get color {
    final String? hex = colorHex;
    if (hex == null || hex.isEmpty) {
      return null;
    }
    try {
      return hexToColor(hex);
    } on ResponsibilityRepositoryException {
      return null;
    }
  }
}

/// پیشرفت یک پروژه.
class ProjectProgress {
  const ProjectProgress({
    required this.percent,
    required this.totalTasks,
    required this.completedTasks,
  });

  final int percent;
  final int totalTasks;
  final int completedTasks;

  bool get hasTasks => totalTasks > 0;
}

/// پروژه به‌همراه پیشرفت محاسبه‌شده.
class ProjectSummary {
  const ProjectSummary({required this.project, required this.progress});

  final Project project;
  final ProjectProgress progress;
}

abstract class ProjectRepository {
  Future<List<ProjectSummary>> getProjectSummaries({
    bool includeArchived = false,
  });

  Future<Project?> getProjectById(String id);

  Future<Project> insertProject({
    String? id,
    required String responsibilityId,
    required String title,
    String? description,
    ProjectStatus status = ProjectStatus.planned,
    Priority priority = Priority.medium,
    DateTime? startDate,
    DateTime? dueDate,
    String? colorHex,
    String? iconKey,
    ProgressMode progressMode = ProgressMode.automatic,
    int? manualProgress,
  });

  Future<void> updateProject({
    required String id,
    String? responsibilityId,
    String? title,
    String? description,
    ProjectStatus? status,
    Priority? priority,
    DateTime? startDate,
    DateTime? dueDate,
    String? colorHex,
    String? iconKey,
    ProgressMode? progressMode,
    int? manualProgress,
    bool clearStartDate = false,
    bool clearDueDate = false,
    bool clearManualProgress = false,
  });

  /// بایگانی: وضعیت `archived` و `archivedAt` هم‌زمان (قید CHECK جدول).
  Future<void> archiveProject(String id);

  Future<void> restoreProject(String id);

  /// حذف ایمن: پروژه پاک می‌شود ولی وظایف و رویدادهای متصل باقی می‌مانند
  /// (FK با `ON DELETE SET NULL` فقط اتصال را قطع می‌کند).
  Future<void> deleteProject(String id);

  Future<ProjectProgress> progressFor(Project project);
}

Project _fromRow(ProjectRow row) {
  return Project(
    id: row.id,
    responsibilityId: row.responsibilityId,
    title: row.title,
    description: row.description,
    status: row.status,
    priority: row.priority,
    startDate: row.startDate,
    dueDate: row.dueDate,
    colorHex: row.colorHex,
    iconKey: row.iconKey,
    progressMode: row.progressMode,
    manualProgress: row.manualProgress,
    completedAtUtc: row.completedAtUtc?.toUtc(),
    createdAt: row.createdAt.toUtc(),
    updatedAt: row.updatedAt.toUtc(),
    archivedAt: row.archivedAt?.toUtc(),
  );
}

String _validateTitle(String title) {
  final String trimmed = title.trim();
  if (trimmed.isEmpty) {
    throw const ProjectValidationException('عنوان پروژه نمی‌تواند خالی باشد.');
  }
  if (trimmed.length > 120) {
    throw const ProjectValidationException(
      'عنوان پروژه نباید بیشتر از ۱۲۰ کاراکتر باشد.',
    );
  }
  return trimmed;
}

int _validateManualProgress(int progress) {
  if (progress < 0 || progress > 100) {
    throw const ProjectValidationException(
      'درصد پیشرفت باید بین ۰ و ۱۰۰ باشد.',
    );
  }
  return progress;
}

void _validateDates(String? start, String? due) {
  if (start == null || due == null) {
    return;
  }
  if (due.compareTo(start) < 0) {
    throw const ProjectValidationException(
      'تاریخ پایان پروژه نمی‌تواند قبل از شروع آن باشد.',
    );
  }
}

/// پیاده‌سازی [ProjectRepository] روی Drift.
class DriftProjectRepository implements ProjectRepository {
  DriftProjectRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<ProjectSummary>> getProjectSummaries({
    bool includeArchived = false,
  }) async {
    final query = _db.select(_db.projects);
    if (!includeArchived) {
      query.where((t) => t.archivedAt.isNull());
    }
    final List<ProjectRow> rows = await query.get();
    final List<Project> projects = rows.map(_fromRow).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final List<ProjectSummary> summaries = <ProjectSummary>[];
    for (final Project project in projects) {
      summaries.add(
        ProjectSummary(
          project: project,
          progress: await progressFor(project),
        ),
      );
    }
    return summaries;
  }

  @override
  Future<Project?> getProjectById(String id) async {
    final ProjectRow? row = await (_db.select(_db.projects)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  @override
  Future<ProjectProgress> progressFor(Project project) async {
    final List<TaskRow> tasks = await (_db.select(_db.tasks)
          ..where(
            (t) => t.projectId.equals(project.id) & t.archivedAt.isNull(),
          ))
        .get();

    // لغوشده‌ها در هیچ‌کدام از صورت و مخرج حساب نمی‌شوند.
    final List<TaskRow> counted = tasks
        .where((TaskRow task) => task.status != TaskStatus.cancelled)
        .toList();
    final int completed = counted
        .where((TaskRow task) => task.status == TaskStatus.completed)
        .length;

    if (project.progressMode == ProgressMode.manual) {
      return ProjectProgress(
        percent: project.manualProgress ?? 0,
        totalTasks: counted.length,
        completedTasks: completed,
      );
    }

    final int percent = counted.isEmpty
        ? 0
        : ((completed * 100) / counted.length).round();
    return ProjectProgress(
      percent: percent,
      totalTasks: counted.length,
      completedTasks: completed,
    );
  }

  @override
  Future<Project> insertProject({
    String? id,
    required String responsibilityId,
    required String title,
    String? description,
    ProjectStatus status = ProjectStatus.planned,
    Priority priority = Priority.medium,
    DateTime? startDate,
    DateTime? dueDate,
    String? colorHex,
    String? iconKey,
    ProgressMode progressMode = ProgressMode.automatic,
    int? manualProgress,
  }) async {
    final String projectId = id ?? _newId();
    final String? start = startDate == null ? null : formatDateOnly(startDate);
    final String? due = dueDate == null ? null : formatDateOnly(dueDate);
    _validateDates(start, due);

    // قید CHECK: حالت دستی ⇒ درصد لازم، حالت خودکار ⇒ درصد ممنوع.
    final int? progress = switch (progressMode) {
      ProgressMode.manual => _validateManualProgress(manualProgress ?? 0),
      ProgressMode.automatic => null,
    };

    final DateTime now = DateTime.now().toUtc();
    await _db.into(_db.projects).insert(
      ProjectsCompanion.insert(
        id: projectId,
        responsibilityId: responsibilityId,
        title: _validateTitle(title),
        description: Value<String?>(description),
        status: Value<ProjectStatus>(status),
        priority: Value<Priority>(priority),
        startDate: Value<String?>(start),
        dueDate: Value<String?>(due),
        colorHex: Value<String?>(colorHex),
        iconKey: Value<String?>(iconKey),
        progressMode: Value<ProgressMode>(progressMode),
        manualProgress: Value<int?>(progress),
        completedAtUtc: Value<DateTime?>(
          status == ProjectStatus.completed ? now : null,
        ),
        // قید CHECK: وضعیت archived بدون archivedAt مجاز نیست.
        archivedAt: Value<DateTime?>(
          status == ProjectStatus.archived ? now : null,
        ),
        createdAt: now,
        updatedAt: now,
      ),
    );

    final Project? inserted = await getProjectById(projectId);
    if (inserted == null) {
      throw ProjectNotFoundException(projectId);
    }
    return inserted;
  }

  @override
  Future<void> updateProject({
    required String id,
    String? responsibilityId,
    String? title,
    String? description,
    ProjectStatus? status,
    Priority? priority,
    DateTime? startDate,
    DateTime? dueDate,
    String? colorHex,
    String? iconKey,
    ProgressMode? progressMode,
    int? manualProgress,
    bool clearStartDate = false,
    bool clearDueDate = false,
    bool clearManualProgress = false,
  }) async {
    final Project? existing = await getProjectById(id);
    if (existing == null) {
      throw ProjectNotFoundException(id);
    }

    final DateTime now = DateTime.now().toUtc();
    final String? nextStart = clearStartDate
        ? null
        : (startDate == null ? existing.startDate : formatDateOnly(startDate));
    final String? nextDue = clearDueDate
        ? null
        : (dueDate == null ? existing.dueDate : formatDateOnly(dueDate));
    _validateDates(nextStart, nextDue);

    final ProgressMode nextMode = progressMode ?? existing.progressMode;
    final int? nextManual = switch (nextMode) {
      ProgressMode.manual => _validateManualProgress(
        clearManualProgress ? 0 : (manualProgress ?? existing.manualProgress ?? 0),
      ),
      ProgressMode.automatic => null,
    };

    final ProjectStatus nextStatus = status ?? existing.status;
    final DateTime? nextArchivedAt = switch (nextStatus) {
      ProjectStatus.archived => existing.archivedAt ?? now,
      _ => null,
    };

    await (_db.update(_db.projects)..where((t) => t.id.equals(id))).write(
      ProjectsCompanion(
        responsibilityId: responsibilityId != null
            ? Value<String>(responsibilityId)
            : const Value<String>.absent(),
        title: title != null
            ? Value<String>(_validateTitle(title))
            : const Value<String>.absent(),
        description: description != null
            ? Value<String?>(description)
            : const Value<String?>.absent(),
        status: status != null
            ? Value<ProjectStatus>(status)
            : const Value<ProjectStatus>.absent(),
        priority: priority != null
            ? Value<Priority>(priority)
            : const Value<Priority>.absent(),
        startDate: (clearStartDate || startDate != null)
            ? Value<String?>(nextStart)
            : const Value<String?>.absent(),
        dueDate: (clearDueDate || dueDate != null)
            ? Value<String?>(nextDue)
            : const Value<String?>.absent(),
        colorHex: colorHex != null
            ? Value<String?>(colorHex)
            : const Value<String?>.absent(),
        iconKey: iconKey != null
            ? Value<String?>(iconKey)
            : const Value<String?>.absent(),
        progressMode: progressMode != null
            ? Value<ProgressMode>(nextMode)
            : const Value<ProgressMode>.absent(),
        manualProgress: (progressMode != null ||
                manualProgress != null ||
                clearManualProgress)
            ? Value<int?>(nextManual)
            : const Value<int?>.absent(),
        completedAtUtc: status == null
            ? const Value<DateTime?>.absent()
            : switch (status) {
                ProjectStatus.completed =>
                  Value<DateTime?>(existing.completedAtUtc ?? now),
                _ => const Value<DateTime?>(null),
              },
        archivedAt: status != null || existing.archivedAt != null
            ? Value<DateTime?>(nextArchivedAt)
            : const Value<DateTime?>.absent(),
        updatedAt: Value<DateTime>(now),
      ),
    );
  }

  @override
  Future<void> archiveProject(String id) async {
    final Project? existing = await getProjectById(id);
    if (existing == null) {
      throw ProjectNotFoundException(id);
    }
    final DateTime now = DateTime.now().toUtc();
    await (_db.update(_db.projects)..where((t) => t.id.equals(id))).write(
      ProjectsCompanion(
        status: const Value<ProjectStatus>(ProjectStatus.archived),
        archivedAt: Value<DateTime?>(existing.archivedAt ?? now),
        updatedAt: Value<DateTime>(now),
      ),
    );
  }

  @override
  Future<void> restoreProject(String id) async {
    final Project? existing = await getProjectById(id);
    if (existing == null) {
      throw ProjectNotFoundException(id);
    }
    await (_db.update(_db.projects)..where((t) => t.id.equals(id))).write(
      ProjectsCompanion(
        status: const Value<ProjectStatus>(ProjectStatus.planned),
        archivedAt: const Value<DateTime?>(null),
        updatedAt: Value<DateTime>(DateTime.now().toUtc()),
      ),
    );
  }

  @override
  Future<void> deleteProject(String id) async {
    // FK ستون‌های project_id در tasks و events با ON DELETE SET NULL ساخته
    // شده‌اند، پس فعالیت‌ها حذف نمی‌شوند؛ فقط اتصالشان قطع می‌شود.
    await (_db.delete(_db.projects)..where((t) => t.id.equals(id))).go();
  }

  String _newId() =>
      'prj-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
}
