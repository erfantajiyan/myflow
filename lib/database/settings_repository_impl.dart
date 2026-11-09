import '../features/settings/domain/app_settings.dart';
import 'app_database.dart';
import 'tables/settings.dart';

/// خطاهای لایه‌ی تنظیمات.
sealed class SettingsRepositoryException implements Exception {
  const SettingsRepositoryException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

final class SettingsValidationException extends SettingsRepositoryException {
  const SettingsValidationException(super.message);
}

/// تنها مسیر خواندن و نوشتن تنظیمات (بخش ۱۰.۱۱ سند).
abstract class SettingsRepository {
  /// تنظیمات ذخیره‌شده؛ کلیدهای ناموجود با پیش‌فرض پر می‌شوند.
  Future<AppSettings> load();

  /// ذخیره‌ی کامل تنظیمات و برگرداندن حالت نهایی.
  Future<AppSettings> save(AppSettings settings);

  /// یک مقدار خام؛ برای کلیدهای آینده.
  Future<String?> getValue(String key);
}

/// محدوده‌های مجاز — مقادیر خارج از این بازه در دیتابیس ذخیره نمی‌شوند تا
/// فرم‌ها و زمان‌بندی اعلان با عدد بی‌معنا روبه‌رو نشوند.
const int minDefaultEventDuration = 5;
const int maxDefaultEventDuration = 12 * 60;
const int minReminderMinutes = 0;
const int maxReminderMinutes = 7 * 24 * 60;

class DriftSettingsRepository implements SettingsRepository {
  DriftSettingsRepository(this._db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  @override
  Future<AppSettings> load() async {
    final List<SettingRow> rows = await _db.select(_db.settings).get();
    return AppSettings.fromValues(<String, String>{
      for (final SettingRow row in rows) row.key: row.value,
    });
  }

  @override
  Future<AppSettings> save(AppSettings settings) async {
    _validate(settings);
    final Map<String, String> values = settings.toValues();
    await _db.transaction(() async {
      // کلید یادآوری وقتی خالی است باید حذف شود، وگرنه مقدار قبلی می‌ماند.
      await (_db.delete(_db.settings)
            ..where((Settings t) => t.key.equals(SettingsKeys.defaultReminderMinutes)))
          .go();
      for (final MapEntry<String, String> entry in values.entries) {
        await _db
            .into(_db.settings)
            .insertOnConflictUpdate(
              SettingsCompanion.insert(
                key: entry.key,
                value: entry.value,
                updatedAt: _now().toUtc(),
              ),
            );
      }
    });
    return settings;
  }

  @override
  Future<String?> getValue(String key) async {
    final SettingRow? row = await (_db.select(
      _db.settings,
    )..where((Settings t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  void _validate(AppSettings settings) {
    final int duration = settings.defaultEventDurationMinutes;
    if (duration < minDefaultEventDuration ||
        duration > maxDefaultEventDuration) {
      throw SettingsValidationException(
        'مدت پیش‌فرض رویداد باید بین $minDefaultEventDuration و '
        '$maxDefaultEventDuration دقیقه باشد.',
      );
    }
    final int? reminder = settings.defaultReminderMinutes;
    if (reminder != null &&
        (reminder < minReminderMinutes || reminder > maxReminderMinutes)) {
      throw SettingsValidationException(
        'یادآوری پیش‌فرض باید بین $minReminderMinutes و '
        '$maxReminderMinutes دقیقه باشد.',
      );
    }
  }
}
