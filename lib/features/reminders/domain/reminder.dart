import '../../../database/row_id.dart';

/// یک ردیف یادآوری — جدول `reminders` (بخش ۱۰.۸ سند).
///
/// هر یادآوری دقیقاً یک والد دارد: یا رویداد یا وظیفه. برای رویداد تکراری،
/// یادآوری روی ردیف master می‌نشیند و زمان هر نمونه هنگام زمان‌بندی حساب
/// می‌شود (بخش ۱۱.۹ سند).
class Reminder {
  const Reminder({
    required this.id,
    required this.remindAtUtc,
    required this.isEnabled,
    this.eventId,
    this.taskId,
    this.minutesBefore,
    this.notificationId,
  });

  final String id;
  final String? eventId;
  final String? taskId;

  /// زمان پایه‌ی یادآوری؛ برای رویداد تکراری فقط مقدار نمایشی است.
  final DateTime remindAtUtc;

  /// فاصله‌ی یادآوری پیش از شروع (دقیقه).
  final int? minutesBefore;

  final bool isEnabled;

  /// شناسه‌ی اعلان سیستم‌عامل؛ فقط برای رویداد/وظیفه‌ی غیرتکراری معنا دارد.
  final int? notificationId;

  bool get isForEvent => eventId != null;

  /// فاصله‌ی مؤثر؛ `null` یعنی «در لحظه‌ی شروع».
  int get effectiveMinutesBefore => minutesBefore ?? 0;

  String get parentId => eventId ?? taskId!;

  Reminder copyWith({DateTime? remindAtUtc, int? minutesBefore, bool? isEnabled}) {
    return Reminder(
      id: id,
      eventId: eventId,
      taskId: taskId,
      remindAtUtc: remindAtUtc ?? this.remindAtUtc,
      minutesBefore: minutesBefore ?? this.minutesBefore,
      isEnabled: isEnabled ?? this.isEnabled,
      notificationId: notificationId,
    );
  }
}

/// گزینه‌های یادآوری در فرم‌ها (دقیقه پیش از شروع).
class ReminderOffset {
  const ReminderOffset(this.minutes, this.label);

  final int minutes;
  final String label;

  static const List<ReminderOffset> options = <ReminderOffset>[
    ReminderOffset(0, 'در لحظه‌ی شروع'),
    ReminderOffset(5, '۵ دقیقه قبل'),
    ReminderOffset(10, '۱۰ دقیقه قبل'),
    ReminderOffset(15, '۱۵ دقیقه قبل'),
    ReminderOffset(30, '۳۰ دقیقه قبل'),
    ReminderOffset(60, '۱ ساعت قبل'),
    ReminderOffset(24 * 60, '۱ روز قبل'),
  ];

  static String labelFor(int minutes) {
    for (final ReminderOffset option in options) {
      if (option.minutes == minutes) {
        return option.label;
      }
    }
    return '$minutes دقیقه قبل';
  }
}

/// محدوده‌ی مجاز فاصله‌ی یادآوری: از ۰ تا یک هفته پیش از رویداد.
const int maxReminderOffsetMinutes = 7 * 24 * 60;

/// اعتبارسنجی فاصله؛ مقدار منفی یا بزرگ‌تر از یک هفته رد می‌شود.
int validateReminderOffset(int minutes) {
  if (minutes < 0 || minutes > maxReminderOffsetMinutes) {
    throw ReminderValidationException(
      'فاصله‌ی یادآوری باید بین ۰ تا $maxReminderOffsetMinutes دقیقه باشد.',
    );
  }
  return minutes;
}

sealed class ReminderRepositoryException implements Exception {
  const ReminderRepositoryException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

final class ReminderValidationException extends ReminderRepositoryException {
  const ReminderValidationException(super.message);
}

/// شناسه‌ی یکتای ردیف یادآوری جدید.
String newReminderId() => newRowId('rem');
