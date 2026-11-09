import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/data_revision_provider.dart';
import '../features/reminders/data/reminder_sync_service.dart';
import '../features/settings/data/settings_controller.dart';
import '../features/settings/domain/app_settings.dart';
import 'router.dart';
import 'theme/app_theme.dart';

/// ریشه‌ی برنامه: تم تیره، زبان فارسی و چیدمان راست‌به‌چپ.
///
/// جهت RTL از لوکال `fa` می‌آید (فلتر GlobalWidgetsLocalizations)، بنابراین
/// همه‌ی صفحات و اجزای Material به‌صورت یکدست راست‌به‌چپ می‌شوند.
class MyFlowApp extends ConsumerStatefulWidget {
  const MyFlowApp({super.key});

  @override
  ConsumerState<MyFlowApp> createState() => _MyFlowAppState();
}

class _MyFlowAppState extends ConsumerState<MyFlowApp> {
  @override
  void initState() {
    super.initState();
    // پنجره‌ی لغزان اعلان‌ها در شروع برنامه بازسازی می‌شود (بخش ۱۱.۹).
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncReminders());
  }

  /// بازسازی اعلان‌ها؛ خطای آن نباید رابط کاربری را بشکند.
  Future<void> _syncReminders() async {
    try {
      await ref.read(reminderSyncProvider).sync();
    } catch (_) {
      // در نبود مجوز یا پلتفرم بدون پشتیبانی، اعلان فقط زمان‌بندی نمی‌شود.
    }
  }

  @override
  Widget build(BuildContext context) {
    // هر تغییر داده (ساخت/ویرایش/حذف رویداد و وظیفه) یا تغییر تنظیمات،
    // پنجره‌ی اعلان‌ها را از نو می‌سازد تا اعلان کهنه باقی نماند (فاز ۱۰).
    ref.listen<int>(dataRevisionProvider, (int? previous, int next) {
      _syncReminders();
    });
    ref.listen<AsyncValue<AppSettings>>(settingsProvider, (
      AsyncValue<AppSettings>? previous,
      AsyncValue<AppSettings> next,
    ) {
      if (next.hasValue && previous?.value != next.value) {
        _syncReminders();
      }
    });

    return MaterialApp.router(
      title: 'MyFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: ref.watch(appRouterProvider),
      locale: const Locale('fa'),
      supportedLocales: const <Locale>[Locale('fa')],
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
