import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myflow/database/app_database.dart';
import 'package:myflow/database/settings_repository_impl.dart';
import 'package:myflow/features/settings/domain/app_settings.dart';

void main() {
  late AppDatabase db;
  late DriftSettingsRepository settings;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    settings = DriftSettingsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('با دیتابیس خالی، پیش‌فرض‌های سند برمی‌گردد', () async {
    final AppSettings loaded = await settings.load();

    expect(loaded.timeFormat, AppTimeFormat.h24);
    expect(loaded.digitFormat, AppDigitFormat.persian);
    expect(loaded.defaultEventDurationMinutes, 60);
    expect(loaded.defaultReminderMinutes, isNull);
    expect(loaded.notificationsEnabled, isTrue);
  });

  test('ذخیره و خواندن همه‌ی تنظیمات', () async {
    await settings.save(
      const AppSettings(
        timeFormat: AppTimeFormat.h12,
        digitFormat: AppDigitFormat.latin,
        defaultEventDurationMinutes: 90,
        defaultReminderMinutes: 15,
        notificationsEnabled: false,
      ),
    );

    final AppSettings loaded = await settings.load();
    expect(loaded.timeFormat, AppTimeFormat.h12);
    expect(loaded.digitFormat, AppDigitFormat.latin);
    expect(loaded.defaultEventDurationMinutes, 90);
    expect(loaded.defaultReminderMinutes, 15);
    expect(loaded.notificationsEnabled, isFalse);
  });

  test('حذف یادآوری پیش‌فرض مقدار قبلی را پاک می‌کند', () async {
    await settings.save(const AppSettings(defaultReminderMinutes: 30));
    await settings.save(const AppSettings());

    expect(await settings.load(), isA<AppSettings>());
    expect((await settings.load()).defaultReminderMinutes, isNull);
    expect(await settings.getValue(SettingsKeys.defaultReminderMinutes), isNull);
  });

  test('مقدار نامعتبر ذخیره نمی‌شود', () async {
    expect(
      () => settings.save(const AppSettings(defaultEventDurationMinutes: 1)),
      throwsA(isA<SettingsValidationException>()),
    );
    expect(
      () => settings.save(const AppSettings(defaultReminderMinutes: -5)),
      throwsA(isA<SettingsValidationException>()),
    );
  });

  test('قالب ساعت ۱۲ ساعته با پسوند درست نمایش داده می‌شود', () {
    const AppSettings twelve = AppSettings(timeFormat: AppTimeFormat.h12);
    expect(twelve.formatTime(DateTime(2026, 11, 9, 13, 5)), '۰۱:۰۵ ب.ظ');
    expect(twelve.formatTime(DateTime(2026, 11, 9, 0, 30)), '۱۲:۳۰ ق.ظ');

    const AppSettings twentyFour = AppSettings();
    expect(twentyFour.formatTime(DateTime(2026, 11, 9, 13, 5)), '۱۳:۰۵');
    expect(
      const AppSettings(digitFormat: AppDigitFormat.latin).formatTime(
        DateTime(2026, 11, 9, 9, 7),
      ),
      '09:07',
    );
  });
}
