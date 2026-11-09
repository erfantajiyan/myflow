import '../../../shared/enums/app_enums.dart';

/// یک نمونه‌ی محاسبه‌شده از سری تکراری (بخش ۱۱.۸ سند).
///
/// [id] نمایشی است (`{masterEventId}@{instanceKey}`) و هرگز در دیتابیس
/// ذخیره نمی‌شود؛ [sourceEventId] فقط وقتی پر است که این نمونه از یک ردیف
/// استثنا آمده باشد.
class EventOccurrence {
  const EventOccurrence({
    required this.masterEventId,
    required this.instanceKey,
    required this.startAtUtc,
    required this.endAtUtc,
    required this.status,
    this.isException = false,
    this.sourceEventId,
  });

  final String masterEventId;

  /// تاریخ محلی نمونه با قالب `YYYY-MM-DD` (کلید یکتای نمونه در سری).
  final String instanceKey;

  final DateTime startAtUtc;
  final DateTime endAtUtc;
  final EventStatus status;

  /// آیا این نمونه در دیتابیس ردیف استثنا دارد؟
  final bool isException;

  /// شناسه‌ی ردیف استثنا (اگر وجود داشته باشد).
  final String? sourceEventId;

  /// شناسه‌ی نمایشی که UI و مسیرها استفاده می‌کنند.
  String get id => '$masterEventId@$instanceKey';

  DateTime get startLocal => startAtUtc.toLocal();

  DateTime get endLocal => endAtUtc.toLocal();

  bool get isCancelled => status == EventStatus.cancelled;

  bool overlapsWindow(DateTime rangeStartUtc, DateTime rangeEndUtc) =>
      startAtUtc.isBefore(rangeEndUtc) && endAtUtc.isAfter(rangeStartUtc);
}
