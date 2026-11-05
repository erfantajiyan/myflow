import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../../core/widgets/app_section_header.dart';

/// تنظیمات — بخش ۷.۸ سند.
///
/// در این فاز فقط مقادیر پیش‌فرض ثابت نمایش داده می‌شوند؛ ذخیره‌سازی و
/// تغییر تنظیمات پس از آماده شدن جدول `settings` فعال می‌شود.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'تنظیمات',
      subtitle: 'ظاهر، تاریخ و داده‌ها',
      actions: <Widget>[
        IconButton(
          tooltip: 'بازگشت',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
      ],
      child: ListView(
        children: <Widget>[
          const AppSectionHeader(title: 'عمومی'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: const <Widget>[
                _SettingRow(
                  icon: Icons.dark_mode_outlined,
                  label: 'تم',
                  value: 'تیره (ثابت در MVP)',
                ),
                Divider(height: 1),
                _SettingRow(
                  icon: Icons.access_time_rounded,
                  label: 'قالب ساعت',
                  value: '۲۴ ساعته',
                ),
                Divider(height: 1),
                _SettingRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'شروع هفته',
                  value: 'شنبه',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const AppSectionHeader(title: 'داده‌ها'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: const <Widget>[
                _SettingRow(
                  icon: Icons.backup_outlined,
                  label: 'پشتیبان‌گیری',
                  value: 'در فاز بکاپ فعال می‌شود',
                ),
                Divider(height: 1),
                _SettingRow(
                  icon: Icons.notifications_none_rounded,
                  label: 'یادآوری‌ها',
                  value: 'در فاز اعلان فعال می‌شود',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          Text(
            'MyFlow — فاز ۱: Design System و پایه‌ی فنی\n'
            'نسخه‌ی 1.0.0',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
