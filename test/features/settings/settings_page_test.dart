import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myflow/app/app.dart';
import 'package:myflow/core/providers/core_providers.dart';
import 'package:myflow/database/app_database.dart';
import 'package:myflow/database/database_providers.dart';
import 'package:myflow/database/settings_repository_impl.dart';
import 'package:myflow/features/settings/data/settings_controller.dart';
import 'package:myflow/features/settings/domain/app_settings.dart';
import 'package:myflow/features/settings/presentation/settings_page.dart';

void main() {
  final DateTime fixedNow = DateTime(2025, 3, 21, 9, 30);

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        nowProvider.overrideWithValue(() => fixedNow),
        appDatabaseProvider.overrideWith((Ref ref) => db),
      ],
      child: const MyFlowApp(),
    );
  }

  Future<ProviderContainer> openSettings(WidgetTester tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('تنظیمات'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    return ProviderScope.containerOf(
      tester.element(find.byType(SettingsPage)),
    );
  }

  testWidgets('تغییر قالب ساعت و ارقام ذخیره می‌شود', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await openSettings(tester);

    await tester.tap(find.text('۱۲ ساعته'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('لاتین'));
    await tester.pumpAndSettle();

    final AppSettings settings = container.read(settingsProvider).value!;
    expect(settings.timeFormat, AppTimeFormat.h12);
    expect(settings.digitFormat, AppDigitFormat.latin);

    final AppSettings stored = await container
        .read(settingsRepositoryProvider)
        .load();
    expect(stored.timeFormat, AppTimeFormat.h12);
    expect(stored.digitFormat, AppDigitFormat.latin);
  });

  testWidgets('خاموش‌کردن اعلان‌ها در دیتابیس می‌ماند', (
    WidgetTester tester,
  ) async {
    await openSettings(tester);

    await tester.tap(find.byKey(settingsNotificationsKey));
    await tester.pumpAndSettle();

    final AppSettings stored = await DriftSettingsRepository(db).load();
    expect(stored.notificationsEnabled, isFalse);
  });

  testWidgets('یادآوری پیش‌فرض قابل انتخاب است', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = await openSettings(tester);

    await tester.tap(find.byKey(settingsDefaultReminderKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('۱۵ دقیقه قبل').last);
    await tester.pumpAndSettle();

    final AppSettings stored = await DriftSettingsRepository(db).load();
    expect(stored.defaultReminderMinutes, 15);
    expect(container.read(settingsProvider).value!.defaultReminderMinutes, 15);
  });
}
