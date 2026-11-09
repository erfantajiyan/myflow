import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../reminders/data/reminder_sync_service.dart';
import '../../reminders/domain/reminder.dart';
import '../data/settings_controller.dart';
import '../domain/app_settings.dart';

const Key settingsNotificationsKey = Key('settings-notifications');
const Key settingsDefaultReminderKey = Key('settings-default-reminder');
const Key settingsDefaultDurationKey = Key('settings-default-duration');

/// تنظیمات — بخش ۷.۸ سند.
///
/// همه‌ی گزینه‌ها در جدول `settings` ذخیره می‌شوند و بلافاصله روی نمایش
/// ساعت/اعداد و مقادیر پیش‌فرض فرم‌ها اثر می‌گذارند.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _isSyncing = false;
  String? _syncMessage;

  static const List<int> _durationOptions = <int>[30, 45, 60, 90, 120];

  Future<void> _syncReminders() async {
    setState(() {
      _isSyncing = true;
      _syncMessage = null;
    });
    try {
      final ReminderSyncResult result = await ref
          .read(reminderSyncProvider)
          .sync();
      if (!mounted) {
        return;
      }
      setState(() {
        _syncMessage = result.disabled
            ? 'اعلان‌ها خاموش هستند؛ چیزی زمان‌بندی نشد.'
            : result.permissionDenied
            ? 'اجازه‌ی نمایش اعلان داده نشده است.'
            : '${result.scheduledCount} یادآوری زمان‌بندی شد.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _syncMessage = 'زمان‌بندی اعلان‌ها انجام نشد.');
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AppSettings> async = ref.watch(settingsProvider);
    final AppSettings settings = async.value ?? const AppSettings();
    final SettingsController controller = ref.read(
      settingsProvider.notifier,
    );

    return AppPageScaffold(
      title: 'تنظیمات',
      subtitle: 'ظاهر، زمان و اعلان‌ها',
      actions: <Widget>[
        IconButton(
          tooltip: 'بازگشت',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
      ],
      child: async.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: <Widget>[
                const AppSectionHeader(title: 'عمومی'),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _ChoiceRow<AppTimeFormat>(
                        label: 'قالب ساعت',
                        values: AppTimeFormat.values,
                        selected: settings.timeFormat,
                        labelOf: (AppTimeFormat value) => value.label,
                        onChanged: controller.setTimeFormat,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _ChoiceRow<AppDigitFormat>(
                        label: 'ارقام',
                        values: AppDigitFormat.values,
                        selected: settings.digitFormat,
                        labelOf: (AppDigitFormat value) => value.label,
                        onChanged: controller.setDigitFormat,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<int>(
                        key: settingsDefaultDurationKey,
                        initialValue: settings.defaultEventDurationMinutes,
                        decoration: const InputDecoration(
                          labelText: 'مدت پیش‌فرض رویداد',
                        ),
                        items: <DropdownMenuItem<int>>[
                          for (final int minutes in _durationOptions)
                            DropdownMenuItem<int>(
                              value: minutes,
                              child: Text(
                                '${settings.digits('$minutes')} دقیقه',
                              ),
                            ),
                        ],
                        onChanged: (int? value) {
                          if (value != null) {
                            controller.setDefaultEventDuration(value);
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      const _Hint(
                        'این مدت هنگام ساخت رویداد جدید پیش‌پر می‌شود.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sectionGap),
                const AppSectionHeader(title: 'اعلان‌ها'),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SwitchListTile.adaptive(
                        key: settingsNotificationsKey,
                        contentPadding: EdgeInsets.zero,
                        value: settings.notificationsEnabled,
                        title: const Text('یادآوری‌ها فعال باشند'),
                        subtitle: const Text(
                          'اعلان محلی برای رویدادها و وظایف دارای یادآوری',
                        ),
                        onChanged: controller.setNotificationsEnabled,
                      ),
                      const Divider(height: AppSpacing.lg),
                      DropdownButtonFormField<int?>(
                        key: settingsDefaultReminderKey,
                        initialValue: settings.defaultReminderMinutes,
                        decoration: const InputDecoration(
                          labelText: 'یادآوری پیش‌فرض',
                        ),
                        items: <DropdownMenuItem<int?>>[
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('بدون یادآوری'),
                          ),
                          for (final ReminderOffset option
                              in ReminderOffset.options)
                            DropdownMenuItem<int?>(
                              value: option.minutes,
                              child: Text(option.label),
                            ),
                        ],
                        onChanged: controller.setDefaultReminderMinutes,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton.icon(
                        onPressed: _isSyncing ? null : _syncReminders,
                        icon: _isSyncing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded),
                        label: const Text('بازسازی زمان‌بندی اعلان‌ها'),
                      ),
                      if (_syncMessage != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _syncMessage!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                      const _Hint(
                        'اعلان‌ها برای نمونه‌های ۱۴ روز آینده زمان‌بندی '
                        'می‌شوند و با هر تغییر داده بازسازی می‌گردند.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sectionGap),
                const AppSectionHeader(title: 'تقویم'),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: const <Widget>[
                      _SettingRow(
                        icon: Icons.calendar_today_rounded,
                        label: 'شروع هفته',
                        value: 'شنبه',
                      ),
                      Divider(height: 1),
                      _SettingRow(
                        icon: Icons.dark_mode_outlined,
                        label: 'تم',
                        value: 'تیره',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sectionGap),
                Text(
                  'MyFlow — نسخه‌ی 1.0.0\n'
                  'داده‌ها فقط روی همین دستگاه ذخیره می‌شوند.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
    );
  }
}

class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
  });

  final String label;
  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        SegmentedButton<T>(
          segments: <ButtonSegment<T>>[
            for (final T value in values)
              ButtonSegment<T>(value: value, label: Text(labelOf(value))),
          ],
          selected: <T>{selected},
          onSelectionChanged: (Set<T> selection) =>
              onChanged(selection.first),
        ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
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
