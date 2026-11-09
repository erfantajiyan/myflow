import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/data_revision_provider.dart';
import '../../../database/database_providers.dart';
import '../../../database/event_repository_impl.dart';
import '../../../database/task_repository_impl.dart';
import '../../../shared/enums/app_enums.dart';
import '../../events/data/events_controller.dart';
import '../../projects/data/projects_controller.dart';

final Provider<TaskRepository> taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => DriftTaskRepository(ref.watch(appDatabaseProvider)),
);

/// فیلتر فعال فهرست وظایف.
final NotifierProvider<TaskFilterController, TaskFilter> taskFilterProvider =
    NotifierProvider<TaskFilterController, TaskFilter>(
      TaskFilterController.new,
    );

class TaskFilterController extends Notifier<TaskFilter> {
  @override
  TaskFilter build() => TaskFilter.all;

  void select(TaskFilter filter) {
    state = filter;
  }
}

final AsyncNotifierProvider<TasksController, List<Task>>
tasksControllerProvider = AsyncNotifierProvider<TasksController, List<Task>>(
  TasksController.new,
);

class TasksController extends AsyncNotifier<List<Task>> {
  @override
  Future<List<Task>> build() {
    final TaskFilter filter = ref.watch(taskFilterProvider);
    return ref
        .read(taskRepositoryProvider)
        .getTasks(filter: filter, today: DateTime.now());
  }

  Future<void> refresh() async {
    // هر بازخوانی یعنی داده تغییر کرده؛ صفحه‌های دیگر هم باید تازه شوند.
    ref.read(dataRevisionProvider.notifier).bump();
    state = const AsyncValue<List<Task>>.loading();
    state = await AsyncValue.guard(
      () => ref
          .read(taskRepositoryProvider)
          .getTasks(filter: ref.read(taskFilterProvider), today: DateTime.now()),
    );
  }

  Future<Task> create({
    required String responsibilityId,
    required String title,
    String? projectId,
    String? description,
    Priority priority = Priority.medium,
    DateTime? dueDate,
    String? dueTime,
    int? estimatedMinutes,
  }) async {
    final Task created = await ref
        .read(taskRepositoryProvider)
        .insertTask(
          responsibilityId: responsibilityId,
          title: title,
          projectId: projectId,
          description: description,
          priority: priority,
          dueDate: dueDate,
          dueTime: dueTime,
          estimatedMinutes: estimatedMinutes,
        );
    await refresh();
    return created;
  }

  Future<void> edit({
    required String id,
    String? responsibilityId,
    String? title,
    String? description,
    Priority? priority,
    DateTime? dueDate,
    String? dueTime,
    int? estimatedMinutes,
    String? projectId,
    bool clearProjectId = false,
    bool clearDueDate = false,
    bool clearDueTime = false,
  }) async {
    await ref
        .read(taskRepositoryProvider)
        .updateTask(
          id: id,
          responsibilityId: responsibilityId,
          title: title,
          description: description,
          priority: priority,
          dueDate: dueDate,
          dueTime: dueTime,
          estimatedMinutes: estimatedMinutes,
          projectId: projectId,
          clearProjectId: clearProjectId,
          clearDueDate: clearDueDate,
          clearDueTime: clearDueTime,
        );
    await _refreshWithProgress();
  }

  Future<void> complete(String id) async {
    await ref.read(taskRepositoryProvider).completeTask(id);
    await _refreshWithProgress();
  }

  Future<void> reopen(String id) async {
    await ref.read(taskRepositoryProvider).reopenTask(id);
    await _refreshWithProgress();
  }

  Future<void> archive(String id) async {
    await ref.read(taskRepositoryProvider).archiveTask(id);
    await _refreshWithProgress();
  }

  /// تبدیل وظیفه به رویداد: همان روز سررسید (یا امروز) ساعت ۰۹:۰۰ تا ۱۰:۰۰.
  ///
  /// رویداد با `sourceTaskId` به وظیفه وصل می‌شود تا رابطه بعداً قابل ردیابی
  /// باشد؛ خود وظیفه تغییر وضعیت نمی‌دهد.
  Future<Event> convertToEvent(Task task) async {
    final DateTime day = task.dueDateLocal ?? DateTime.now();
    final Event created = await ref
        .read(eventRepositoryProvider)
        .insertEvent(
          responsibilityId: task.responsibilityId,
          projectId: task.projectId,
          sourceTaskId: task.id,
          title: task.title,
          startAt: DateTime(day.year, day.month, day.day, 9),
          endAt: DateTime(day.year, day.month, day.day, 10),
          description: task.description,
        );
    ref.invalidate(dayEventsProvider);
    return created;
  }

  /// پیشرفت پروژه‌ها از روی وظایف محاسبه می‌شود، پس هر تغییر وظیفه آن را
  /// بی‌اعتبار می‌کند.
  Future<void> _refreshWithProgress() async {
    ref.invalidate(projectsControllerProvider);
    await refresh();
  }
}
