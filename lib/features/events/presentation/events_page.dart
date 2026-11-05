import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/date_time/jalali_date_service.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../../database/event_repository_impl.dart';
import '../../../database/responsibility_repository_impl.dart';
import '../../responsibilities/data/responsibilities_controller.dart';
import '../data/events_controller.dart';
import 'event_editor_sheet.dart';

/// رویدادها — لیست روزانه، بخش ۷.۳ و ۸.۲ سند.
///
/// این صفحه فهرست رویدادهای یک روز شمسی را از دیتابیس می‌خواند، امکان
/// ساخت/ویرایش/حذف می‌دهد و مسیر ورود به فرم و جزئیات است. شبکه‌ی ماه و
/// تایم‌لاین در فازهای ۶ و ۷ روی همین داده ساخته می‌شوند.
class EventsPage extends ConsumerWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final JalaliDateService dates = ref.watch(jalaliDateServiceProvider);
    final DateTime day = ref.watch(selectedEventDayProvider);
    final AsyncValue<List<Event>> asyncEvents = ref.watch(dayEventsProvider);
    final List<Responsibility> responsibilities =
        ref.watch(responsibilitiesControllerProvider).value ??
        const <Responsibility>[];
    final Map<String, Responsibility> byId = <String, Responsibility>{
      for (final Responsibility responsibility in responsibilities)
        responsibility.id: responsibility,
    };

    return AppPageScaffold(
      title: 'رویدادها',
      subtitle: '${dates.weekDayName(day)} • ${dates.formatLong(day)}',
      actions: <Widget>[
        IconButton(
          tooltip: 'روز قبل',
          onPressed: () =>
              ref.read(selectedEventDayProvider.notifier).previousDay(),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
        IconButton(
          tooltip: 'امروز',
          onPressed: () => ref
              .read(selectedEventDayProvider.notifier)
              .select(ref.read(nowProvider)()),
          icon: const Icon(Icons.today_outlined),
        ),
        IconButton(
          tooltip: 'روز بعد',
          onPressed: () =>
              ref.read(selectedEventDayProvider.notifier).nextDay(),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('رویداد جدید'),
      ),
      child: asyncEvents.when(
        loading: () => const AppLoading(label: 'در حال خواندن رویدادها…'),
        error: (Object error, StackTrace stackTrace) => AppErrorState(
          title: 'خواندن رویدادها ممکن نشد',
          message: 'ارتباط با دیتابیس محلی برقرار نشد. یک بار دیگر تلاش کنید.',
          onRetry: () => ref.invalidate(dayEventsProvider),
        ),
        data: (List<Event> events) {
          if (events.isEmpty) {
            return AppEmptyState(
              icon: Icons.event_note_outlined,
              title: 'برای این روز رویدادی ثبت نشده',
              message:
                  'رویدادها ساعت‌دار هستند یا کل روز را می‌پوشانند. '
                  'با دکمه‌ی پایین اولین رویداد این روز را بسازید.',
              action: AppButton(
                label: 'افزودن رویداد',
                icon: Icons.add_rounded,
                onPressed: () => _openEditor(context, ref),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl * 2),
            itemCount: events.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(height: AppSpacing.xs),
            itemBuilder: (BuildContext context, int index) {
              final Event event = events[index];
              return _EventTile(
                event: event,
                responsibility: byId[event.responsibilityId],
              );
            },
          );
        },
      ),
    );
  }
}

Future<void> _openEditor(BuildContext context, WidgetRef ref) async {
  final DateTime day = ref.read(selectedEventDayProvider);
  final EventEditorResult? result = await showAppBottomSheet<EventEditorResult>(
    context: context,
    title: 'رویداد جدید',
    builder: (BuildContext sheetContext) =>
        EventEditorSheet(initialDate: day),
  );

  if (!context.mounted || result == null) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('رویداد ثبت شد.')),
  );
}

class _EventTile extends ConsumerWidget {
  const _EventTile({required this.event, this.responsibility});

  final Event event;
  final Responsibility? responsibility;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final JalaliDateService dates = ref.watch(jalaliDateServiceProvider);
    final TextTheme text = Theme.of(context).textTheme;
    final Color accent = responsibility?.color ?? AppColors.textSecondary;
    final String? location = event.location;

    return AppCard(
      onTap: () => context.pushNamed(
        'eventDetails',
        pathParameters: <String, String>{'id': event.id},
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 64,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (event.allDay)
                  Text('تمام‌روز', style: text.labelLarge)
                else ...<Widget>[
                  Text(
                    dates.formatTime(event.startLocal),
                    style: text.titleSmall,
                  ),
                  Text(
                    'تا ${dates.formatTime(event.endLocal)}',
                    style: text.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            width: 3,
            height: 40,
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
                Text(
                  event.title,
                  style: text.titleSmall?.copyWith(
                    decoration: event.isCancelled
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Row(
                  children: <Widget>[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Text(
                      responsibility?.name ?? 'بدون مسئولیت',
                      style: text.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (location != null && location.isNotEmpty) ...<Widget>[
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          '• $location',
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (event.isCompleted)
            const _StatusChip(label: 'انجام‌شده', color: AppColors.success)
          else if (event.isCancelled)
            const _StatusChip(label: 'لغوشده', color: AppColors.error),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
      ),
    );
  }
}
