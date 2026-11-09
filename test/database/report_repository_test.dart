import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myflow/database/app_database.dart';
import 'package:myflow/database/event_repository_impl.dart';
import 'package:myflow/database/project_repository_impl.dart';
import 'package:myflow/database/report_repository_impl.dart';
import 'package:myflow/database/responsibility_repository_impl.dart';
import 'package:myflow/database/task_repository_impl.dart';
import 'package:myflow/features/reports/domain/report_data.dart';
import 'package:myflow/shared/enums/app_enums.dart';

void main() {
  const String respId = 'resp-report';

  late AppDatabase db;
  late DriftEventRepository events;
  late DriftTaskRepository tasks;
  late DriftProjectRepository projects;
  late DriftReportRepository reports;

  final DateTime rangeStart = DateTime(2026, 3, 21);
  final DateTime rangeEnd = DateTime(2026, 4, 21);
  final DateTime today = DateTime(2026, 4, 10, 9);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    events = DriftEventRepository(db);
    tasks = DriftTaskRepository(db);
    projects = DriftProjectRepository(db);
    final DriftResponsibilityRepository responsibilities =
        DriftResponsibilityRepository(db);
    await responsibilities.insertResponsibility(
      id: respId,
      name: 'تحصیل',
      color: const Color(0xFF5BA8FF),
    );
    reports = DriftReportRepository(
      eventRepository: events,
      taskRepository: tasks,
      projectRepository: projects,
      responsibilityRepository: responsibilities,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('تعداد و زمان رویدادها با خواندن مستقیم تقویم یکی است', () async {
    await events.insertEvent(
      responsibilityId: respId,
      title: 'کلاس یک',
      startAt: DateTime(2026, 3, 22, 10),
      endAt: DateTime(2026, 3, 22, 11, 30),
    );
    await events.insertEvent(
      responsibilityId: respId,
      title: 'کلاس دو',
      startAt: DateTime(2026, 4, 2, 8),
      endAt: DateTime(2026, 4, 2, 9),
    );
    await events.createRecurringEvent(
      responsibilityId: respId,
      title: 'جلسه هفتگی',
      startAt: DateTime(2026, 3, 28, 16),
      endAt: DateTime(2026, 3, 28, 17),
      frequency: RecurrenceFrequency.weekly,
    );
    // خارج از بازه
    await events.insertEvent(
      responsibilityId: respId,
      title: 'ماه بعد',
      startAt: DateTime(2026, 5, 2, 10),
      endAt: DateTime(2026, 5, 2, 11),
    );

    final ReportData report = await reports.buildReport(
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      today: today,
    );
    final List<Event> direct = await events.getEventsInRange(
      fromDay: rangeStart,
      toDay: rangeEnd,
    );

    expect(report.eventCount, direct.length);
    expect(report.eventCount, 6, reason: '۲ رویداد + ۴ نمونه‌ی هفتگی');
    expect(
      report.plannedMinutes,
      direct.fold<int>(0, (int sum, Event event) => sum + event.duration.inMinutes),
    );
    expect(report.responsibilities.single.eventCount, report.eventCount);
    expect(report.responsibilities.single.plannedMinutes, report.plannedMinutes);
  });

  test('شمارش وظایف با وضعیت واقعی دیتابیس تطبیق دارد', () async {
    final Task done = await tasks.insertTask(
      responsibilityId: respId,
      title: 'انجام‌شده',
      dueDate: DateTime(2026, 4, 5),
    );
    await tasks.completeTask(done.id);
    await tasks.insertTask(
      responsibilityId: respId,
      title: 'عقب‌افتاده',
      dueDate: DateTime(2026, 4, 1),
    );
    final Task archived = await tasks.insertTask(
      responsibilityId: respId,
      title: 'بایگانی',
      dueDate: DateTime(2026, 4, 2),
    );
    await tasks.archiveTask(archived.id);

    final ReportData report = await reports.buildReport(
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      today: today,
    );
    final List<Task> all = await tasks.getTasks();

    // تکمیل با زمان واقعی سیستم ثبت می‌شود و در بازه‌ی فروردین ۱۴۰۵ نیست.
    expect(report.tasksCompleted, 0);
    expect(all.where((Task t) => t.isCompleted), hasLength(1));
    expect(
      report.tasksOverdue,
      all.where((Task t) => t.isOverdue(today)).length,
    );
    expect(report.tasksOpen, 1);

    // در بازه‌ی ماه جاری، تکمیل همین وظیفه شمرده می‌شود.
    final DateTime now = DateTime.now();
    final DateTime currentMonthStart = DateTime(now.year, now.month, 1);
    final ReportData current = await reports.buildReport(
      rangeStart: currentMonthStart,
      rangeEnd: DateTime(now.year, now.month + 1, 1),
      today: today,
    );
    expect(current.tasksCompleted, 1);
  });

  test('پیشرفت پروژه‌ها در گزارش می‌آید', () async {
    final Project project = await projects.insertProject(
      responsibilityId: respId,
      title: 'پایان‌نامه',
      status: ProjectStatus.active,
    );
    final Task task = await tasks.insertTask(
      responsibilityId: respId,
      title: 'فصل اول',
      projectId: project.id,
    );
    await tasks.insertTask(
      responsibilityId: respId,
      title: 'فصل دوم',
      projectId: project.id,
    );
    await tasks.completeTask(task.id);

    final ReportData report = await reports.buildReport(
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      today: today,
    );

    expect(report.activeProjects, 1);
    expect(report.projects.single.percent, 50);
    expect(report.projects.single.completedTasks, 1);
    expect(report.projects.single.totalTasks, 2);
  });
}
