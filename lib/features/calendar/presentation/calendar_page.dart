import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/date_time/date_only.dart';
import '../../../core/date_time/jalali_date_parts.dart';
import '../../../core/date_time/jalali_date_service.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/utils/persian_digits.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../../database/event_repository_impl.dart';
import '../../../database/responsibility_repository_impl.dart';
import '../../../database/task_repository_impl.dart';
import '../../events/presentation/event_editor_sheet.dart';
import '../../responsibilities/data/responsibilities_controller.dart';
import '../../tasks/data/tasks_controller.dart';
import '../data/calendar_controller.dart';
import '../../settings/data/settings_controller.dart';
import '../../settings/domain/app_settings.dart';

/// کلیدهای تست تقویم.
const Key calendarPreviousKey = Key('calendarPrevious');
const Key calendarNextKey = Key('calendarNext');
const Key calendarTodayKey = Key('calendarToday');
const Key calendarMonthModeKey = Key('calendarMonthMode');
const Key calendarWeekModeKey = Key('calendarWeekMode');
const Key calendarDaySummaryKey = Key('calendarDaySummary');
const Key calendarOpenTimelineKey = Key('calendarOpenTimeline');
const Key calendarAddEventKey = Key('calendarAddEvent');
const Key calendarFilterAllKey = Key('calendarFilterAll');

Key calendarDayCellKey(DateTime day) =>
    ValueKey<String>('calendar-day-${formatDateOnly(day)}');

Key calendarWeekDayCardKey(DateTime day) =>
    ValueKey<String>('calendar-week-day-${formatDateOnly(day)}');

/// تقویم شمسی — بخش ۷.۲ سند.
///
/// شبکه‌ی ماه (شنبه تا جمعه) با نشانگر رنگی رویدادها، نمای هفتگی، فیلتر
/// مسئولیت و خلاصه‌ی روز انتخاب‌شده. همه‌ی داده از Repository خوانده می‌شود؛
/// هیچ محاسبه‌ی تقویمی خارج از [JalaliDateService] انجام نمی‌شود.
class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final JalaliDateService dates = ref.watch(jalaliDateServiceProvider);
    final CalendarViewMode mode = ref.watch(calendarViewModeProvider);
    final DateTime month = ref.watch(calendarMonthProvider);
    final DateTime selected = ref.watch(calendarSelectedDayProvider);

    final String subtitle = switch (mode) {
      CalendarViewMode.month => dates.formatMonthYear(
        dates.partsOf(month).year,
        dates.partsOf(month).month,
      ),
      CalendarViewMode.week =>
        'هفته‌ی ${dates.formatShort(dates.startOfWeek(selected))}',
    };

    return AppPageScaffold(
      title: 'تقویم',
      subtitle: subtitle,
      actions: <Widget>[
        IconButton(
          key: calendarPreviousKey,
          tooltip: mode == CalendarViewMode.month ? 'ماه قبل' : 'هفته قبل',
          onPressed: () => _step(ref, -1),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
        IconButton(
          key: calendarTodayKey,
          tooltip: 'امروز',
          onPressed: () => ref.read(calendarMonthProvider.notifier).goToToday(),
          icon: const Icon(Icons.today_outlined),
        ),
        IconButton(
          key: calendarNextKey,
          tooltip: mode == CalendarViewMode.month ? 'ماه بعد' : 'هفته بعد',
          onPressed: () => _step(ref, 1),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
      ],
      // دکمه‌ی شناور اینجا حذف شده است: خلاصه‌ی روز خودش «رویداد جدید»
      // دارد و FAB روی همان دکمه می‌افتاد.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _CalendarToolbar(),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: switch (mode) {
              CalendarViewMode.month => const _MonthView(),
              CalendarViewMode.week => const _WeekView(),
            },
          ),
        ],
      ),
    );
  }

  /// جابه‌جایی ماه یا هفته بسته به نمای فعال.
  void _step(WidgetRef ref, int direction) {
    final CalendarViewMode mode = ref.read(calendarViewModeProvider);
    if (mode == CalendarViewMode.month) {
      final CalendarMonthController controller = ref.read(
        calendarMonthProvider.notifier,
      );
      if (direction < 0) {
        controller.previous();
      } else {
        controller.next();
      }
      return;
    }

    final JalaliDateService dates = ref.read(jalaliDateServiceProvider);
    final DateTime selected = ref.read(calendarSelectedDayProvider);
    ref
        .read(calendarSelectedDayProvider.notifier)
        .select(dates.addDays(selected, direction * 7));
  }
}

