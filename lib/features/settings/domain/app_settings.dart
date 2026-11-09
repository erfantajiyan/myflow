import '../../../core/utils/persian_digits.dart';

/// قالب ساعت نمایشی — بخش ۷.۸ سند.
enum AppTimeFormat {
  h24('۲۴ ساعته'),
  h12('۱۲ ساعته');

  const AppTimeFormat(this.label);

  final String label;

  String get storageValue => name;

  static AppTimeFormat fromStorage(String? value) {
    return AppTimeFormat.values.firstWhere(
      (AppTimeFormat format) => format.name == value,
      orElse: () => AppTimeFormat.h24,
    );
  }
}

/// قالب ارقام نمایشی — بخش ۷.۸ سند.
///
/// فقط لایه‌ی نمایش تغییر می‌کند؛ هر مقداری که ذخیره یا مقایسه می‌شود لاتین
/// می‌ماند (بخش ۲۰.۴ سند).
enum AppDigitFormat {
  persian('فارسی'),
  latin('لاتین');

  const AppDigitFormat(this.label);

  final String label;

  String get storageValue => name;

  static AppDigitFormat fromStorage(String? value) {
    return AppDigitFormat.values.firstWhere(
      (AppDigitFormat format) => format.name == value,
      orElse: () => AppDigitFormat.persian,
    );
  }
}

/// کلیدهای جدول `settings` (بخش ۱۰.۱۱ سند).
abstract final class SettingsKeys {
  static const String timeFormat = 'time_format';
  static const String digitFormat = 'digit_format';
  static const String defaultEventDuration = 'default_event_duration';
  static const String defaultReminderMinutes = 'default_reminder_minutes';
  static const String notificationsEnabled = 'notifications_enabled';
}

/// تنظیمات کاربر با مقادیر پیش‌فرض مطابق سند.
class AppSettings {
  const AppSettings({
    this.timeFormat = AppTimeFormat.h24,
    this.digitFormat = AppDigitFormat.persian,
    this.defaultEventDurationMinutes = 60,
    this.defaultReminderMinutes,
    this.notificationsEnabled = true,
  });

  final AppTimeFormat timeFormat;
  final AppDigitFormat digitFormat;

  /// مدت پیش‌فرض رویداد جدید به دقیقه.
  final int defaultEventDurationMinutes;

  /// یادآوری پیش‌فرض پیش از رویداد؛ `null` یعنی بدون یادآوری.
  final int? defaultReminderMinutes;

  final bool notificationsEnabled;

  bool get usePersianDigits => digitFormat == AppDigitFormat.persian;

  /// ساعت را با قالب انتخاب‌شده و ارقام دلخواه برمی‌گرداند.
  ///
  /// پایه‌ی محاسبه همیشه ساعت محلی است (بخش ۱۲.۱ سند).
  String formatTime(DateTime dateTime) {
    final int hour = timeFormat == AppTimeFormat.h12
        ? _to12Hour(dateTime.hour)
        : dateTime.hour;
    final String base =
        '${hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
    final String withSuffix = timeFormat == AppTimeFormat.h12
        ? '$base ${dateTime.hour < 12 ? 'ق.ظ' : 'ب.ظ'}'
        : base;
    return digits(withSuffix);
  }

  /// ارقام یک رشته را مطابق تنظیم کاربر تبدیل می‌کند.
  String digits(String value) =>
      usePersianDigits ? PersianDigits.convert(value) : value;

  AppSettings copyWith({
    AppTimeFormat? timeFormat,
    AppDigitFormat? digitFormat,
    int? defaultEventDurationMinutes,
    int? defaultReminderMinutes,
    bool clearDefaultReminder = false,
    bool? notificationsEnabled,
  }) {
    return AppSettings(
      timeFormat: timeFormat ?? this.timeFormat,
      digitFormat: digitFormat ?? this.digitFormat,
      defaultEventDurationMinutes:
          defaultEventDurationMinutes ?? this.defaultEventDurationMinutes,
      defaultReminderMinutes: clearDefaultReminder
          ? null
          : (defaultReminderMinutes ?? this.defaultReminderMinutes),
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }

  /// ساخت تنظیمات از مقدارهای خام جدول `settings`.
  factory AppSettings.fromValues(Map<String, String> values) {
    final String? durationRaw = values[SettingsKeys.defaultEventDuration];
    final String? reminderRaw = values[SettingsKeys.defaultReminderMinutes];
    final int? duration = int.tryParse(durationRaw ?? '');
    final int? reminder = int.tryParse(reminderRaw ?? '');
    return AppSettings(
      timeFormat: AppTimeFormat.fromStorage(values[SettingsKeys.timeFormat]),
      digitFormat: AppDigitFormat.fromStorage(
        values[SettingsKeys.digitFormat],
      ),
      defaultEventDurationMinutes: duration ?? 60,
      defaultReminderMinutes: reminder,
      notificationsEnabled:
          (values[SettingsKeys.notificationsEnabled] ?? 'true') != 'false',
    );
  }

  /// مقدارهای قابل نوشتن در جدول `settings`.
  Map<String, String> toValues() {
    return <String, String>{
      SettingsKeys.timeFormat: timeFormat.storageValue,
      SettingsKeys.digitFormat: digitFormat.storageValue,
      SettingsKeys.defaultEventDuration: '$defaultEventDurationMinutes',
      if (defaultReminderMinutes != null)
        SettingsKeys.defaultReminderMinutes: '$defaultReminderMinutes',
      SettingsKeys.notificationsEnabled: notificationsEnabled ? 'true' : 'false',
    };
  }

  static int _to12Hour(int hour) {
    final int value = hour % 12;
    return value == 0 ? 12 : value;
  }
}
