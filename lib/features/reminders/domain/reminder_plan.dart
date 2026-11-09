/// پنجره‌ی لغزان زمان‌بندی اعلان — بخش ۱۱.۹ سند.
///
/// اعلان‌های سیستم‌عامل فقط برای نمونه‌های آینده‌ی این بازه زمان‌بندی
/// می‌شوند و در شروع برنامه یا پس از هر تغییر داده بازسازی می‌گردند.
const Duration reminderWindow = Duration(days: 14);

/// سقف تعداد اعلان هم‌زمان؛ iOS حدود ۶۴ اعلان معلق می‌پذیرد.
const int maxScheduledNotifications = 60;

/// یک نمونه‌ی آینده که باید برایش یادآوری زمان‌بندی شود.
class ReminderOccurrence {
  const ReminderOccurrence({
    required this.instanceKey,
    required this.startLocal,
  });

  /// کلید پایدار نمونه؛ برای رویداد غیرتکراری شناسه‌ی خود رویداد کافی است.
  final String instanceKey;

  /// شروع نمونه به وقت محلی.
  final DateTime startLocal;
}

/// یک یادآوری به‌همراه نمونه‌های آینده‌ی والدش.
class ReminderTarget {
  const ReminderTarget({
    required this.reminderId,
    required this.parentId,
    required this.title,
    required this.body,
    required this.minutesBefore,
    required this.occurrences,
  });

  final String reminderId;
  final String parentId;
  final String title;
  final String body;

  /// دقیقه پیش از شروع؛ برای رویداد تمام‌روز از ساعت ۹ صبح همان روز.
  final int minutesBefore;

  final List<ReminderOccurrence> occurrences;
}

/// یک اعلان آماده‌ی ثبت در سیستم‌عامل.
class PlannedReminder {
  const PlannedReminder({
    required this.notificationId,
    required this.reminderId,
    required this.instanceKey,
    required this.whenUtc,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int notificationId;
  final String reminderId;
  final String instanceKey;
  final DateTime whenUtc;
  final String title;
  final String body;
  final String payload;

  DateTime get whenLocal => whenUtc.toLocal();
}

/// شناسه‌ی قطعی اعلان از شناسه‌ی یادآوری و کلید نمونه — بخش ۱۱.۹.
///
/// مشتق‌شدن از داده (نه شمارنده‌ی ترتیبی) باعث می‌شود لغو و بازتنظیم دقیقاً
/// همان اعلان قبلی را هدف بگیرد. خروجی همیشه در بازه‌ی معتبر Android است
/// (۳۱ بیت و بزرگ‌تر از صفر).
int notificationIdFor(String reminderId, String instanceKey) {
  // FNV-1a 32-bit روی رشته، سپس ماسک ۳۱ بیت.
  int hash = 0x811C9DC5;
  for (final int codeUnit in '$reminderId@$instanceKey'.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  final int id = hash & 0x7FFFFFFF;
  return id == 0 ? 1 : id;
}

/// ساخت برنامه‌ی اعلان‌ها از یادآوری‌های فعال.
///
/// قواعد:
/// - لحظه‌های گذشته یا مساوی [now] نادیده گرفته می‌شوند (اعلان عقب‌افتاده
///   نباید دوباره ثبت شود).
/// - فقط لحظه‌های داخل [window] از [now] ثبت می‌شوند.
/// - هر شناسه‌ی اعلان فقط یک بار برمی‌گردد تا لغو/بازتنظیم دقیق بماند.
/// - خروجی مرتب بر اساس زمان و حداکثر [maxNotifications] مورد.
List<PlannedReminder> buildReminderPlan({
  required List<ReminderTarget> targets,
  required DateTime now,
  Duration window = reminderWindow,
  int maxNotifications = maxScheduledNotifications,
}) {
  final DateTime windowEnd = now.add(window);
  final Map<int, PlannedReminder> byId = <int, PlannedReminder>{};

  for (final ReminderTarget target in targets) {
    for (final ReminderOccurrence occurrence in target.occurrences) {
      final DateTime remindAt = occurrence.startLocal.subtract(
        Duration(minutes: target.minutesBefore),
      );
      if (!remindAt.isAfter(now) || remindAt.isAfter(windowEnd)) {
        continue;
      }
      final int id = notificationIdFor(
        target.reminderId,
        occurrence.instanceKey,
      );
      byId.putIfAbsent(
        id,
        () => PlannedReminder(
          notificationId: id,
          reminderId: target.reminderId,
          instanceKey: occurrence.instanceKey,
          whenUtc: remindAt.toUtc(),
          title: target.title,
          body: target.body,
          payload: '${target.parentId}|${occurrence.instanceKey}',
        ),
      );
    }
  }

  final List<PlannedReminder> plan = byId.values.toList()
    ..sort(
      (PlannedReminder a, PlannedReminder b) => a.whenUtc.compareTo(b.whenUtc),
    );
  if (plan.length <= maxNotifications) {
    return plan;
  }
  return plan.sublist(0, maxNotifications);
}
