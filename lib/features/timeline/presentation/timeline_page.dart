import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/date_time/jalali_date_service.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/utils/duration_text.dart';
import '../../../core/utils/persian_digits.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../../database/event_repository_impl.dart';
import '../../../database/responsibility_repository_impl.dart';

import '../../events/presentation/event_editor_sheet.dart';
import '../../responsibilities/data/responsibilities_controller.dart';
import '../data/timeline_controller.dart';
import 'timeline_layout.dart';

const Key timelinePreviousKey = Key('timelinePrevious');
const Key timelineNextKey = Key('timelineNext');
const Key timelineTodayKey = Key('timelineToday');
const Key timelineEmptyNoticeKey = Key('timelineEmptyNotice');
const Key timelineAxisKey = Key('timelineAxis');
const Key timelineNowLineKey = Key('timelineNowLine');

Key timelineBlockKey(String eventId) =>
    ValueKey<String>('timeline-block-$eventId');

Key timelineFreeSlotKey(int startMinute) =>
    ValueKey<String>('timeline-free-$startMinute');

/// ارتفاع هر ساعت در محور؛ سند ۶۰ تا ۷۲dp را مجاز می‌داند.
const double timelineHourHeight = 64;

/// تایم‌لاین ۲۴ ساعته — بخش ۷.۳ سند (مهم‌ترین صفحه‌ی محصول).
///
/// محور ۰۰:۰۰ تا ۲۴:۰۰، بلوک رویدادها با عرض مشترک در هم‌پوشانی، خط زمان
/// فعلی، بازه‌های آزاد محاسبه‌شده (بدون ذخیره در دیتابیس) و افزودن رویداد
/// با لمس فضای خالی.
class TimelinePage extends ConsumerStatefulWidget {
  const TimelinePage({super.key, this.initialDate});

  /// تاریخ ورودی از مسیر (`/timeline?date=YYYY-MM-DD`)؛ برای پرش از تقویم
  /// یا داشبورد به همان روز.
  final DateTime? initialDate;

  @override
  ConsumerState<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends ConsumerState<TimelinePage> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    final DateTime now = ref.read(nowProvider)();
    final DateTime focusDay = widget.initialDate ?? now;
    final JalaliDateService dates = ref.read(jalaliDateServiceProvider);
    final bool isToday = dates.isSameJalaliDay(focusDay, now);
    final double offset =
        (isToday ? math.max(0, now.hour - 2) : 7) * timelineHourHeight;
    _scrollController = ScrollController(initialScrollOffset: offset);

