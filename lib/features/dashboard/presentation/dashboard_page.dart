import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/date_time/date_only.dart';
import '../../../core/date_time/jalali_date_parts.dart';
import '../../../core/date_time/jalali_date_service.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/utils/duration_text.dart';
import '../../../core/utils/persian_digits.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../../database/event_repository_impl.dart';
import '../../../database/responsibility_repository_impl.dart';
import '../../../database/task_repository_impl.dart';
import '../../../shared/enums/app_enums.dart';
import '../../events/presentation/event_editor_sheet.dart';
import '../../responsibilities/data/responsibilities_controller.dart';
import '../../tasks/data/tasks_controller.dart';
import '../../timeline/presentation/timeline_layout.dart';
import '../data/dashboard_controller.dart';
import '../../settings/data/settings_controller.dart';
import '../../settings/domain/app_settings.dart';

const Key dashboardEventsSectionKey = Key('dashboardEventsSection');
const Key dashboardTasksSectionKey = Key('dashboardTasksSection');
const Key dashboardFreeTimeKey = Key('dashboardFreeTime');
const Key dashboardAddEventKey = Key('dashboardAddEvent');
const Key dashboardAllTasksKey = Key('dashboardAllTasks');

Key dashboardEventTileKey(String eventId) =>
    ValueKey<String>('dashboard-event-$eventId');

Key dashboardTaskTileKey(String taskId) =>
    ValueKey<String>('dashboard-task-$taskId');

