import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/providers/data_revision_provider.dart';
import '../../../database/event_repository_impl.dart';
import '../../../database/task_repository_impl.dart';
import '../../events/data/events_controller.dart';
import '../../tasks/data/tasks_controller.dart';
import '../../timeline/presentation/timeline_layout.dart';

/// خلاصه‌ی وضعیت امروز برای داشبورد — بخش ۷.۱ سند.
///
/// همه‌ی اعداد از Repository خوانده می‌شوند؛ هیچ مقدار ساختگی در UI نمی‌ماند.
class TodayOverview {
  const TodayOverview({
    required this.events,
    required this.todayTasks,
    required this.freeRanges,
    required this.openTaskCount,
    required this.completedTodayCount,
    required this.scheduledMinutes,
  });

  /// رویدادهای امروز، مرتب بر اساس شروع (تمام‌روز اول).
  final List<Event> events;

  /// وظایف با سررسید امروز.
  final List<Task> todayTasks;

  /// بازه‌های آزاد محاسبه‌شده‌ی امروز (ذخیره نمی‌شوند).
  final List<FreeRange> freeRanges;

  /// همه‌ی وظایف باز، نه فقط امروز؛ «کار باز» در سند همین معناست.
  final int openTaskCount;

  final int completedTodayCount;

  /// مجموع دقیقه‌های برنامه‌ریزی‌شده‌ی امروز (رویدادهای ساعت‌دار).
  final int scheduledMinutes;

  int get freeMinutes => TimelineLayout.totalFreeMinutes(freeRanges);

  int get activeEventCount =>
      events.where((Event event) => !event.isCancelled).length;

  /// نزدیک‌ترین رویداد پیش‌روی امروز که لغو یا تمام نشده است.
  Event? nextEventAfter(DateTime now) {
    for (final Event event in events) {
      if (event.allDay || event.isCancelled || event.isCompleted) continue;
      if (event.startLocal.isAfter(now)) {
        return event;
      }
    }
    return null;
  }
}

final AsyncNotifierProvider<TodayOverviewController, TodayOverview>
todayOverviewProvider =
    AsyncNotifierProvider<TodayOverviewController, TodayOverview>(
      TodayOverviewController.new,
    );

class TodayOverviewController extends AsyncNotifier<TodayOverview> {
  @override
  Future<TodayOverview> build() async {
    // هر تغییر رویداد/وظیفه در هر صفحه‌ای، این خلاصه را تازه می‌کند.
    ref.watch(dataRevisionProvider);
    final DateTime now = ref.watch(nowProvider)();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final EventRepository eventRepository = ref.read(eventRepositoryProvider);
    final TaskRepository taskRepository = ref.read(taskRepositoryProvider);

    final List<Event> events = await eventRepository.getEventsForDay(today);
    final List<Task> todayTasks = await taskRepository.getTasks(
      filter: TaskFilter.today,
      today: today,
    );
    final List<Task> allTasks = await taskRepository.getTasks(today: today);

    final int openTaskCount = allTasks
        .where((Task task) => !task.isCompleted && !task.isCancelled)
        .length;
    final int completedTodayCount = allTasks.where((Task task) {
      final DateTime? completedAt = task.completedAtUtc?.toLocal();
      if (completedAt == null) return false;
      return completedAt.year == today.year &&
          completedAt.month == today.month &&
          completedAt.day == today.day;
    }).length;

    final List<TimelineBlock> blocks = TimelineLayout.blocksFor(events, today);
    final int scheduledMinutes = blocks.fold(
      0,
      (int sum, TimelineBlock block) => sum + block.durationMinutes,
    );

    return TodayOverview(
      events: events,
      todayTasks: todayTasks,
      freeRanges: TimelineLayout.freeRanges(blocks),
      openTaskCount: openTaskCount,
      completedTodayCount: completedTodayCount,
      scheduledMinutes: scheduledMinutes,
    );
  }

  /// بازخوانی پس از تغییر رویداد یا وظیفه.
  void refresh() => ref.invalidateSelf();
}
