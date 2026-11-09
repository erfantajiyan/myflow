import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myflow/app/app.dart';
import 'package:myflow/app/theme/app_colors.dart';
import 'package:myflow/core/providers/core_providers.dart';
import 'package:myflow/database/app_database.dart';
import 'package:myflow/database/database_providers.dart';
import 'package:myflow/features/calendar/presentation/calendar_page.dart';
import 'package:myflow/features/timeline/presentation/timeline_page.dart';

void main() {
  // ۱ فروردین ۱۴۰۴ — جمعه
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

  Finder navLabel(String label) => find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );

  testWidgets('اپ با پنج مقصد، تم تیره و جهت راست‌به‌چپ بالا می‌آید', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('MyFlow'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    for (final String label in <String>[
      'خانه',
      'تقویم',
      'وظایف',
      'پروژه‌ها',
      'گزارش‌ها',
    ]) {
      expect(navLabel(label), findsOneWidget, reason: 'مقصد $label');
    }

    // تاریخ شمسی واقعی امروز در سربرگ داشبورد
    expect(find.textContaining('۱ فروردین ۱۴۰۴'), findsOneWidget);
    expect(find.text('جمعه'), findsWidgets);

    final BuildContext context = tester.element(find.text('MyFlow'));
    expect(Directionality.of(context), TextDirection.rtl);

    final ThemeData theme = Theme.of(context);
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Vazirmatn');
  });

  testWidgets('ناوبری بین مقصدهای نوار پایین کار می‌کند', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(navLabel('وظایف'));
    await tester.pumpAndSettle();
    expect(find.text('هنوز وظیفه‌ای ثبت نشده'), findsOneWidget);

    await tester.tap(navLabel('تقویم'));
    await tester.pumpAndSettle();
    expect(find.byKey(calendarMonthModeKey), findsOneWidget);

    await tester.tap(navLabel('پروژه‌ها'));
    await tester.pumpAndSettle();
    expect(find.text('هنوز پروژه‌ای ساخته نشده'), findsOneWidget);

    await tester.tap(navLabel('گزارش‌ها'));
    await tester.pumpAndSettle();
    expect(find.text('داده‌ای برای این ماه نیست'), findsOneWidget);

    await tester.tap(navLabel('خانه'));
    await tester.pumpAndSettle();
    expect(find.text('برنامه‌ی امروز'), findsOneWidget);
  });

  testWidgets('تنظیمات از داشبورد باز می‌شود', (WidgetTester tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('تنظیمات'));
    await tester.pumpAndSettle();

    expect(find.text('قالب ساعت'), findsOneWidget);
    expect(find.text('یادآوری‌ها فعال باشند'), findsOneWidget);

    // صفحه‌ی تنظیمات بلند است؛ بخش تقویم با اسکرول دیده می‌شود.
    await tester.dragUntilVisible(
      find.text('شروع هفته'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    expect(find.text('شروع هفته'), findsOneWidget);
    expect(find.text('شنبه'), findsOneWidget);
  });

  testWidgets('افزودن سریع، BottomSheet و رفتن به وظایف را نشان می‌دهد', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('افزودن'));
    await tester.pumpAndSettle();
    expect(find.text('افزودن سریع'), findsOneWidget);

    await tester.tap(find.text('وظیفه‌ی جدید'));
    await tester.pumpAndSettle();
    expect(find.text('هنوز وظیفه‌ای ثبت نشده'), findsOneWidget);
  });

  testWidgets('«رویداد جدید» از افزودن سریع به صفحه‌ی رویدادها می‌رود', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('افزودن'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('رویداد جدید'));
    await tester.pumpAndSettle();

    // افزودن سریع، فرم رویداد را همان‌جا باز می‌کند.
    expect(find.text('ذخیره رویداد'), findsOneWidget);
  });

  testWidgets('تایم‌لاین از داشبورد باز می‌شود', (WidgetTester tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('تایم‌لاین'));
    await tester.pumpAndSettle();

    expect(find.byKey(timelineAxisKey), findsOneWidget);
  });
}
