import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myflow/app/app.dart';
import 'package:myflow/database/app_database.dart';
import 'package:myflow/database/database_providers.dart';
import 'package:myflow/features/projects/presentation/project_editor_sheet.dart';

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

  Future<void> openProjectsPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('پروژه‌ها').first);
    await tester.pumpAndSettle();
  }

  Future<void> createProject(WidgetTester tester, String title) async {
    await tester.tap(find.text('پروژه‌ی جدید'));
    await tester.pumpAndSettle();
    await tester.enterText(fieldOf(projectEditorTitleKey), title);
    await tester.ensureVisible(find.text('ذخیره پروژه'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ذخیره پروژه'));
    await tester.pumpAndSettle();
    expect(find.text('ذخیره پروژه'), findsNothing);
  }

  testWidgets('صفحه‌ی خالی پیام روشن نشان می‌دهد', (WidgetTester tester) async {
    await openProjectsPage(tester);

    expect(find.text('هنوز پروژه‌ای ساخته نشده'), findsOneWidget);
  });

  testWidgets('پروژه‌ی جدید با پیشرفت صفر ساخته می‌شود', (
    WidgetTester tester,
  ) async {
    await openProjectsPage(tester);
    await createProject(tester, 'همایش علمی');

    expect(find.text('همایش علمی'), findsOneWidget);
    expect(find.text('۰٪'), findsOneWidget);
    expect(find.textContaining('بدون وظیفه'), findsOneWidget);
    expect(find.textContaining('برنامه‌ریزی‌شده'), findsOneWidget);
  });

  testWidgets('عنوان خالی در فرم پیام خطا می‌دهد', (WidgetTester tester) async {
    await openProjectsPage(tester);

    await tester.tap(find.text('پروژه‌ی جدید'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ذخیره پروژه'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ذخیره پروژه'));
    await tester.pumpAndSettle();

    expect(find.text('عنوان پروژه نمی‌تواند خالی باشد.'), findsOneWidget);
  });

  testWidgets('حذف پروژه بعد از تأیید از فهرست برمی‌دارد', (
    WidgetTester tester,
  ) async {
    await openProjectsPage(tester);
    await createProject(tester, 'پروژه‌ی موقت');

    await tester.tap(find.byTooltip('اقدام‌های پروژه‌ی موقت'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف پروژه'));
    await tester.pumpAndSettle();

    expect(find.text('حذف پروژه'), findsOneWidget);
    await tester.tap(find.text('حذف'));
    await tester.pumpAndSettle();

    expect(find.text('پروژه‌ی موقت'), findsNothing);
    expect(find.text('هنوز پروژه‌ای ساخته نشده'), findsOneWidget);
  });

  testWidgets('بایگانی پروژه آن را از فهرست بیرون می‌برد', (
    WidgetTester tester,
  ) async {
    await openProjectsPage(tester);
    await createProject(tester, 'پروژه‌ی آرشیوی');

    await tester.tap(find.byTooltip('اقدام‌های پروژه‌ی آرشیوی'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('بایگانی'));
    await tester.pumpAndSettle();

    expect(find.text('پروژه‌ی آرشیوی'), findsNothing);
    expect(find.text('هنوز پروژه‌ای ساخته نشده'), findsOneWidget);
  });
}
