import 'package:drift/native.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myflow/database/app_database.dart';
import 'package:myflow/database/database_providers.dart';
import 'package:myflow/database/event_repository_impl.dart';
import 'package:myflow/database/responsibility_repository_impl.dart';
import 'package:myflow/database/task_repository_impl.dart';
import 'package:myflow/features/tasks/data/tasks_controller.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final DriftResponsibilityRepository responsibilities =
        DriftResponsibilityRepository(db);
    await responsibilities.insertResponsibility(
      id: 'resp-1',
      name: 'دانشجو',
      color: const Color(0xFF3B82F6),
    );
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWith((Ref ref) => db),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(() async {
    await db.close();
  });

  test('وظیفه به رویداد همان روز ساعت ۹ تا ۱۰ تبدیل می‌شود', () async {
    await container.read(tasksControllerProvider.future);
    final TasksController controller = container.read(
      tasksControllerProvider.notifier,
    );

    final Task task = await controller.create(
      responsibilityId: 'resp-1',
      title: 'جلسه با استاد',
      dueDate: DateTime(2026, 11, 5),
    );

    final Event event = await controller.convertToEvent(task);

    expect(event.title, 'جلسه با استاد');
    expect(event.startLocal, DateTime(2026, 11, 5, 9));
    expect(event.endLocal, DateTime(2026, 11, 5, 10));

    // پیوند به وظیفه در دیتابیس ثبت شده است.
    final EventRow row = (await db.select(db.events).get()).single;
    expect(row.sourceTaskId, task.id);
    expect(row.projectId, isNull);

    // خود وظیفه دست‌نخورده می‌ماند.
    final Task? kept = await container
        .read(taskRepositoryProvider)
        .getTaskById(task.id);
    expect(kept?.isCompleted, isFalse);
  });

  test('وظیفه‌ی بدون سررسید برای امروز تبدیل می‌شود', () async {
    await container.read(tasksControllerProvider.future);
    final TasksController controller = container.read(
      tasksControllerProvider.notifier,
    );

    final Task task = await controller.create(
      responsibilityId: 'resp-1',
      title: 'کار بی‌تاریخ',
    );
    final Event event = await controller.convertToEvent(task);

    final DateTime now = DateTime.now();
    expect(event.startLocal.day, now.day);
    expect(event.startLocal.hour, 9);
  });
}
