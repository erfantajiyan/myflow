import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myflow/database/event_repository_impl.dart';
import 'package:myflow/database/project_repository_impl.dart';
import 'package:myflow/database/responsibility_repository_impl.dart';
import 'package:myflow/database/task_repository_impl.dart';
import 'package:myflow/features/reports/domain/report_data.dart';
import 'package:myflow/shared/enums/app_enums.dart';

void main() {
  final DateTime monthStart = DateTime(2026, 3, 21);
  final DateTime monthEnd = DateTime(2026, 4, 21);
  final DateTime today = DateTime(2026, 4, 10, 12);

  Event event({
    required String id,
    required String title,
    required DateTime start,
    required int minutes,
    bool allDay = false,
    EventStatus status = EventStatus.planned,
    String responsibilityId = 'resp-study',
  }) {
    return Event(
      id: id,
      responsibilityId: responsibilityId,
      title: title,
      startAtUtc: start.toUtc(),
      endAtUtc: start.add(Duration(minutes: minutes)).toUtc(),
      timezoneId: 'Asia/Tehran',
      allDay: allDay,
      status: status,
      createdAt: DateTime(2026, 3, 1),
      updatedAt: DateTime(2026, 3, 1),
    );
  }

  Task task({
    required String id,
    required String title,
    DateTime? dueDate,
    TaskStatus status = TaskStatus.todo,
    DateTime? completedAt,
  }) {
    return Task(
      id: id,
      responsibilityId: 'resp-study',
      title: title,
      priority: Priority.medium,
      status: status,
      sortOrder: 0,
      createdAt: DateTime(2026, 3, 1),
      updatedAt: DateTime(2026, 3, 1),
      dueDate: dueDate == null
          ? null
          : '${dueDate.year.toString().padLeft(4, '0')}-'
                '${dueDate.month.toString().padLeft(2, '0')}-'
                '${dueDate.day.toString().padLeft(2, '0')}',
      completedAtUtc: completedAt?.toUtc(),
    );
  }

  Responsibility responsibility(String id, String name) {
    return Responsibility(
      id: id,
      name: name,
      color: const Color(0xFF5BA8FF),
      isActive: true,
      sortOrder: 0,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  test('رویدادها، مدت و لغوشده‌ها درست شمرده می‌شوند', () {
    final ReportData report = aggregateReport(
      events: <Event>[
        event(
          id: 'e1',
          title: 'کلاس',
          start: DateTime(2026, 3, 22, 10),
          minutes: 90,
        ),
        event(
          id: 'e2',
          title: 'کلاس دوم',
          start: DateTime(2026, 3, 23, 8),
          minutes: 30,
        ),
        event(
          id: 'e3',
          title: 'لغوشده',
          start: DateTime(2026, 3, 24, 8),
          minutes: 60,
          status: EventStatus.cancelled,
        ),
        event(
          id: 'e4',
          title: 'تعطیل',
          start: DateTime(2026, 3, 25),
          minutes: 24 * 60,
          allDay: true,
        ),
        event(
          id: 'e5',
          title: 'ماه قبل',
          start: DateTime(2026, 2, 20, 8),
          minutes: 60,
        ),
      ],
      tasks: const <Task>[],
      projects: const <ProjectSummary>[],
      responsibilities: <Responsibility>[responsibility('resp-study', 'تحصیل')],
      rangeStart: monthStart,
      rangeEnd: monthEnd,
      today: today,
    );

    expect(report.eventCount, 3, reason: 'لغوشده و خارج بازه شمرده نمی‌شوند');
    expect(report.plannedMinutes, 120, reason: 'تمام‌روز در مدت نمی‌آید');
    expect(report.responsibilities, hasLength(1));
    expect(report.responsibilities.single.name, 'تحصیل');
    expect(report.responsibilities.single.eventCount, 3);
    expect(report.responsibilities.single.plannedMinutes, 120);
  });

  test('وظایف تکمیل‌شده، عقب‌افتاده و باز تفکیک می‌شوند', () {
    final ReportData report = aggregateReport(
      events: const <Event>[],
      tasks: <Task>[
        task(
          id: 't1',
          title: 'انجام‌شده این ماه',
          status: TaskStatus.completed,
          completedAt: DateTime(2026, 4, 2, 15),
        ),
        task(
          id: 't2',
          title: 'انجام‌شده ماه قبل',
          status: TaskStatus.completed,
          completedAt: DateTime(2026, 3, 1, 9),
        ),
        task(id: 't3', title: 'عقب‌افتاده', dueDate: DateTime(2026, 4, 8)),
        task(id: 't4', title: 'باز بدون سررسید'),
      ],
      projects: const <ProjectSummary>[],
      responsibilities: const <Responsibility>[],
      rangeStart: monthStart,
      rangeEnd: monthEnd,
      today: today,
    );

    expect(report.tasksCompleted, 1);
    expect(report.tasksOverdue, 1);
    expect(report.tasksOpen, 2, reason: 'وظیفه‌ی انجام‌شده باز حساب نمی‌شود');
  });

  test('روند تکمیل هفتگی از هفته‌ی جاری به عقب ساخته می‌شود', () {
    final ReportData report = aggregateReport(
      events: const <Event>[],
      tasks: <Task>[
        task(
          id: 't1',
          title: 'این هفته',
          status: TaskStatus.completed,
          completedAt: today,
        ),
        task(
          id: 't2',
          title: 'هفته قبل',
          status: TaskStatus.completed,
          completedAt: today.subtract(const Duration(days: 7)),
        ),
      ],
      projects: const <ProjectSummary>[],
      responsibilities: const <Responsibility>[],
      rangeStart: monthStart,
      rangeEnd: monthEnd,
      today: today,
      weeks: 3,
    );

    expect(report.weeklyCompletions, hasLength(3));
    expect(report.weeklyCompletions.last.completed, 1);
    expect(report.weeklyCompletions[1].completed, 1);
    expect(report.weeklyCompletions.first.completed, 0);
  });

  test('پروژه‌ها با پیشرفت و شمارش فعال‌ها می‌آیند', () {
    final ReportData report = aggregateReport(
      events: <Event>[
        event(
          id: 'e1',
          title: 'کار پروژه',
          start: DateTime(2026, 3, 22, 10),
          minutes: 60,
        ),
      ],
      tasks: const <Task>[],
      projects: <ProjectSummary>[
        ProjectSummary(
          project: Project(
            id: 'p1',
            responsibilityId: 'resp-study',
            title: 'پایان‌نامه',
            status: ProjectStatus.active,
            priority: Priority.high,
            progressMode: ProgressMode.automatic,
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
          ),
          progress: const ProjectProgress(
            percent: 40,
            totalTasks: 5,
            completedTasks: 2,
          ),
        ),
        ProjectSummary(
          project: Project(
            id: 'p2',
            responsibilityId: 'resp-study',
            title: 'بایگانی‌شده',
            status: ProjectStatus.active,
            priority: Priority.low,
            progressMode: ProgressMode.automatic,
            createdAt: DateTime(2026, 1, 1),
            updatedAt: DateTime(2026, 1, 1),
            archivedAt: DateTime(2026, 2, 1),
          ),
          progress: const ProjectProgress(
            percent: 10,
            totalTasks: 2,
            completedTasks: 0,
          ),
        ),
      ],
      responsibilities: const <Responsibility>[],
      rangeStart: monthStart,
      rangeEnd: monthEnd,
      today: today,
    );

    expect(report.activeProjects, 1);
    expect(report.projects, hasLength(1));
    expect(report.projects.single.title, 'پایان‌نامه');
    expect(report.projects.single.percent, 40);
  });
}
