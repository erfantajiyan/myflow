import '../../../database/event_repository_impl.dart';
import '../../../database/project_repository_impl.dart';
import '../../../database/responsibility_repository_impl.dart';
import '../../../database/task_repository_impl.dart';
import '../../../shared/enums/app_enums.dart';

/// آمار یک مسئولیت در بازه‌ی گزارش — بخش ۷.۶ سند.
class ResponsibilityReport {
  const ResponsibilityReport({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.eventCount,
    required this.plannedMinutes,
  });

  final String id;
  final String name;
  final int colorValue;
  final int eventCount;
  final int plannedMinutes;

  double get plannedHours => plannedMinutes / 60;
}

/// تعداد وظایف تکمیل‌شده در یک هفته (شنبه‌محور).
class WeeklyCompletion {
  const WeeklyCompletion({required this.weekStart, required this.completed});

  final DateTime weekStart;
  final int completed;
}

/// پیشرفت یک پروژه در گزارش.
class ProjectReport {
  const ProjectReport({
    required this.title,
    required this.percent,
    required this.completedTasks,
    required this.totalTasks,
    required this.isActive,
  });

  final String title;
  final int percent;
  final int completedTasks;
  final int totalTasks;
  final bool isActive;
}

/// داده‌ی کامل صفحه‌ی گزارش برای یک بازه.
class ReportData {
  const ReportData({
    required this.rangeStart,
    required this.rangeEnd,
    required this.eventCount,
    required this.plannedMinutes,
    required this.responsibilities,
    required this.tasksCompleted,
    required this.tasksOverdue,
    required this.tasksOpen,
    required this.weeklyCompletions,
    required this.activeProjects,
    required this.projects,
  });

  final DateTime rangeStart;
  final DateTime rangeEnd;
  final int eventCount;

  /// مجموع مدت رویدادهای ساعت‌دار؛ رویداد تمام‌روز در این عدد نمی‌آید
  /// چون زمان برنامه‌ریزی‌شده‌ی واقعی نیست (بخش ۷.۶ سند).
  final int plannedMinutes;

  final List<ResponsibilityReport> responsibilities;
  final int tasksCompleted;
  final int tasksOverdue;
  final int tasksOpen;
  final List<WeeklyCompletion> weeklyCompletions;
  final int activeProjects;
  final List<ProjectReport> projects;

  bool get isEmpty =>
      eventCount == 0 &&
      tasksCompleted == 0 &&
      tasksOpen == 0 &&
      projects.isEmpty;
}

