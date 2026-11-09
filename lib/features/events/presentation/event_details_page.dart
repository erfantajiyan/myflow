import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/date_time/jalali_date_service.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../database/event_repository_impl.dart';
import '../../../database/responsibility_repository_impl.dart';
import '../../../shared/enums/app_enums.dart';
import '../../recurrence/domain/recurrence_rule.dart';
import '../../recurrence/presentation/recurrence_scope_dialog.dart';
import '../../responsibilities/data/responsibilities_controller.dart';
import '../data/events_controller.dart';
import 'event_editor_sheet.dart';

/// جزئیات یک رویداد — بخش ۷.۳ سند.
///
/// با شناسه‌ی رویداد باز می‌شود تا رفرش صفحه یا بازگشت به آن، داده‌ی
/// به‌روز را از دیتابیس بخواند (نه از یک شیء در حافظه).
class EventDetailsPage extends ConsumerStatefulWidget {
  const EventDetailsPage({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<EventDetailsPage> createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends ConsumerState<EventDetailsPage> {
  late Future<Event?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Event?> _load() =>
      ref.read(eventRepositoryProvider).getEventById(widget.eventId);

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _edit(Event event) async {
    final EventEditorResult? result = await showAppBottomSheet<EventEditorResult>(
      context: context,
      title: 'ویرایش رویداد',
      builder: (BuildContext sheetContext) => EventEditorSheet(
        initialDate: event.startLocal,
        existing: event,
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    _reload();
  }

  Future<void> _delete(Event event) async {
    final DayEventsController controller = ref.read(
      dayEventsProvider.notifier,
    );

    if (event.isOccurrence) {
      final RecurrenceEditScope? scope = await showRecurrenceScopeDialog(
        context: context,
        title: 'حذف رویداد تکراری',
      );
      if (scope == null || !mounted) {
        return;
      }
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      final NavigatorState navigator = Navigator.of(context);
      try {
        await controller.deleteOccurrence(id: event.id, scope: scope);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              scope == RecurrenceEditScope.allSeries
                  ? 'کل سری رویداد حذف شد.'
                  : 'رویداد از برنامه حذف شد.',
            ),
          ),
        );
        navigator.pop();
      } on EventRepositoryException catch (error) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      }
      return;
    }

    final bool confirmed = await showAppConfirmDialog(
      context: context,
      title: 'حذف رویداد',
      message:
          '«${event.title}» از برنامه حذف می‌شود. این عملیات قابل بازگشت '
          'نیست ولی داده برای بازیابی در دیتابیس می‌ماند.',
      confirmLabel: 'حذف',
      isDestructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);
    try {
      await controller.delete(event.id);
      messenger.showSnackBar(
        const SnackBar(content: Text('رویداد حذف شد.')),
      );
      navigator.pop();
    } on EventRepositoryException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final JalaliDateService dates = ref.watch(jalaliDateServiceProvider);
    final List<Responsibility> responsibilities =
        ref.watch(responsibilitiesControllerProvider).value ??
        const <Responsibility>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('جزئیات رویداد'),
        actions: <Widget>[
          FutureBuilder<Event?>(
            future: _future,
            builder: (BuildContext context, AsyncSnapshot<Event?> snapshot) {
              final Event? event = snapshot.data;
              if (event == null) {
                return const SizedBox.shrink();
              }
              return Row(
                children: <Widget>[
                  IconButton(
                    tooltip: 'ویرایش رویداد',
                    onPressed: () => _edit(event),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'حذف رویداد',
                    onPressed: () => _delete(event),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<Event?>(
          future: _future,
          builder: (BuildContext context, AsyncSnapshot<Event?> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppLoading(label: 'در حال خواندن رویداد…');
            }
            if (snapshot.hasError) {
              return const AppEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'خواندن رویداد ممکن نشد',
                message: 'یک بار دیگر تلاش کنید.',
              );
            }
            final Event? event = snapshot.data;
            if (event == null) {
              return const AppEmptyState(
                icon: Icons.event_busy_outlined,
                title: 'رویداد پیدا نشد',
                message: 'این رویداد حذف شده یا وجود ندارد.',
              );
            }
            final String? ruleId = event.recurrenceRuleId;
            return FutureBuilder<RecurrenceRule?>(
              future: ruleId == null
                  ? Future<RecurrenceRule?>.value(null)
                  : ref.read(eventRepositoryProvider).getRecurrenceRule(ruleId),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<RecurrenceRule?> ruleSnapshot,
                  ) {
                    return _DetailsBody(
                      event: event,
                      dates: dates,
                      recurrence: ruleSnapshot.data,
                      responsibility: _responsibilityFor(
                        responsibilities,
                        event.responsibilityId,
                      ),
                    );
                  },
            );
          },
        ),
      ),
    );
  }
}

Responsibility? _responsibilityFor(
  List<Responsibility> responsibilities,
  String id,
) {
  for (final Responsibility responsibility in responsibilities) {
    if (responsibility.id == id) {
      return responsibility;
    }
  }
  return null;
}

class _DetailsBody extends StatelessWidget {
  const _DetailsBody({
    required this.event,
    required this.dates,
    this.recurrence,
    this.responsibility,
  });

  final Event event;
  final JalaliDateService dates;
  final RecurrenceRule? recurrence;
  final Responsibility? responsibility;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final DateTime start = event.startLocal;
    final DateTime end = event.endLocal;
    final Color accent = responsibility?.color ?? AppColors.textSecondary;

    final String timeLabel = event.allDay
        ? 'تمام‌روز • ${dates.formatLong(start)}'
        : '${dates.formatTime(start)} تا ${dates.formatTime(end)}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        Text(event.title, style: text.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: <Widget>[
            Icon(
              Icons.calendar_month_outlined,
              size: 18,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xxs),
            Text(
              '${dates.weekDayName(start)} • ${dates.formatLong(start)}',
              style: text.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        Row(
          children: <Widget>[
            Icon(
              Icons.schedule_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xxs),
            Text(
              timeLabel,
              style: text.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        if (event.endLocal.day != event.startLocal.day &&
            !event.allDay) ...<Widget>[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'این رویداد پس از نیمه‌شب تمام می‌شود.',
            style: text.bodySmall?.copyWith(color: AppColors.warning),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppSectionHeader(title: 'مسئولیت'),
        Row(
          children: <Widget>[
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              responsibility?.name ?? 'مسئولیت حذف‌شده',
              style: text.bodyLarge,
            ),
          ],
        ),
        if (event.location != null && event.location!.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          AppSectionHeader(title: 'مکان'),
          Text(event.location!, style: text.bodyLarge),
        ],
        if (event.description != null &&
            event.description!.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          AppSectionHeader(title: 'توضیح'),
          Text(event.description!, style: text.bodyLarge),
        ],
        if (recurrence != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          AppSectionHeader(title: 'تکرار'),
          Text(
            recurrence!.untilLocalDate == null
                ? '${recurrence!.frequencyLabel} • بدون تاریخ پایان'
                : '${recurrence!.frequencyLabel} • تا '
                      '${dates.formatShort(recurrence!.untilLocalDate!)}',
            style: text.bodyLarge,
          ),
          if (event.isOccurrence) ...<Widget>[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'این رویداد یکی از نمونه‌های این سری است.',
              style: text.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
        const SizedBox(height: AppSpacing.lg),
        AppSectionHeader(title: 'وضعیت'),
        Text(
          switch (event.status) {
            EventStatus.planned => 'برنامه‌ریزی‌شده',
            EventStatus.completed => 'انجام‌شده',
            EventStatus.cancelled => 'لغوشده',
          },
          style: text.bodyLarge,
        ),
      ],
    );
  }
}
