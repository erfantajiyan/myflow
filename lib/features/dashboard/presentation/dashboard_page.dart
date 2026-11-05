import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/date_time/jalali_date_parts.dart';
import '../../../core/date_time/jalali_date_service.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/utils/persian_digits.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../../core/widgets/app_section_header.dart';

/// داشبورد — بخش ۷.۱ سند.
///
/// در این فاز فقط تاریخ شمسی واقعی و ساختار صفحه‌ی روز نمایش داده می‌شود؛
/// اعداد رویداد و وظیفه پس از آماده شدن لایه‌ی داده (فاز ۲ به بعد) از
/// Repository واقعی خوانده می‌شوند و هیچ داده‌ی ساختگی جایش نمی‌نشیند.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final JalaliDateService dates = ref.watch(jalaliDateServiceProvider);
    final DateTime now = ref.watch(nowProvider)();
    final JalaliDateParts today = dates.partsOf(now);

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
        onPressed: () => _showQuickAdd(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('افزودن'),
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl * 2),
        children: <Widget>[
          _TodayCard(
            dates: dates,
            today: today,
            weekday: dates.weekDayName(now),
            onTap: () => context.goNamed('calendar'),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          AppSectionHeader(
            title: 'برنامه‌ی امروز',
            trailing: TextButton(
              onPressed: () => context.pushNamed('timeline'),
              child: const Text('تایم‌لاین'),
            ),
          ),
          AppCard(
            child: AppEmptyState(
              icon: Icons.event_note_outlined,
              title: 'برنامه‌ی امروز خالی است',
              message:
                  'رویدادهای زمان‌دار پس از فعال شدن فرم رویداد، اینجا به‌ترتیب '
                  'ساعت نمایش داده می‌شوند.',
              action: AppButton(
                label: 'افزودن رویداد',
                icon: Icons.add_rounded,
                onPressed: () => context.pushNamed('events'),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          AppSectionHeader(
            title: 'وظایف امروز',
            trailing: TextButton(
              onPressed: () => context.goNamed('tasks'),
              child: const Text('همه‌ی وظایف'),
            ),
          ),
          AppCard(
            child: AppEmptyState(
              icon: Icons.checklist_rounded,
              title: 'وظیفه‌ای برای امروز نیست',
              message:
                  'وظایف بدون ساعت هم در این بخش دیده می‌شوند؛ فقط تاریخ '
                  'سررسیدشان امروز باید باشد.',
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const AppSectionHeader(title: 'زمان آزاد امروز'),
          AppCard(
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(
                    Icons.schedule_rounded,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'بازه‌های خالی روز',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        'از تفاضل زمان روز و رویدادها محاسبه می‌شود.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '—',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showQuickAdd(BuildContext context) {
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
                context.pushNamed('events');
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

}

/// کارت خلاصه‌ی روز: شماره‌ی روز، روز هفته، ماه و سال شمسی.
class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.dates,
    required this.today,
    required this.weekday,
    required this.onTap,
  });

  final JalaliDateService dates;
  final JalaliDateParts today;
  final String weekday;
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
              ],
            ),
          ),
          Icon(
            Icons.chevron_left_rounded,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