/// ساخت گزارش از داده‌ی خام؛ تابع خالص تا اعداد با دیتابیس قابل تطبیق و
/// قابل تست باشند (معیار اتمام فاز ۱۲).
///
/// قواعد:
/// - رویدادهای لغوشده شمرده نمی‌شوند.
/// - مدت رویدادهای تمام‌روز در «زمان برنامه‌ریزی‌شده» نمی‌آید.
/// - وظیفه‌ی تکمیل‌شده بر اساس `completedAtUtc` داخل بازه شمرده می‌شود.
/// - وظیفه‌ی عقب‌افتاده: سررسید قبل از امروز، انجام‌نشده، لغوشده یا
///   بایگانی‌نشده.
ReportData aggregateReport({
  required List<Event> events,
  required List<Task> tasks,
  required List<ProjectSummary> projects,
  required List<Responsibility> responsibilities,
  required DateTime rangeStart,
  required DateTime rangeEnd,
  required DateTime today,
  int weeks = 6,
}) {
  final DateTime startDay = DateTime(
    rangeStart.year,
    rangeStart.month,
    rangeStart.day,
  );
  final DateTime endDay = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day);
  final DateTime todayDay = DateTime(today.year, today.month, today.day);

  final Map<String, Responsibility> byId = <String, Responsibility>{
    for (final Responsibility responsibility in responsibilities)
      responsibility.id: responsibility,
  };

  final Map<String, _ResponsibilityAccumulator> perResponsibility =
      <String, _ResponsibilityAccumulator>{};
  int eventCount = 0;
  int plannedMinutes = 0;

  for (final Event event in events) {
    if (event.isCancelled) {
      continue;
    }
    final DateTime start = event.startLocal;
    if (start.isBefore(startDay) || !start.isBefore(endDay)) {
      continue;
    }
    eventCount++;
    if (!event.allDay) {
      plannedMinutes += event.duration.inMinutes;
    }
    final _ResponsibilityAccumulator accumulator = perResponsibility
        .putIfAbsent(
          event.responsibilityId,
          () => _ResponsibilityAccumulator(),
        );
    accumulator.eventCount++;
    if (!event.allDay) {
      accumulator.minutes += event.duration.inMinutes;
    }
  }

  final List<ResponsibilityReport> responsibilityReports =
      perResponsibility.entries
          .map((MapEntry<String, _ResponsibilityAccumulator> entry) {
            final Responsibility? responsibility = byId[entry.key];
            return ResponsibilityReport(
              id: entry.key,
              name: responsibility?.name ?? 'بدون مسئولیت',
              colorValue: responsibility?.color.toARGB32() ?? 0xFF9E9E9E,
              eventCount: entry.value.eventCount,
              plannedMinutes: entry.value.minutes,
            );
          })
          .toList()
        ..sort(
          (ResponsibilityReport a, ResponsibilityReport b) =>
              b.plannedMinutes.compareTo(a.plannedMinutes),
        );

  int completed = 0;
  int overdue = 0;
  int open = 0;
  final List<DateTime> completionDays = <DateTime>[];

  for (final Task task in tasks) {
    if (task.isArchived || task.isCancelled) {
      continue;
    }
    if (!task.isCompleted) {
      open++;
    }
    if (task.isOverdue(todayDay)) {
      overdue++;
    }
    final DateTime? completedAt = task.completedAtUtc?.toLocal();
    if (completedAt != null &&
        !completedAt.isBefore(startDay) &&
        completedAt.isBefore(endDay)) {
      completed++;
      completionDays.add(
        DateTime(completedAt.year, completedAt.month, completedAt.day),
      );
    }
  }

  // هفته‌های شنبه‌محور؛ هفته‌ی جاری آخرین ستون است.
  final DateTime currentWeekStart = _startOfWeek(todayDay);
  final List<WeeklyCompletion> weekly = <WeeklyCompletion>[
    for (int i = weeks - 1; i >= 0; i--)
      WeeklyCompletion(
        weekStart: currentWeekStart.subtract(Duration(days: 7 * i)),
        completed: 0,
      ),
  ];
  for (final DateTime day in completionDays) {
    for (int i = 0; i < weekly.length; i++) {
      final DateTime weekStart = weekly[i].weekStart;
      final DateTime weekEnd = weekStart.add(const Duration(days: 7));
      if (!day.isBefore(weekStart) && day.isBefore(weekEnd)) {
        weekly[i] = WeeklyCompletion(
          weekStart: weekStart,
          completed: weekly[i].completed + 1,
        );
        break;
      }
    }
  }

  final List<ProjectSummary> visibleProjects = projects
      .where((ProjectSummary summary) => summary.project.archivedAt == null)
      .toList();
  final List<ProjectReport> projectReports = visibleProjects
      .map(
        (ProjectSummary summary) => ProjectReport(
          title: summary.project.title,
          percent: summary.progress.percent,
          completedTasks: summary.progress.completedTasks,
          totalTasks: summary.progress.totalTasks,
          isActive: summary.project.status == ProjectStatus.active,
        ),
      )
      .toList()
    ..sort((ProjectReport a, ProjectReport b) => b.percent.compareTo(a.percent));

  return ReportData(
    rangeStart: startDay,
    rangeEnd: endDay,
    eventCount: eventCount,
    plannedMinutes: plannedMinutes,
    responsibilities: responsibilityReports,
    tasksCompleted: completed,
    tasksOverdue: overdue,
    tasksOpen: open,
    weeklyCompletions: weekly,
    activeProjects: visibleProjects
        .where(
          (ProjectSummary summary) =>
              summary.project.status == ProjectStatus.active,
        )
        .length,
    projects: projectReports,
  );
}

DateTime _startOfWeek(DateTime day) {
  // شنبه = ۰ در تقویم فارسی؛ DateTime.weekday دوشنبه = ۱.
  final int daysFromSaturday = (day.weekday + 1) % 7;
  return DateTime(
    day.year,
    day.month,
    day.day,
  ).subtract(Duration(days: daysFromSaturday));
}

class _ResponsibilityAccumulator {
  int eventCount = 0;
  int minutes = 0;
}
