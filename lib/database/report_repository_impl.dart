import '../features/reports/domain/report_data.dart';
import 'event_repository_impl.dart';
import 'project_repository_impl.dart';
import 'responsibility_repository_impl.dart';
import 'task_repository_impl.dart';

/// ساخت گزارش پایه — بخش ۷.۶ سند.
///
/// گزارش از همان repositoryهای صفحه‌های دیگر می‌خواند تا نمونه‌های تکراری
/// (که ردیف ذخیره‌شده ندارند) هم در شمارش و زمان برنامه‌ریزی‌شده بیایند و
/// اعداد گزارش با چیزی که کاربر در تقویم می‌بیند یکی باشد.
abstract class ReportRepository {
  Future<ReportData> buildReport({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required DateTime today,
    int weeks = 6,
  });
}

class DriftReportRepository implements ReportRepository {
  DriftReportRepository({
    required this.eventRepository,
    required this.taskRepository,
    required this.projectRepository,
    required this.responsibilityRepository,
  });

  final EventRepository eventRepository;
  final TaskRepository taskRepository;
  final ProjectRepository projectRepository;
  final ResponsibilityRepository responsibilityRepository;

  @override
  Future<ReportData> buildReport({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required DateTime today,
    int weeks = 6,
  }) async {
    final List<Event> events = await eventRepository.getEventsInRange(
      fromDay: rangeStart,
      toDay: rangeEnd,
    );
    final List<Task> tasks = await taskRepository.getTasks();
    final List<ProjectSummary> projects = await projectRepository
        .getProjectSummaries();
    final List<Responsibility> responsibilities = await responsibilityRepository
        .getAllResponsibilities();

    return aggregateReport(
      events: events,
      tasks: tasks,
      projects: projects,
      responsibilities: responsibilities,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      today: today,
      weeks: weeks,
    );
  }
}
