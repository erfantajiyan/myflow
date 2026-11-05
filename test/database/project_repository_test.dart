import 'package:drift/native.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myflow/database/app_database.dart';
import 'package:myflow/database/event_repository_impl.dart';
import 'package:myflow/database/project_repository_impl.dart';
import 'package:myflow/database/responsibility_repository_impl.dart';
import 'package:myflow/database/task_repository_impl.dart';
import 'package:myflow/shared/enums/app_enums.dart';

void main() {
  late AppDatabase db;
  late DriftProjectRepository projects;
  late DriftTaskRepository tasks;
  late DriftEventRepository events;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final DriftResponsibilityRepository responsibilities =
        DriftResponsibilityRepository(db);
    await responsibilities.insertResponsibility(
      id: 'resp-1',
      name: 'دانشجو',
      color: const Color(0xFF3B82F6),
    );
    projects = DriftProjectRepository(db);
    tasks = DriftTaskRepository(db);
    events = DriftEventRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<Project> createProject({
    String title = 'همایش',
    ProgressMode mode = ProgressMode.automatic,
    int? manualProgress,
    DateTime? start,
    DateTime? due,
  }) {
    return projects.insertProject(
      responsibilityId: 'resp-1',
      title: title,
      progressMode: mode,
      manualProgress: manualProgress,
      startDate: start,
      dueDate: due,
    );
  }

  group('ساخت و اعتبارسنجی', () {
    test('پروژه با پیشرفت خودکار ساخته و خوانده می‌شود', () async {
      final Project created = await createProject();

      expect(created.title, 'همایش');
      expect(created.status, ProjectStatus.planned);
      expect(created.progressMode, ProgressMode.automatic);
      expect(created.manualProgress, isNull);
      expect(created.archivedAt, isNull);

      final Project? loaded = await projects.getProjectById(created.id);
      expect(loaded?.title, 'همایش');
    });

    test('عنوان خالی رد می‌شود', () {
      expect(
        () => projects.insertProject(
          responsibilityId: 'resp-1',
          title: '  ',
        ),
        throwsA(isA<ProjectValidationException>()),
      );
    });

    test('پایان قبل از شروع رد می‌شود', () {
      expect(
        () => createProject(
          start: DateTime(2026, 11, 10),
          due: DateTime(2026, 11, 1),
        ),
        throwsA(isA<ProjectValidationException>()),
      );
    });

    test('حالت دستی بدون درصد، صفر می‌گیرد', () async {
      final Project project = await createProject(
        mode: ProgressMode.manual,
      );
      expect(project.manualProgress, 0);

      await expectLater(
        projects.insertProject(
          responsibilityId: 'resp-1',
          title: 'دستی',
          progressMode: ProgressMode.manual,
          manualProgress: 140,
        ),
        throwsA(isA<ProjectValidationException>()),
      );
    });

    test('حالت خودکار درصد دستی را ذخیره نمی‌کند', () async {
      final Project project = await projects.insertProject(
        responsibilityId: 'resp-1',
        title: 'خودکار',
        progressMode: ProgressMode.automatic,
        manualProgress: 80,
      );
      expect(project.manualProgress, isNull);
    });
  });

  group('محاسبه‌ی پیشرفت', () {
    test('پروژه‌ی بدون وظیفه صفر درصد است', () async {
      final Project project = await createProject();
      final ProjectProgress progress = await projects.progressFor(project);

      expect(progress.percent, 0);
      expect(progress.totalTasks, 0);
      expect(progress.hasTasks, isFalse);
    });

    test('وظیفه‌ی لغوشده از صورت و مخرج حذف می‌شود', () async {
      final Project project = await createProject();

      await tasks.insertTask(
        responsibilityId: 'resp-1',
        title: 'یک',
        projectId: project.id,
        status: TaskStatus.completed,
      );
      await tasks.insertTask(
        responsibilityId: 'resp-1',
        title: 'دو',
        projectId: project.id,
      );
      await tasks.insertTask(
        responsibilityId: 'resp-1',
        title: 'سه',
        projectId: project.id,
        status: TaskStatus.cancelled,
      );

      final ProjectProgress progress = await projects.progressFor(project);
      expect(progress.totalTasks, 2);
      expect(progress.completedTasks, 1);
      expect(progress.percent, 50);
    });

    test('وظیفه‌ی بایگانی‌شده در پیشرفت حساب نمی‌شود', () async {
      final Project project = await createProject();

      await tasks.insertTask(
        responsibilityId: 'resp-1',
        title: 'یک',
        projectId: project.id,
        status: TaskStatus.completed,
      );
      final Task archived = await tasks.insertTask(
        responsibilityId: 'resp-1',
        title: 'دو',
        projectId: project.id,
      );
      await tasks.archiveTask(archived.id);

      final ProjectProgress progress = await projects.progressFor(project);
      expect(progress.totalTasks, 1);
      expect(progress.percent, 100);
    });

    test('همه‌ی وظیفه‌ها تکمیل‌شده یعنی صد درصد', () async {
      final Project project = await createProject();
      for (final String title in <String>['یک', 'دو', 'سه']) {
        await tasks.insertTask(
          responsibilityId: 'resp-1',
          title: title,
          projectId: project.id,
          status: TaskStatus.completed,
        );
      }

      final ProjectProgress progress = await projects.progressFor(project);
      expect(progress.percent, 100);
      expect(progress.completedTasks, 3);
    });

    test('پیشرفت دستی مقدار ذخیره‌شده را برمی‌گرداند', () async {
      final Project project = await createProject(
        mode: ProgressMode.manual,
        manualProgress: 40,
      );
      await tasks.insertTask(
        responsibilityId: 'resp-1',
        title: 'یک',
        projectId: project.id,
      );

      final ProjectProgress progress = await projects.progressFor(project);
      expect(progress.percent, 40);
      expect(progress.totalTasks, 1);
      expect(progress.completedTasks, 0);
    });

    test('تکمیل وظیفه پیشرفت را در فهرست خلاصه بالا می‌برد', () async {
      final Project project = await createProject();
      final Task task = await tasks.insertTask(
        responsibilityId: 'resp-1',
        title: 'یک',
        projectId: project.id,
      );

      List<ProjectSummary> summaries = await projects.getProjectSummaries();
      expect(summaries.single.progress.percent, 0);

      await tasks.completeTask(task.id);
      summaries = await projects.getProjectSummaries();
      expect(summaries.single.progress.percent, 100);
    });
  });

  group('بایگانی و حذف ایمن', () {
    test('بایگانی وضعیت و مهر زمان را با هم می‌نویسد', () async {
      final Project project = await createProject();
      await projects.archiveProject(project.id);

      expect(await projects.getProjectSummaries(), isEmpty);
      final List<ProjectSummary> withArchived =
          await projects.getProjectSummaries(includeArchived: true);
      expect(withArchived.single.project.status, ProjectStatus.archived);
      expect(withArchived.single.project.archivedAt, isNotNull);
    });

    test('بازگردانی پروژه آن را به حالت برنامه‌ریزی‌شده برمی‌گرداند', () async {
      final Project project = await createProject();
      await projects.archiveProject(project.id);
      await projects.restoreProject(project.id);

      final Project? restored = await projects.getProjectById(project.id);
      expect(restored?.status, ProjectStatus.planned);
      expect(restored?.archivedAt, isNull);
      expect(await projects.getProjectSummaries(), hasLength(1));
    });

    test('حذف پروژه وظیفه را نگه می‌دارد و فقط اتصال را قطع می‌کند', () async {
      final Project project = await createProject();
      final Task task = await tasks.insertTask(
        responsibilityId: 'resp-1',
        title: 'کار پروژه',
        projectId: project.id,
      );

      await projects.deleteProject(project.id);

      expect(await projects.getProjectById(project.id), isNull);
      final Task? kept = await tasks.getTaskById(task.id);
      expect(kept, isNotNull);
      expect(kept?.projectId, isNull);
    });

    test('حذف پروژه رویداد متصل را هم حفظ می‌کند', () async {
      final Project project = await createProject();
      final Event event = await events.insertEvent(
        responsibilityId: 'resp-1',
        projectId: project.id,
        title: 'جلسه‌ی پروژه',
        startAt: DateTime(2026, 11, 5, 10),
        endAt: DateTime(2026, 11, 5, 11),
      );

      await projects.deleteProject(project.id);

      final Event? kept = await events.getEventById(event.id);
      expect(kept, isNotNull);
      expect(kept?.projectId, isNull);
    });
  });
}
