import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myflow/app/app.dart';
import 'package:myflow/database/app_database.dart';
import 'package:myflow/database/database_providers.dart';
import 'package:myflow/features/tasks/presentation/task_editor_sheet.dart';

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

  // کلید مستقیماً روی خود TextFormField گذاشته شده است.
  Finder fieldOf(Key key) => find.byKey(key);

  Future<void> openTasksPage(WidgetTester tester) async {
    // فرم وظیفه بلند است؛ با ارتفاع پیش‌فرض دکمه‌ی ذخیره بیرون از ویوپورت
    // می‌ماند.
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('وظایف').first);
    await tester.pumpAndSettle();
  }

  // کیبورد باز، ارتفاع ویوپورت را کم می‌کند و دکمه‌ی ذخیره زیر آن می‌ماند؛
  // tap بدون بستن کیبورد به هدف نمی‌خورد.
  Future<void> dismissKeyboard(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  Future<void> createTask(WidgetTester tester, String title) async {
    await tester.tap(find.text('وظیفه‌ی جدید'));
    await tester.pumpAndSettle();
    await tester.enterText(fieldOf(taskEditorTitleKey), title);
    await dismissKeyboard(tester);
    await tester.ensureVisible(find.text('ذخیره وظیفه'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ذخیره وظیفه'));
    await tester.pumpAndSettle();
    // فرم باز‌مانده یعنی ذخیره رد شده است.
    expect(find.text('ذخیره وظیفه'), findsNothing);
  }

  testWidgets('صفحه‌ی خالی پیام روشن نشان می‌دهد', (WidgetTester tester) async {
    await openTasksPage(tester);

    expect(find.text('هنوز وظیفه‌ای ثبت نشده'), findsOneWidget);
  });

  testWidgets('ساخت وظیفه در فهرست ظاهر می‌شود', (WidgetTester tester) async {
    await openTasksPage(tester);
    await createTask(tester, 'ارسال گزارش هفتگی');

    expect(find.text('ارسال گزارش هفتگی'), findsOneWidget);
    expect(find.text('هنوز وظیفه‌ای ثبت نشده'), findsNothing);
    expect(find.textContaining('بدون سررسید'), findsOneWidget);
  });

  testWidgets('عنوان خالی در فرم پیام خطا می‌دهد', (WidgetTester tester) async {
    await openTasksPage(tester);

    await tester.tap(find.text('وظیفه‌ی جدید'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ذخیره وظیفه'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ذخیره وظیفه'));
    await tester.pumpAndSettle();

    expect(find.text('عنوان وظیفه نمی‌تواند خالی باشد.'), findsOneWidget);
  });

  testWidgets('تکمیل وظیفه در فیلتر تکمیل‌شده دیده می‌شود', (
    WidgetTester tester,
  ) async {
    await openTasksPage(tester);
    await createTask(tester, 'تمرین ریاضی');

    await tester.tap(find.byTooltip('تکمیل وظیفه'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('تکمیل‌شده'));
    await tester.pumpAndSettle();
    expect(find.text('تمرین ریاضی'), findsOneWidget);

    await tester.tap(find.text('همه'));
    await tester.pumpAndSettle();
    expect(find.text('تمرین ریاضی'), findsOneWidget);
  });

  testWidgets('فیلتر عقب‌افتاده وظیفه‌ی بدون سررسید را نشان نمی‌دهد', (
    WidgetTester tester,
  ) async {
    await openTasksPage(tester);
    await createTask(tester, 'کار بی‌تاریخ');

    await tester.tap(find.text('عقب‌افتاده'));
    await tester.pumpAndSettle();

    expect(find.text('کار بی‌تاریخ'), findsNothing);
    expect(find.text('هیچ وظیفه‌ای عقب نیفتاده'), findsOneWidget);
  });

  testWidgets('ساعت واردشده با ارقام فارسی ذخیره می‌شود', (
    WidgetTester tester,
  ) async {
    await openTasksPage(tester);

    await tester.tap(find.text('وظیفه‌ی جدید'));
    await tester.pumpAndSettle();
    await tester.enterText(fieldOf(taskEditorTitleKey), 'تمرین ریاضی');
    await tester.enterText(fieldOf(taskEditorDateKey), '۱۴۰۵/۰۸/۱۴');
    await tester.enterText(fieldOf(taskEditorTimeKey), '۱۰:۱۵');
    await dismissKeyboard(tester);
    await tester.ensureVisible(find.text('ذخیره وظیفه'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ذخیره وظیفه'));
    await tester.pumpAndSettle();

    // اگر ساعت تجزیه نمی‌شد، فرم باز می‌ماند و خطا نشان می‌داد.
    expect(find.text('ذخیره وظیفه'), findsNothing);
    expect(find.textContaining('ساعت را به شکل'), findsNothing);
    expect(find.textContaining('۱۰:۱۵'), findsOneWidget);
  });

  testWidgets('تبدیل وظیفه به رویداد پیام تأیید می‌دهد', (
    WidgetTester tester,
  ) async {
    await openTasksPage(tester);
    await createTask(tester, 'جلسه با استاد');
    // ScaffoldMessenger پیام‌ها را صف می‌کند؛ تا رفتن پیام ساخت، پیام تبدیل
    // نمایش داده نمی‌شود.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('اقدام‌های جلسه با استاد'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تبدیل به رویداد'));
    await tester.pumpAndSettle();

    expect(
      find.text('رویداد ۰۹:۰۰ تا ۱۰:۰۰ برای این وظیفه ساخته شد.'),
      findsOneWidget,
    );
    // وظیفه باید سر جایش بماند.
    expect(find.text('جلسه با استاد'), findsOneWidget);
  });

  testWidgets('ویرایش عنوان از فرم انجام می‌شود', (WidgetTester tester) async {
    await openTasksPage(tester);
    await createTask(tester, 'عنوان قدیمی');
    // SnackBar موفقیت چند ثانیه پایین صفحه می‌ماند و روی دکمه‌ی ذخیره‌ی فرم
    // بعدی می‌افتد؛ تا محو شدنش صبر می‌کنیم.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.tap(find.text('عنوان قدیمی'));
    await tester.pumpAndSettle();
    await tester.enterText(fieldOf(taskEditorTitleKey), 'عنوان جدید');
    await dismissKeyboard(tester);
    await tester.ensureVisible(find.text('ذخیره وظیفه'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ذخیره وظیفه'));
    await tester.pumpAndSettle();

    expect(find.text('عنوان جدید'), findsOneWidget);
    expect(find.text('عنوان قدیمی'), findsNothing);
  });
}
