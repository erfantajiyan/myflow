import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../date_time/jalali_date_service.dart';

/// سرویس تاریخ شمسی به‌صورت تزریق‌شده.
///
/// صفحه‌ها و ویجت‌ها فقط از این مسیر به تقویم دسترسی دارند تا در تست‌ها
/// بتوان نسخه‌ی جایگزین تزریق کرد (بخش ۱۲.۵ سند).
final Provider<JalaliDateService> jalaliDateServiceProvider =
    Provider<JalaliDateService>((Ref ref) => const JalaliDateService());

/// منبع زمان «اکنون».
///
/// در تست‌ها با یک مقدار ثابت override می‌شود تا خروجی صفحه‌ها قابل پیش‌بینی
/// باشد و منطق به ساعت واقعی دستگاه وابسته نشود.
final Provider<DateTime Function()> nowProvider =
    Provider<DateTime Function()>((Ref ref) => DateTime.now);