/// انتخاب نمای ماه/هفته و فیلتر مسئولیت.
class _CalendarToolbar extends ConsumerWidget {
  const _CalendarToolbar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CalendarViewMode mode = ref.watch(calendarViewModeProvider);
    final String? filter = ref.watch(calendarResponsibilityFilterProvider);
    final List<Responsibility> responsibilities =
        ref.watch(responsibilitiesControllerProvider).value ??
        const <Responsibility>[];
    final List<Responsibility> active = responsibilities
        .where(
          (Responsibility item) => item.isActive && item.archivedAt == null,
        )
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            for (final CalendarViewMode option in CalendarViewMode.values)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: AppSpacing.xs),
                child: ChoiceChip(
                  key: option == CalendarViewMode.month
                      ? calendarMonthModeKey
                      : calendarWeekModeKey,
                  label: Text('نمای ${option.label}'),
                  selected: option == mode,
                  onSelected: (bool _) => ref
                      .read(calendarViewModeProvider.notifier)
                      .select(option),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              ChoiceChip(
                key: calendarFilterAllKey,
                label: const Text('همه'),
                selected: filter == null,
                onSelected: (bool _) => ref
                    .read(calendarResponsibilityFilterProvider.notifier)
                    .select(null),
              ),
              for (final Responsibility responsibility in active)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: AppSpacing.xxs,
                  ),
                  child: ChoiceChip(
                    avatar: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: responsibility.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    label: Text(responsibility.name),
                    selected: filter == responsibility.id,
                    onSelected: (bool selectedNow) => ref
                        .read(calendarResponsibilityFilterProvider.notifier)
                        .select(selectedNow ? responsibility.id : null),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// شبکه‌ی ماه + خلاصه‌ی روز انتخاب‌شده.
class _MonthView extends ConsumerWidget {
  const _MonthView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final JalaliDateService dates = ref.watch(jalaliDateServiceProvider);
    final DateTime month = ref.watch(calendarMonthProvider);
    final DateTime selected = ref.watch(calendarSelectedDayProvider);
    final AsyncValue<Map<DateTime, CalendarDayActivity>> asyncActivity = ref
        .watch(calendarActivityProvider);
    final Map<String, Responsibility> byId = _responsibilitiesById(ref);

    final JalaliDateParts parts = dates.partsOf(month);
    final List<List<JalaliMonthCell>> grid = dates.monthGrid(
      parts.year,
      parts.month,
    );
    final Map<DateTime, CalendarDayActivity> activity =
        asyncActivity.value ?? const <DateTime, CalendarDayActivity>{};
    final DateTime today = ref.watch(nowProvider)();

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl * 2),
      children: <Widget>[
        const _WeekdayHeader(),
        for (final List<JalaliMonthCell> week in grid)
          Row(
            children: <Widget>[
              for (final JalaliMonthCell cell in week)
                Expanded(
                  child: _MonthCell(
                    cell: cell,
                    activity: CalendarActivityController.activityFor(
                      activity,
                      cell.date,
                    ),
                    responsibilitiesById: byId,
                    isSelected: dates.isSameJalaliDay(cell.date, selected),
                    isToday: dates.isSameJalaliDay(cell.date, today),
                    onTap: () {
                      if (cell.isInMonth) {
                        ref
                            .read(calendarSelectedDayProvider.notifier)
                            .select(cell.date);
                      } else {
                        ref
                            .read(calendarMonthProvider.notifier)
                            .selectMonthOf(cell.date);
                      }
                    },
                  ),
                ),
            ],
          ),
        const SizedBox(height: AppSpacing.md),
        if (asyncActivity.hasError)
          AppErrorState(
            title: 'خواندن برنامه‌ی ماه ممکن نشد',
            message: 'ارتباط با دیتابیس محلی برقرار نشد. یک بار دیگر تلاش کنید.',
            onRetry: () => ref.invalidate(calendarActivityProvider),
          )
        else
          _DaySummaryCard(
            day: selected,
            activity: CalendarActivityController.activityFor(activity, selected),
            responsibilitiesById: byId,
            isLoading: asyncActivity.isLoading,
          ),
      ],
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  static const List<String> _labels = <String>[
    'ش',
    'ی',
    'د',
    'س',
    'چ',
    'پ',
    'ج',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Row(
        children: <Widget>[
          for (final String label in _labels)
            Expanded(
              child: Center(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.cell,
    required this.activity,
    required this.responsibilitiesById,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  final JalaliMonthCell cell;
  final CalendarDayActivity activity;
  final Map<String, Responsibility> responsibilitiesById;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final Color dayColor = !cell.isInMonth
        ? AppColors.textSecondary.withValues(alpha: 0.55)
        : isSelected
        ? AppColors.accent
        : AppColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: Material(
        key: calendarDayCellKey(cell.date),
        color: isSelected
            ? AppColors.accent.withValues(alpha: 0.16)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(
            color: isSelected
                ? AppColors.accent
                : isToday
                ? AppColors.accent.withValues(alpha: 0.55)
                : Colors.transparent,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: onTap,
          child: SizedBox(
            height: 56,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  PersianDigits.fromInt(cell.parts.day),
                  style: text.bodyMedium?.copyWith(
                    color: dayColor,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                _ActivityDots(
                  activity: activity,
                  responsibilitiesById: responsibilitiesById,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// نشانگر فعالیت روز: حداکثر سه رنگ مسئولیت، یک نشانگر کهربایی برای
/// وظیفه‌ی باز و شمارش تجمیعی برای روزهای شلوغ (بخش ۷.۲ سند).
class _ActivityDots extends StatelessWidget {
  const _ActivityDots({
    required this.activity,
    required this.responsibilitiesById,
  });

  final CalendarDayActivity activity;
  final Map<String, Responsibility> responsibilitiesById;

  @override
  Widget build(BuildContext context) {
    final List<Color> colors = <Color>[];
    for (final Event event in activity.events) {
      if (event.isCancelled) continue;
      final Color color =
          responsibilitiesById[event.responsibilityId]?.color ??
          AppColors.textSecondary;
      if (!colors.contains(color)) {
        colors.add(color);
      }
      if (colors.length == 3) break;
    }
    final bool hasOpenTasks = activity.pendingTaskCount > 0;
    final int hiddenEvents = activity.activeEventCount - colors.length;

    final List<Widget> dots = <Widget>[
      for (final Color color in colors)
        Container(
          width: 5,
          height: 5,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      if (hasOpenTasks && colors.length < 3)
        Container(
          width: 5,
          height: 5,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: const BoxDecoration(
            color: AppColors.warning,
            shape: BoxShape.circle,
          ),
        ),
    ];

    if (dots.isEmpty) {
      return const SizedBox(height: 7);
    }

    return SizedBox(
      height: 7,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          ...dots,
          if (hiddenEvents > 0)
            Text(
              '+${PersianDigits.fromInt(hiddenEvents)}',
              style: const TextStyle(
                fontSize: 8,
                height: 0.9,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

/// خلاصه‌ی روز انتخاب‌شده: رویدادها به‌ترتیب ساعت و وظایف همان روز.
class _DaySummaryCard extends ConsumerWidget {
  const _DaySummaryCard({
    required this.day,
    required this.activity,
    required this.responsibilitiesById,
    required this.isLoading,
  });

  final DateTime day;
  final CalendarDayActivity activity;
  final Map<String, Responsibility> responsibilitiesById;
  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final JalaliDateService dates = ref.watch(jalaliDateServiceProvider);
    final TextTheme text = Theme.of(context).textTheme;

    return AppCard(
      key: calendarDaySummaryKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${dates.weekDayName(day)} • ${dates.formatLong(day)}',
                  style: text.titleSmall,
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (activity.isEmpty)
                Text(
                  'خالی',
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                )
              else
                Text(
                  _summaryLabel(activity),
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (!isLoading && activity.isEmpty)
            Text(
              'برای این روز رویداد یا وظیفه‌ای ثبت نشده است.',
              style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          for (final Event event in activity.events)
            _SummaryEventRow(
              event: event,
              responsibility: responsibilitiesById[event.responsibilityId],
            ),
          for (final Task task in activity.tasks)
            _SummaryTaskRow(task: task),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: <Widget>[
              Expanded(
                child: AppButton(
                  key: calendarOpenTimelineKey,
                  label: 'تایم‌لاین روز',
                  icon: Icons.view_day_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => _openTimeline(context, day),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: AppButton(
                  key: calendarAddEventKey,
                  label: 'رویداد جدید',
                  icon: Icons.add_rounded,
                  onPressed: () => _openEventEditor(context, ref, day),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _summaryLabel(CalendarDayActivity activity) {
    final List<String> parts = <String>[
      if (activity.activeEventCount > 0)
        '${PersianDigits.fromInt(activity.activeEventCount)} رویداد',
      if (activity.pendingTaskCount > 0)
        '${PersianDigits.fromInt(activity.pendingTaskCount)} کار باز',
    ];
    return parts.join(' • ');
  }
}

class _SummaryEventRow extends ConsumerWidget {
  const _SummaryEventRow({required this.event, this.responsibility});

  final Event event;
  final Responsibility? responsibility;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(currentSettingsProvider);
    final TextTheme text = Theme.of(context).textTheme;
    final Color accent = responsibility?.color ?? AppColors.textSecondary;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: () => context.pushNamed(
        'eventDetails',
        pathParameters: <String, String>{'id': event.id},
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 52,
              child: Text(
                event.allDay ? 'تمام‌روز' : settings.formatTime(event.startLocal),
                style: text.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Container(
              width: 3,
              height: 18,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            Expanded(
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
          ],
        ),
      ),
    );
  }
}

class _SummaryTaskRow extends ConsumerWidget {
  const _SummaryTaskRow({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextTheme text = Theme.of(context).textTheme;
    final String? time = task.dueTime;

    return Row(
      children: <Widget>[
        Checkbox(
          value: task.isCompleted,
          visualDensity: VisualDensity.compact,
          onChanged: (bool? _) => _toggle(ref),
        ),
        Expanded(
          child: Text(
            task.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodyMedium?.copyWith(
              color: task.isCompleted
                  ? AppColors.textSecondary
                  : AppColors.textPrimary,
              decoration: task.isCompleted
                  ? TextDecoration.lineThrough
                  : null,
            ),
          ),
        ),
        if (time != null)
          Text(
            PersianDigits.convert(time.substring(0, 5)),
            style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        if (task.isCancelled) ...<Widget>[
          const SizedBox(width: AppSpacing.xxs),
          Text(
            'لغو',
            style: text.bodySmall?.copyWith(color: AppColors.error),
          ),
        ],
      ],
    );
  }

  Future<void> _toggle(WidgetRef ref) async {
    final TasksController controller = ref.read(
      tasksControllerProvider.notifier,
    );
    if (task.isCompleted) {
      await controller.reopen(task.id);
    } else {
      await controller.complete(task.id);
    }
    ref.invalidate(calendarActivityProvider);
  }
}

/// نمای هفتگی: هفت کارت روز با رویدادهای مرتب بر اساس ساعت.
class _WeekView extends ConsumerWidget {
  const _WeekView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final JalaliDateService dates = ref.watch(jalaliDateServiceProvider);
    final DateTime selected = ref.watch(calendarSelectedDayProvider);
    final AsyncValue<Map<DateTime, CalendarDayActivity>> asyncActivity = ref
        .watch(calendarActivityProvider);
    final Map<String, Responsibility> byId = _responsibilitiesById(ref);
    final Map<DateTime, CalendarDayActivity> activity =
        asyncActivity.value ?? const <DateTime, CalendarDayActivity>{};
    final DateTime today = ref.watch(nowProvider)();
    final DateTime weekStart = dates.startOfWeek(selected);

    if (asyncActivity.hasError) {
      return AppErrorState(
        title: 'خواندن برنامه‌ی هفته ممکن نشد',
        message: 'ارتباط با دیتابیس محلی برقرار نشد. یک بار دیگر تلاش کنید.',
        onRetry: () => ref.invalidate(calendarActivityProvider),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl * 2),
      itemCount: 7,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: AppSpacing.xs),
      itemBuilder: (BuildContext context, int index) {
        final DateTime day = dates.addDays(weekStart, index);
        return _WeekDayCard(
          day: day,
          activity: CalendarActivityController.activityFor(activity, day),
          responsibilitiesById: byId,
          isToday: dates.isSameJalaliDay(day, today),
          isSelected: dates.isSameJalaliDay(day, selected),
          onTap: () {
            ref.read(calendarSelectedDayProvider.notifier).select(day);
            _openTimeline(context, day);
          },
        );
      },
    );
  }
}

class _WeekDayCard extends ConsumerWidget {
  const _WeekDayCard({
    required this.day,
    required this.activity,
    required this.responsibilitiesById,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime day;
  final CalendarDayActivity activity;
  final Map<String, Responsibility> responsibilitiesById;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final JalaliDateService dates = ref.watch(jalaliDateServiceProvider);
    final AppSettings settings = ref.watch(currentSettingsProvider);
    final TextTheme text = Theme.of(context).textTheme;
    final List<Event> events = activity.events;
    const int visibleLimit = 4;

    return AppCard(
      key: calendarWeekDayCardKey(day),
      onTap: onTap,
      borderColor: isSelected ? AppColors.accent : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                dates.weekDayName(day),
                style: text.titleSmall?.copyWith(
                  color: isToday ? AppColors.accent : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                dates.formatShort(day),
                style: text.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              if (isToday)
                Text(
                  'امروز',
                  style: text.bodySmall?.copyWith(color: AppColors.accent),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          if (events.isEmpty)
            Text(
              activity.tasks.isEmpty
                  ? 'رویدادی ثبت نشده'
                  : 'رویدادی نیست • ${PersianDigits.fromInt(activity.pendingTaskCount)} کار',
              style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
            )
          else
            for (final Event event in events.take(visibleLimit))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 46,
                      child: Text(
                        event.allDay
                            ? 'تمام‌روز'
                            : settings.formatTime(event.startLocal),
                        style: text.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Container(
                      width: 3,
                      height: 14,
                      margin: const EdgeInsetsDirectional.only(
                        end: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color:
                            responsibilitiesById[event.responsibilityId]?.color ??
                            AppColors.textSecondary,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    Expanded(
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
                  ],
                ),
              ),
          if (events.length > visibleLimit)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Text(
                'و ${PersianDigits.fromInt(events.length - visibleLimit)} رویداد دیگر',
                style: text.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Map<String, Responsibility> _responsibilitiesById(WidgetRef ref) {
  final List<Responsibility> all =
      ref.watch(responsibilitiesControllerProvider).value ??
      const <Responsibility>[];
  return <String, Responsibility>{
    for (final Responsibility responsibility in all)
      responsibility.id: responsibility,
  };
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
  ref.invalidate(calendarActivityProvider);
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
