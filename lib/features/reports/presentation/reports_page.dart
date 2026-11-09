import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/date_time/jalali_date_service.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../settings/data/settings_controller.dart';
import '../../settings/domain/app_settings.dart';
import '../data/reports_controller.dart';
import '../domain/report_data.dart';

/// گزارش‌ها — بخش ۷.۶ سند.
///
/// اعداد از همان دیتابیس و همان مسیر گسترش تقویم می‌آیند تا با
/// چیزی که کاربر در تقویم/تایم‌لاین می‌بیند یکی باشد.
class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ReportData> asyncReport = ref.watch(reportsProvider);
    final DateTime month = ref.watch(reportMonthProvider);
    final JalaliDateService dates = ref.watch(jalaliDateServiceProvider);
    final AppSettings settings = ref.watch(currentSettingsProvider);

    return AppPageScaffold(
      title: 'گزارش‌ها',
      subtitle: 'زمان برنامه‌ریزی‌شده و وضعیت وظایف',
      child: asyncReport.when(
        loading: () => const AppLoading(),
        error: (Object error, StackTrace stackTrace) => AppEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'گزارش خوانده نشد',
          message: 'دوباره تلاش کنید. اگر تکرار شد، برنامه را باز کنید.',
          action: TextButton(
            onPressed: () => ref.read(reportsProvider.notifier).refresh(),
            child: const Text('تلاش دوباره'),
          ),
        ),
        data: (ReportData report) => ListView(
          children: <Widget>[
            _MonthSwitcher(
              label: dates.formatMonthYear(
                dates.partsOf(month).year,
                dates.partsOf(month).month,
                usePersianDigits: settings.usePersianDigits,
              ),
              onPrevious: () =>
                  ref.read(reportMonthProvider.notifier).previous(),
              onNext: () => ref.read(reportMonthProvider.notifier).next(),
            ),
            const SizedBox(height: AppSpacing.md),
            if (report.isEmpty)
              const AppEmptyState(
                icon: Icons.insights_outlined,
                title: 'داده‌ای برای این ماه نیست',
                message:
                    'با ثبت رویداد و وظیفه، گزارش زمان برنامه‌ریزی‌شده و '
                    'روند تکمیل همین‌جا ساخته می‌شود.',
              )
            else ...<Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.event_available_outlined,
                      label: 'رویدادها',
                      value: settings.digits('${report.eventCount}'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.timelapse_rounded,
                      label: 'زمان برنامه‌ریزی‌شده',
                      value: _hoursLabel(settings, report.plannedMinutes),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'وظایف تکمیل‌شده',
                      value: settings.digits('${report.tasksCompleted}'),
                      accent: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.warning_amber_rounded,
                      label: 'وظایف عقب‌افتاده',
                      value: settings.digits('${report.tasksOverdue}'),
                      accent: report.tasksOverdue > 0
                          ? AppColors.warning
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              const AppSectionHeader(title: 'تفکیک مسئولیت'),
              if (report.responsibilities.isEmpty)
                const AppCard(child: Text('در این ماه رویدادی ثبت نشده است.'))
              else
                AppCard(
                  child: Column(
                    children: <Widget>[
                      for (int i = 0;
                          i < report.responsibilities.length;
                          i++) ...<Widget>[
                        if (i > 0) const Divider(height: AppSpacing.lg),
                        _ResponsibilityRow(
                          report: report.responsibilities[i],
                          settings: settings,
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.sectionGap),
              const AppSectionHeader(title: 'روند تکمیل هفتگی'),
              AppCard(
                child: _WeeklyTrend(
                  weeks: report.weeklyCompletions,
                  settings: settings,
                  dates: dates,
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              AppSectionHeader(
                title: 'پروژه‌ها',
                trailing: Text(
                  '${settings.digits('${report.activeProjects}')} فعال',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              if (report.projects.isEmpty)
                const AppCard(child: Text('هنوز پروژه‌ای ساخته نشده است.'))
              else
                AppCard(
                  child: Column(
                    children: <Widget>[
                      for (int i = 0; i < report.projects.length; i++) ...<Widget>[
                        if (i > 0) const Divider(height: AppSpacing.lg),
                        _ProjectRow(
                          project: report.projects[i],
                          settings: settings,
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ],
        ),
      ),
    );
  }

  static String _hoursLabel(AppSettings settings, int minutes) {
    final String hours = (minutes / 60).toStringAsFixed(
      minutes % 60 == 0 ? 0 : 1,
    );
    return '${settings.digits(hours)} ساعت';
  }
}

class _MonthSwitcher extends StatelessWidget {
  const _MonthSwitcher({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          tooltip: 'ماه قبل',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: 'ماه بعد',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    this.accent = AppColors.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: accent),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: text.titleLarge),
          const SizedBox(height: 2),
          Text(
            label,
            style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ResponsibilityRow extends StatelessWidget {
  const _ResponsibilityRow({required this.report, required this.settings});

  final ResponsibilityReport report;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Row(
      children: <Widget>[
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: Color(report.colorValue),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(report.name, style: text.bodyMedium)),
        Text(
          '${settings.digits('${report.eventCount}')} رویداد • '
          '${settings.digits(_minutes(report.plannedMinutes))}',
          style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  static String _minutes(int minutes) {
    if (minutes < 60) {
      return '$minutes دقیقه';
    }
    final double hours = minutes / 60;
    return '${hours.toStringAsFixed(minutes % 60 == 0 ? 0 : 1)} ساعت';
  }
}

class _WeeklyTrend extends StatelessWidget {
  const _WeeklyTrend({
    required this.weeks,
    required this.settings,
    required this.dates,
  });

  final List<WeeklyCompletion> weeks;
  final AppSettings settings;
  final JalaliDateService dates;

  @override
  Widget build(BuildContext context) {
    final int maxCount = weeks.fold<int>(
      1,
      (int max, WeeklyCompletion week) =>
          week.completed > max ? week.completed : max,
    );
    final TextTheme text = Theme.of(context).textTheme;

    return Column(
      children: <Widget>[
        for (final WeeklyCompletion week in weeks)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 74,
                  child: Text(
                    dates.formatShort(
                      week.weekStart,
                      usePersianDigits: settings.usePersianDigits,
                    ),
                    style: text.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: week.completed / maxCount,
                      minHeight: 8,
                      backgroundColor: AppColors.surfaceHigh,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 24,
                  child: Text(
                    settings.digits('${week.completed}'),
                    textAlign: TextAlign.end,
                    style: text.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({required this.project, required this.settings});

  final ProjectReport project;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                project.title,
                style: text.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${settings.digits('${project.percent}')}٪',
              style: text.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: project.percent / 100,
            minHeight: 6,
            backgroundColor: AppColors.surfaceHigh,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${settings.digits('${project.completedTasks}')} از '
          '${settings.digits('${project.totalTasks}')} وظیفه'
          '${project.isActive ? ' • فعال' : ''}',
          style: text.labelSmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