    final DateTime? initialDate = widget.initialDate;
    if (initialDate != null) {
      Future<void>.microtask(() {
        if (!mounted) return;
        ref.read(timelineDayProvider.notifier).select(initialDate);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final JalaliDateService dates = ref.watch(jalaliDateServiceProvider);
    final DateTime day = ref.watch(timelineDayProvider);
    final AsyncValue<List<Event>> asyncEvents = ref.watch(
      timelineEventsProvider,
    );
    final DateTime now = ref.watch(nowProvider)();
    final bool isToday = dates.isSameJalaliDay(day, now);

    return AppPageScaffold(
      title: 'تایم‌لاین',
      subtitle: '${dates.weekDayName(day)} • ${dates.formatLong(day)}',
      actions: <Widget>[
        IconButton(
          key: timelinePreviousKey,
          tooltip: 'روز قبل',
          onPressed: () => ref.read(timelineDayProvider.notifier).previousDay(),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
        IconButton(
          key: timelineTodayKey,
          tooltip: 'امروز',
          onPressed: () => ref.read(timelineDayProvider.notifier).goToToday(),
          icon: const Icon(Icons.today_outlined),
        ),
        IconButton(
          key: timelineNextKey,
          tooltip: 'روز بعد',
          onPressed: () => ref.read(timelineDayProvider.notifier).nextDay(),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, day: day),
        icon: const Icon(Icons.add_rounded),
        label: const Text('رویداد جدید'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _ResponsibilityFilterBar(),
          const SizedBox(height: AppSpacing.xxs),
          Expanded(
            child: asyncEvents.when(
              loading: () => const AppLoading(label: 'در حال خواندن برنامه…'),
              error: (Object error, StackTrace stackTrace) => AppErrorState(
                title: 'خواندن برنامه‌ی روز ممکن نشد',
                message:
                    'ارتباط با دیتابیس محلی برقرار نشد. یک بار دیگر تلاش کنید.',
                onRetry: () => ref.invalidate(timelineEventsProvider),
              ),
              data: (List<Event> events) {
                final Map<String, Responsibility> byId = _responsibilitiesById(
                  ref,
                );
                return _TimelineBody(
                  dates: dates,
                  day: day,
                  events: events,
                  responsibilitiesById: byId,
                  isToday: isToday,
                  now: now,
                  scrollController: _scrollController,
                  onEmptyTap: (int startMinute) =>
                      _openEditor(context, day: day, startMinutes: startMinute),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponsibilityFilterBar extends ConsumerWidget {
  const _ResponsibilityFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? filter = ref.watch(timelineResponsibilityFilterProvider);
    final List<Responsibility> all =
        ref.watch(responsibilitiesControllerProvider).value ??
        const <Responsibility>[];
    final List<Responsibility> active = all
        .where(
          (Responsibility item) => item.isActive && item.archivedAt == null,
        )
        .toList(growable: false);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          ChoiceChip(
            label: const Text('همه'),
            selected: filter == null,
            onSelected: (bool _) => ref
                .read(timelineResponsibilityFilterProvider.notifier)
                .select(null),
          ),
          for (final Responsibility responsibility in active)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: AppSpacing.xxs),
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
                    .read(timelineResponsibilityFilterProvider.notifier)
                    .select(selectedNow ? responsibility.id : null),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimelineBody extends StatelessWidget {
  const _TimelineBody({
    required this.dates,
    required this.day,
    required this.events,
    required this.responsibilitiesById,
    required this.isToday,
    required this.now,
    required this.scrollController,
    required this.onEmptyTap,
  });

  final JalaliDateService dates;
  final DateTime day;
  final List<Event> events;
  final Map<String, Responsibility> responsibilitiesById;
  final bool isToday;
  final DateTime now;
  final ScrollController scrollController;
  final ValueChanged<int> onEmptyTap;

  @override
  Widget build(BuildContext context) {
    final List<Event> allDayEvents = TimelineLayout.allDayEvents(events);
    final List<TimelineBlock> blocks = TimelineLayout.blocksFor(events, day);
    final List<FreeRange> freeRanges = TimelineLayout.freeRanges(blocks);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (events.isEmpty)
          AppCard(
            key: timelineEmptyNoticeKey,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Text(
              'برنامه‌ای برای این روز نیست؛ با لمس هر ساعت از محور رویداد بسازید.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        if (events.isEmpty) const SizedBox(height: AppSpacing.xs),
        if (allDayEvents.isNotEmpty) ...<Widget>[
          Wrap(
            spacing: AppSpacing.xxs,
            runSpacing: AppSpacing.xxs,
            children: <Widget>[
              for (final Event event in allDayEvents)
                _AllDayChip(
                  event: event,
                  responsibility: responsibilitiesById[event.responsibilityId],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: <Widget>[
                _InfoChip(
                  icon: Icons.event_available_rounded,
                  label:
                      '${PersianDigits.fromInt(blocks.length + allDayEvents.length)} رویداد',
                ),
                const SizedBox(width: AppSpacing.md),
                _InfoChip(
                  icon: Icons.schedule_rounded,
                  label:
                      '${formatDurationLabel(TimelineLayout.totalFreeMinutes(freeRanges))} آزاد',
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.only(bottom: 140),
            children: <Widget>[
              SizedBox(
                height: timelineHourHeight * 24,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _HourLabels(hourHeight: timelineHourHeight),
                    Expanded(
                      child: LayoutBuilder(
                        builder:
                            (BuildContext context, BoxConstraints constraints) {
                              return Stack(
                                key: timelineAxisKey,
                                children: <Widget>[
                                  Positioned.fill(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTapDown: (TapDownDetails details) {
                                        final double rawMinutes =
                                            details.localPosition.dy /
                                            timelineHourHeight *
                                            60;
                                        final int snapped =
                                            (rawMinutes / 15).round() * 15;
                                        onEmptyTap(
                                          snapped.clamp(0, 23 * 60 + 45),
                                        );
                                      },
                                    ),
                                  ),
                                  for (int hour = 0; hour <= 24; hour++)
                                    Positioned(
                                      top: hour * timelineHourHeight,
                                      left: 0,
                                      right: 0,
                                      child: IgnorePointer(
                                        child: Container(
                                          height: 1,
                                          color: AppColors.border.withValues(
                                            alpha: hour % 6 == 0 ? 0.9 : 0.45,
                                          ),
                                        ),
                                      ),
                                    ),
                                  for (final FreeRange range in freeRanges)
                                    if (range.durationMinutes >= 60)
                                      _FreeSlot(
                                        range: range,
                                        hourHeight: timelineHourHeight,
                                        onTap: () =>
                                            onEmptyTap(range.startMinute),
                                      ),
                                  for (final TimelineBlock block in blocks)
                                    _EventBlock(
                                      block: block,
                                      hourHeight: timelineHourHeight,
                                      width: constraints.maxWidth,
                                      responsibility:
                                          responsibilitiesById[block
                                              .event
                                              .responsibilityId],
                                      dates: dates,
                                    ),
                                  if (isToday)
                                    Positioned(
                                      key: timelineNowLineKey,
                                      top:
                                          (now.hour + now.minute / 60) *
                                          timelineHourHeight,
                                      left: 0,
                                      right: 0,
                                      child: IgnorePointer(
                                        child: Row(
                                          children: <Widget>[
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                color: AppColors.error,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            Expanded(
                                              child: Container(
                                                height: 1.5,
                                                color: AppColors.error,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HourLabels extends StatelessWidget {
  const _HourLabels({required this.hourHeight});

  final double hourHeight;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return SizedBox(
      width: 46,
      child: Column(
        children: <Widget>[
          for (int hour = 0; hour < 24; hour++)
            SizedBox(
              height: hourHeight,
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: Text(
                  PersianDigits.convert(
                    '${hour.toString().padLeft(2, '0')}:00',
                  ),
                  style: text.labelSmall?.copyWith(
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

class _EventBlock extends StatelessWidget {
  const _EventBlock({
    required this.block,
    required this.hourHeight,
    required this.width,
    required this.responsibility,
    required this.dates,
  });

  final TimelineBlock block;
  final double hourHeight;
  final double width;
  final Responsibility? responsibility;
  final JalaliDateService dates;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final Color accent = responsibility?.color ?? AppColors.accent;
    final double laneWidth = width / block.columns;
    final double blockWidth = math.max(laneWidth - 4, 24);
    final double top = block.startMinute / 60 * hourHeight;
    final double height = math.max(block.durationMinutes / 60 * hourHeight, 24);
    final Event event = block.event;
    final bool showTime = height >= 40;

    return PositionedDirectional(
      key: timelineBlockKey(event.id),
      top: top,
      start: block.column * laneWidth,
      width: blockWidth,
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1.5),
        child: Material(
          color: accent.withValues(alpha: event.isCancelled ? 0.08 : 0.18),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.pushNamed(
              'eventDetails',
              pathParameters: <String, String>{'id': event.id},
            ),
            child: Container(
              decoration: BoxDecoration(
                border: BorderDirectional(
                  start: BorderSide(color: accent, width: 3),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    event.title,
                    maxLines: showTime ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      decoration: event.isCancelled
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  if (showTime)
                    Text(
                      '${dates.formatTime(event.startLocal)} تا ${dates.formatTime(event.endLocal)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FreeSlot extends StatelessWidget {
  const _FreeSlot({
    required this.range,
    required this.hourHeight,
    required this.onTap,
  });

  final FreeRange range;
  final double hourHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      key: timelineFreeSlotKey(range.startMinute),
      top: range.startMinute / 60 * hourHeight,
      height: range.durationMinutes / 60 * hourHeight,
      start: 0,
      end: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            onTap: onTap,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.6),
                ),
              ),
              child: Text(
                '${formatDurationLabel(range.durationMinutes)} آزاد',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AllDayChip extends StatelessWidget {
  const _AllDayChip({required this.event, this.responsibility});

  final Event event;
  final Responsibility? responsibility;

  @override
  Widget build(BuildContext context) {
    final Color accent = responsibility?.color ?? AppColors.accent;
    return Material(
      color: accent.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: () => context.pushNamed(
          'eventDetails',
          pathParameters: <String, String>{'id': event.id},
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 6,
          ),
          child: Text(
            '${event.title} • تمام‌روز',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.xxs),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ],
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

Future<void> _openEditor(
  BuildContext context, {
  required DateTime day,
  int? startMinutes,
}) async {
  final int start = startMinutes ?? 10 * 60;
  final EventEditorResult? result = await showAppBottomSheet<EventEditorResult>(
    context: context,
    title: 'رویداد جدید',
    builder: (BuildContext sheetContext) => EventEditorSheet(
      initialDate: day,
      initialStartMinutes: start,
      initialEndMinutes: math.min(start + 60, 24 * 60),
    ),
  );
  if (!context.mounted || result == null) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(const SnackBar(content: Text('رویداد ثبت شد.')));
}
