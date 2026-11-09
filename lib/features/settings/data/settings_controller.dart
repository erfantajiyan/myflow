import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/database_providers.dart';
import '../../../database/settings_repository_impl.dart';
import '../domain/app_settings.dart';

/// تنها مسیر دسترسی UI به repository تنظیمات.
final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>((Ref ref) {
      return DriftSettingsRepository(ref.watch(appDatabaseProvider));
    });

/// تنظیمات ذخیره‌شده‌ی کاربر.
final AsyncNotifierProvider<SettingsController, AppSettings> settingsProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
      SettingsController.new,
    );

/// مقدار قابل استفاده در ویجت‌هایی که نباید منتظر بارگذاری بمانند.
///
/// تا وقتی تنظیمات از دیتابیس خوانده نشده، پیش‌فرض‌های سند برمی‌گردند تا
/// فرم‌ها با مقدار خالی یا spinner ساخته نشوند.
final Provider<AppSettings> currentSettingsProvider = Provider<AppSettings>((
  Ref ref,
) {
  return ref.watch(settingsProvider).value ?? const AppSettings();
});

class SettingsController extends AsyncNotifier<AppSettings> {
  SettingsRepository get _repository => ref.read(settingsRepositoryProvider);

  @override
  Future<AppSettings> build() => _repository.load();

  Future<void> setTimeFormat(AppTimeFormat format) =>
      _update(state.value!.copyWith(timeFormat: format));

  Future<void> setDigitFormat(AppDigitFormat format) =>
      _update(state.value!.copyWith(digitFormat: format));

  Future<void> setDefaultEventDuration(int minutes) =>
      _update(state.value!.copyWith(defaultEventDurationMinutes: minutes));

  Future<void> setDefaultReminderMinutes(int? minutes) => _update(
    minutes == null
        ? state.value!.copyWith(clearDefaultReminder: true)
        : state.value!.copyWith(defaultReminderMinutes: minutes),
  );

  Future<void> setNotificationsEnabled(bool enabled) =>
      _update(state.value!.copyWith(notificationsEnabled: enabled));

  Future<void> reload() async {
    state = AsyncData<AppSettings>(await _repository.load());
  }

  Future<void> _update(AppSettings next) async {
    final AppSettings saved = await _repository.save(next);
    state = AsyncData<AppSettings>(saved);
  }
}
