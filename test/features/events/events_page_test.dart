import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myflow/app/app.dart';
import 'package:myflow/app/router.dart';
import 'package:myflow/database/app_database.dart';
import 'package:myflow/database/database_providers.dart';
import 'package:myflow/features/events/presentation/event_editor_sheet.dart';

void main() {
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
        appDatabaseProvider.overrideWith((Ref ref) => db),
      ],
      child: const MyFlowApp(),
    );
  }

  Finder fieldOf(Key key) => find
      .descendant(of: find.byKey(key), matching: find.byType(TextFormField))
      .first;

  Future<void> openEventsPage(WidgetTester tester) async {
    // فرم رویداد بلند است؛ با ارتفاع پیش‌فرض ۶۰۰ پیکسل دکمه‌ی ذخیره بیرون از
    // ویوپورت می‌ماند و tap روی آن ناممکن می‌شود.
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // دکمه‌ی «افزودن رویداد» داشبورد حالا فرم را در همان صفحه باز می‌کند،
    // پس این تست مستقیم به مسیر فهرست رویدادها می‌رود.
    final BuildContext context = tester.element(find.byType(MyFlowApp));
    ProviderScope.containerOf(context).read(appRouterProvider).go('/events');
    await tester.pumpAndSettle();
  }

  Future<void> saveSheet(WidgetTester tester) async {
    await tester.ensureVisible(find.text('ذخیره رویداد'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ذخیره رویداد'));
    await tester.pumpAndSettle();
  }

  /// اگر فرم باز بماند یعنی ذخیره رد شده؛ وگرنه متن داخل فیلدها می‌تواند
  /// ادعای «در فهرست ظاهر شد» را دروغین سبز کند.
  void expectSheetClosed() {
    expect(find.text('ذخیره رویداد'), findsNothing);
  }

  Future<void> createEvent(
    WidgetTester tester, {
    required String title,
    String? start,
    String? end,
  }) async {
    await tester.tap(find.text('رویداد جدید'));
    await tester.pumpAndSettle();
    await tester.enterText(fieldOf(eventEditorTitleKey), title);
    if (start != null) {
      await tester.enterText(fieldOf(eventEditorStartKey), start);
    }
    if (end != null) {
      await tester.enterText(fieldOf(eventEditorEndKey), end);
    }
    await saveSheet(tester);
    expectSheetClosed();
  }

  testWidgets('روز بدون رویداد حالت خالی نشان می‌دهد', (
    WidgetTester tester,
  ) async {
    await openEventsPage(tester);

    expect(find.text('رویدادها'), findsOneWidget);
    expect(find.text('برای این روز رویدادی ثبت نشده'), findsOneWidget);
  });

  testWidgets('ساخت رویداد در فهرست روز ظاهر می‌شود', (
    WidgetTester tester,
  ) async {
    await openEventsPage(tester);

    await createEvent(tester, title: 'جلسه‌ی شورا');

    expect(find.text('جلسه‌ی شورا'), findsOneWidget);
    expect(find.text('۱۰:۰۰'), findsOneWidget);
    expect(find.text('برای این روز رویدادی ثبت نشده'), findsNothing);
  });

  testWidgets('عنوان خالی در فرم پیام خطا می‌دهد', (
    WidgetTester tester,
  ) async {
    await openEventsPage(tester);

    await tester.tap(find.text('رویداد جدید'));
    await tester.pumpAndSettle();
    await saveSheet(tester);

    expect(find.text('عنوان رویداد نمی‌تواند خالی باشد.'), findsOneWidget);
  });

  testWidgets('تداخل زمانی قبل از ذخیره هشدار می‌دهد', (
    WidgetTester tester,
  ) async {
    await openEventsPage(tester);
    await createEvent(tester, title: 'جلسه‌ی اول');

    await tester.tap(find.text('رویداد جدید'));
    await tester.pumpAndSettle();
    await tester.enterText(fieldOf(eventEditorTitleKey), 'جلسه‌ی دوم');
    await tester.enterText(fieldOf(eventEditorStartKey), '10:30');
    await tester.enterText(fieldOf(eventEditorEndKey), '11:30');
    // دیالوگ هم‌پوشانی همین‌جا باز می‌شود، پس فرم هنوز بسته نشده است.
    await saveSheet(tester);

    expect(find.text('همپوشانی زمانی'), findsOneWidget);

    await tester.tap(find.text('ثبت با تداخل'));
    await tester.pumpAndSettle();
    expectSheetClosed();

    expect(find.text('جلسه‌ی اول'), findsOneWidget);
    expect(find.text('جلسه‌ی دوم'), findsOneWidget);
  });

  testWidgets('ورودی با ارقام فارسی هم پذیرفته می‌شود', (
    WidgetTester tester,
  ) async {
    await openEventsPage(tester);

    await createEvent(
      tester,
      title: 'ورزش صبحگاهی',
      start: '۰۶:۳۰',
      end: '۰۷:۱۵',
    );

    expect(find.text('ورزش صبحگاهی'), findsOneWidget);
    expect(find.text('۰۶:۳۰'), findsOneWidget);
  });

  testWidgets('رویداد تمام‌روز برچسب تمام‌روز می‌گیرد', (
    WidgetTester tester,
  ) async {
    await openEventsPage(tester);

    await tester.tap(find.text('رویداد جدید'));
    await tester.pumpAndSettle();
    await tester.enterText(fieldOf(eventEditorTitleKey), 'روز پژوهش');
    await tester.tap(find.text('تمام‌روز'));
    await tester.pumpAndSettle();
    await saveSheet(tester);
    expectSheetClosed();

    expect(find.text('روز پژوهش'), findsOneWidget);
    expect(find.text('تمام‌روز'), findsOneWidget);
  });

  testWidgets('جزئیات باز می‌شود و حذف رویداد را برمی‌دارد', (
    WidgetTester tester,
  ) async {
    await openEventsPage(tester);
    await createEvent(tester, title: 'جلسه‌ی شورا');

    await tester.tap(find.text('جلسه‌ی شورا'));
    await tester.pumpAndSettle();
    expect(find.text('جزئیات رویداد'), findsOneWidget);

    await tester.tap(find.byTooltip('حذف رویداد'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف'));
    await tester.pumpAndSettle();

    expect(find.text('جزئیات رویداد'), findsNothing);
    expect(find.text('جلسه‌ی شورا'), findsNothing);
    expect(find.text('برای این روز رویدادی ثبت نشده'), findsOneWidget);
  });

  testWidgets('جابه‌جایی روز رویدادها را جدا می‌کند', (
    WidgetTester tester,
  ) async {
    await openEventsPage(tester);
    await createEvent(tester, title: 'جلسه‌ی امروز');

    await tester.tap(find.byTooltip('روز بعد'));
    await tester.pumpAndSettle();
    expect(find.text('جلسه‌ی امروز'), findsNothing);
    expect(find.text('برای این روز رویدادی ثبت نشده'), findsOneWidget);

    await tester.tap(find.byTooltip('روز قبل'));
    await tester.pumpAndSettle();
    expect(find.text('جلسه‌ی امروز'), findsOneWidget);
  });

  testWidgets('ساخت رویداد هفتگی در همان روز هفته‌ی بعد هم دیده می‌شود', (
    WidgetTester tester,
  ) async {
    await openEventsPage(tester);

    await tester.tap(find.text('رویداد جدید'));
    await tester.pumpAndSettle();
    await tester.enterText(fieldOf(eventEditorTitleKey), 'کلاس روش تحقیق');
    await tester.tap(find.byKey(eventEditorRecurrenceKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('هفتگی').last);
    await tester.pumpAndSettle();
    await saveSheet(tester);
    expectSheetClosed();

    expect(find.text('کلاس روش تحقیق'), findsOneWidget);

    for (int i = 0; i < 7; i++) {
      await tester.tap(find.byTooltip('روز بعد'));
      await tester.pumpAndSettle();
    }

    expect(find.text('کلاس روش تحقیق'), findsOneWidget);
  });

  testWidgets('ویرایش نمونه‌ی تکراری دامنه‌ی اعمال را می‌پرسد', (
    WidgetTester tester,
  ) async {
    await openEventsPage(tester);

    await tester.tap(find.text('رویداد جدید'));
    await tester.pumpAndSettle();
    await tester.enterText(fieldOf(eventEditorTitleKey), 'کلاس روش تحقیق');
    await tester.tap(find.byKey(eventEditorRecurrenceKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('هفتگی').last);
    await tester.pumpAndSettle();
    await saveSheet(tester);
    expectSheetClosed();

    await tester.tap(find.text('کلاس روش تحقیق'));
    await tester.pumpAndSettle();
    expect(find.text('تکرار'), findsOneWidget);
    expect(find.text('هر هفته • بدون تاریخ پایان'), findsOneWidget);

    await tester.tap(find.byTooltip('ویرایش رویداد'));
    await tester.pumpAndSettle();
    await tester.enterText(fieldOf(eventEditorTitleKey), 'کارگاه');
    await saveSheet(tester);

    expect(find.text('ویرایش رویداد تکراری'), findsOneWidget);
    await tester.tap(find.text('این مورد'));
    await tester.pumpAndSettle();
    expectSheetClosed();
  });

  testWidgets('حذف نمونه‌ی تکراری فقط همان روز را برمی‌دارد', (
    WidgetTester tester,
  ) async {
    await openEventsPage(tester);

    await tester.tap(find.text('رویداد جدید'));
    await tester.pumpAndSettle();
    await tester.enterText(fieldOf(eventEditorTitleKey), 'کلاس روش تحقیق');
    await tester.tap(find.byKey(eventEditorRecurrenceKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('هفتگی').last);
    await tester.pumpAndSettle();
    await saveSheet(tester);
    expectSheetClosed();

    await tester.tap(find.text('کلاس روش تحقیق'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('حذف رویداد'));
    await tester.pumpAndSettle();
    expect(find.text('حذف رویداد تکراری'), findsOneWidget);
    await tester.tap(find.text('این مورد'));
    await tester.pumpAndSettle();

    expect(find.text('برای این روز رویدادی ثبت نشده'), findsOneWidget);

    await tester.tap(find.byTooltip('روز بعد'));
    await tester.pumpAndSettle();
    for (int i = 0; i < 6; i++) {
      await tester.tap(find.byTooltip('روز بعد'));
      await tester.pumpAndSettle();
    }
    expect(find.text('کلاس روش تحقیق'), findsOneWidget);
  });
}
