import '../domain/reminder_plan.dart';

/// درگاه اعلان سیستم‌عامل.
///
/// کل زمان‌بندی در لایه‌ی دامنه محاسبه می‌شود و این اینترفیس فقط آن را به
/// سیستم‌عامل می‌سپارد؛ در تست‌ها و روی پلتفرم‌های بدون پشتیبانی، نسخه‌ی
/// no-op استفاده می‌شود تا منطق قابل آزمون بماند.
abstract class NotificationGateway {
  Future<void> initialize();

  /// درخواست مجوز؛ `true` یعنی مجوز داده شده است.
  Future<bool> requestPermission();

  /// لغو همه‌ی اعلان‌های معلق این برنامه.
  ///
  /// کل پنجره در هر بازسازی از نو ساخته می‌شود، پس اعلان‌های حذف‌شده هم
  /// همین‌جا پاک می‌شوند (معیار اتمام فاز ۱۰: اعلان باقی‌مانده نداشته باشیم).
  Future<void> cancelAll();

  Future<void> scheduleAll(List<PlannedReminder> reminders);
}

/// نسخه‌ی خالی برای وب، دسکتاپ و تست‌ها.
class NoopNotificationGateway implements NotificationGateway {
  NoopNotificationGateway();

  int cancelAllCalls = 0;
  List<PlannedReminder> lastScheduled = const <PlannedReminder>[];

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
  }

  @override
  Future<void> scheduleAll(List<PlannedReminder> reminders) async {
    lastScheduled = reminders;
  }
}