/// داشبورد — بخش ۷.۱ سند.
///
/// تاریخ شمسی، شمار رویداد و کار باز، برنامه‌ی امروز با رویداد بعدی، وظایف
/// امروز با تکمیل سریع و زمان آزاد تخمینی. همه از دیتابیس محلی خوانده
/// می‌شود.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final JalaliDateService dates = ref.watch(jalaliDateServiceProvider);
    final DateTime now = ref.watch(nowProvider)();
    final JalaliDateParts today = dates.partsOf(now);
    final AsyncValue<TodayOverview> asyncOverview = ref.watch(
      todayOverviewProvider,
    );

    return AppPageScaffold(
      title: 'MyFlow',
      subtitle: '${dates.weekDayName(now)} • ${dates.formatLong(now)}',
      actions: <Widget>[
        IconButton(
          tooltip: 'مسئولیت‌ها',
          onPressed: () => context.pushNamed('responsibilities'),
          icon: const Icon(Icons.badge_outlined),
        ),
        IconButton(
          tooltip: 'تنظیمات',
          onPressed: () => context.pushNamed('settings'),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showQuickAdd(context, ref, now),
        icon: const Icon(Icons.add_rounded),
        label: const Text('افزودن'),
      ),
      child: asyncOverview.when(
        loading: () => const AppLoading(label: 'در حال خواندن امروز…'),
        error: (Object error, StackTrace stackTrace) => AppErrorState(
          title: 'خواندن وضعیت امروز ممکن نشد',
          message: 'ارتباط با دیتابیس محلی برقرار نشد. یک بار دیگر تلاش کنید.',
          onRetry: () => ref.invalidate(todayOverviewProvider),
        ),
        data: (TodayOverview overview) {
          final List<Responsibility> all =
              ref.watch(responsibilitiesControllerProvider).value ??
              const <Responsibility>[];
          final Map<String, Responsibility> byId = <String, Responsibility>{
            for (final Responsibility responsibility in all)
              responsibility.id: responsibility,
          };
          final Event? nextEvent = overview.nextEventAfter(now);

          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: <Widget>[
              _TodayCard(
                dates: dates,
                today: today,
                weekday: dates.weekDayName(now),
                eventCount: overview.activeEventCount,
                openTaskCount: overview.openTaskCount,
                onTap: () => context.goNamed('calendar'),
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              AppSectionHeader(
                title: 'برنامه‌ی امروز',
                trailing: TextButton(
                  onPressed: () => _openTimeline(context, now),
                  child: const Text('تایم‌لاین'),
                ),
              ),
              _EventsSection(
                key: dashboardEventsSectionKey,
                events: overview.events,
                responsibilitiesById: byId,
                dates: dates,
                nextEventId: nextEvent?.id,
                onAdd: () => _openEventEditor(context, ref, now),
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              AppSectionHeader(
                title: 'وظایف امروز',
                trailing: TextButton(
                  key: dashboardAllTasksKey,
                  onPressed: () => context.goNamed('tasks'),
                  child: const Text('همه‌ی وظایف'),
                ),
              ),
              _TasksSection(tasks: overview.todayTasks),
              const SizedBox(height: AppSpacing.sectionGap),
              const AppSectionHeader(title: 'زمان آزاد امروز'),
              _FreeTimeCard(
                key: dashboardFreeTimeKey,
                overview: overview,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// کارت خلاصه‌ی روز: شماره‌ی روز، روز هفته، ماه و سال شمسی و شمارش‌ها.
class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.dates,
    required this.today,
    required this.weekday,
    required this.eventCount,
    required this.openTaskCount,
    required this.onTap,
  });

  final JalaliDateService dates;
  final JalaliDateParts today;
  final String weekday;
  final int eventCount;
  final int openTaskCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              PersianDigits.fromInt(today.day),
              style: text.displaySmall?.copyWith(color: AppColors.accent),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(weekday, style: text.titleMedium),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  dates.formatMonthYear(today.year, today.month),
                  style: text.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${PersianDigits.fromInt(eventCount)} رویداد • ${PersianDigits.fromInt(openTaskCount)} کار باز',
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

class _EventsSection extends StatelessWidget {
  const _EventsSection({
    super.key,
    required this.events,
    required this.responsibilitiesById,
    required this.dates,
    required this.nextEventId,
    required this.onAdd,
  });

  final List<Event> events;
  final Map<String, Responsibility> responsibilitiesById;
  final JalaliDateService dates;
  final String? nextEventId;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return AppCard(
        child: AppEmptyState(
          icon: Icons.event_note_outlined,
          title: 'برنامه‌ی امروز خالی است',
          message: 'اولین رویداد امروز را بسازید تا در تایم‌لاین هم دیده شود.',
          action: AppButton(
            key: dashboardAddEventKey,
            label: 'افزودن رویداد',
            icon: Icons.add_rounded,
            onPressed: onAdd,
          ),
        ),
      );
    }

    return AppCard(
      child: Column(
        children: <Widget>[
          for (int index = 0; index < events.length; index++) ...<Widget>[
            if (index > 0)
              const Divider(height: AppSpacing.md, color: AppColors.border),
            _DashboardEventRow(
              event: events[index],
              responsibility:
                  responsibilitiesById[events[index].responsibilityId],
              dates: dates,
              isNext: events[index].id == nextEventId,
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppButton(
              label: 'افزودن رویداد',
              icon: Icons.add_rounded,
              variant: AppButtonVariant.ghost,
              onPressed: onAdd,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardEventRow extends ConsumerWidget {
  const _DashboardEventRow({
    required this.event,
    required this.responsibility,
    required this.dates,
    required this.isNext,
  });

  final Event event;
  final Responsibility? responsibility;
  final JalaliDateService dates;
  final bool isNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(currentSettingsProvider);
    final TextTheme text = Theme.of(context).textTheme;
    final Color accent = responsibility?.color ?? AppColors.textSecondary;

    return InkWell(
      key: dashboardEventTileKey(event.id),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: () => context.pushNamed(
        'eventDetails',
        pathParameters: <String, String>{'id': event.id},
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 56,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    event.allDay
                        ? 'تمام‌روز'
                        : settings.formatTime(event.startLocal),
                    style: text.bodySmall?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (!event.allDay)
                    Text(
                      'تا ${settings.formatTime(event.endLocal)}',
                      style: text.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              width: 3,
              height: 32,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          event.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium?.copyWith(
                            decoration: event.isCancelled
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                      if (isNext) ...<Widget>[
                        const SizedBox(width: AppSpacing.xxs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            'بعدی',
                            style: text.labelSmall?.copyWith(
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (responsibility != null)
                    Text(
                      responsibility!.name,
                      style: text.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TasksSection extends ConsumerWidget {
  const _TasksSection({required this.tasks});

  final List<Task> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tasks.isEmpty) {
      return AppCard(
        child: AppEmptyState(
          icon: Icons.checklist_rounded,
          title: 'وظیفه‌ای برای امروز نیست',
          message:
              'وظایف بدون ساعت هم در این بخش دیده می‌شوند؛ فقط تاریخ '
              'سررسیدشان امروز باید باشد.',
          action: AppButton(
            label: 'وظیفه‌ی جدید',
            icon: Icons.add_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () => context.goNamed('tasks'),
          ),
        ),
      );
    }

    final TextTheme text = Theme.of(context).textTheme;
    return AppCard(
      key: dashboardTasksSectionKey,
      child: Column(
        children: <Widget>[
          for (int index = 0; index < tasks.length; index++) ...<Widget>[
            if (index > 0)
              const Divider(height: AppSpacing.md, color: AppColors.border),
            Row(
              key: dashboardTaskTileKey(tasks[index].id),
              children: <Widget>[
                Checkbox(
                  value: tasks[index].isCompleted,
                  visualDensity: VisualDensity.compact,
                  onChanged: (bool? _) => _toggle(ref, tasks[index]),
                ),
                Expanded(
                  child: Text(
                    tasks[index].title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(
                      color: tasks[index].isCompleted
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      decoration: tasks[index].isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
                _PriorityChip(priority: tasks[index].priority),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _toggle(WidgetRef ref, Task task) async {
    final TasksController controller = ref.read(
      tasksControllerProvider.notifier,
    );
    if (task.isCompleted) {
      await controller.reopen(task.id);
    } else {
      await controller.complete(task.id);
    }
    ref.invalidate(todayOverviewProvider);
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority});

  final Priority priority;

  @override
  Widget build(BuildContext context) {
    final (String label, Color color) = switch (priority) {
      Priority.low => ('کم', AppColors.textSecondary),
      Priority.medium => ('متوسط', AppColors.warning),
      Priority.high => ('زیاد', AppColors.error),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

/// زمان آزاد امروز: مجموع و دو بازه‌ی بزرگ‌تر.
class _FreeTimeCard extends StatelessWidget {
  const _FreeTimeCard({super.key, required this.overview});

  final TodayOverview overview;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final List<FreeRange> ranges = List<FreeRange>.of(overview.freeRanges)
      ..sort(
        (FreeRange a, FreeRange b) =>
            b.durationMinutes.compareTo(a.durationMinutes),
      );
    final List<FreeRange> top = ranges.take(2).toList(growable: false);

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.schedule_rounded, color: AppColors.accent),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  formatDurationLabel(overview.freeMinutes),
                  style: text.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xxs),
                if (overview.scheduledMinutes == 0)
                  Text(
                    'امروز رویداد ساعت‌داری ثبت نشده و کل روز آزاد است.',
                    style: text.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  )
                else
                  for (final FreeRange range in top)
                    Text(
                      '${_timeLabel(range.startMinute)} تا ${_timeLabel(range.endMinute)}',
                      style: text.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _timeLabel(int minutes) {
    final String hour = (minutes ~/ 60).toString().padLeft(2, '0');
    final String minute = (minutes % 60).toString().padLeft(2, '0');
    return PersianDigits.convert('$hour:$minute');
  }
}

Future<void> _openEventEditor(
  BuildContext context,
  WidgetRef ref,
  DateTime day,
) async {
  final EventEditorResult? result = await showAppBottomSheet<EventEditorResult>(
    context: context,
    title: 'رویداد جدید',
    builder: (BuildContext sheetContext) =>
        EventEditorSheet(initialDate: day),
  );
  if (!context.mounted || result == null) return;
  ref.invalidate(todayOverviewProvider);
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('رویداد ثبت شد.')),
  );
}

void _openTimeline(BuildContext context, DateTime day) {
  context.pushNamed(
    'timeline',
    queryParameters: <String, String>{'date': formatDateOnly(day)},
  );
}

Future<void> _showQuickAdd(
  BuildContext context,
  WidgetRef ref,
  DateTime now,
) {
  return showAppBottomSheet<void>(
    context: context,
    title: 'افزودن سریع',
    builder: (BuildContext sheetContext) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppButton(
            label: 'رویداد جدید',
            icon: Icons.event_available_rounded,
            expand: true,
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _openEventEditor(context, ref, now);
            },
          ),
          const SizedBox(height: AppSpacing.xs),
          AppButton(
            label: 'وظیفه‌ی جدید',
            icon: Icons.checklist_rounded,
            variant: AppButtonVariant.secondary,
            expand: true,
            onPressed: () {
              Navigator.of(sheetContext).pop();
              context.goNamed('tasks');
            },
          ),
        ],
      );
    },
  );
}
