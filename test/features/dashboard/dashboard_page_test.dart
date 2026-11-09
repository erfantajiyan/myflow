import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myflow/app/app.dart';
import 'package:myflow/core/providers/core_providers.dart';
import 'package:myflow/database/app_database.dart';
import 'package:myflow/database/database_providers.dart';
import 'package:myflow/database/event_repository_impl.dart';
import 'package:myflow/database/responsibility_repository_impl.dart';
import 'package:myflow/database/task_repository_impl.dart';
import 'package:myflow/features/dashboard/presentation/dashboard_page.dart';
import 'package:myflow/features/tasks/presentation/task_editor_sheet.dart';
import 'package:myflow/shared/enums/app_enums.dart';

void main() {
  const String respId = 'resp-test';
  final DateTime now = DateTime(2026, 11, 5, 10, 0);
  final DateTime today = DateTime(2026, 11, 5);

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await DriftResponsibilityRepository(db).insertResponsibility(
      id: respId,
      name: 'دانشجو',
      color: const Color(0xFF3B82F6),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWith((Ref ref) => db),
        nowProvider.overrideWith((Ref ref) => () => now),
      ],
      child: const MyFlowApp(),
    );
  }

  Future<void> openDashboard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
  }

  testWidgets('برنامه، وظایف و زمان آزاد از دیتابیس خوانده می‌شوند', (
    WidgetTester tester,
  ) async {
    final EventRepository events = DriftEventRepository(db);
    final TaskRepository tasks = DriftTaskRepository(db);

    await events.insertEvent(
      responsibilityId: respId,
      title: 'جلسه‌ی صبح',
      startAt: DateTime(2026, 11, 5, 9, 0),
      endAt: DateTime(2026, 11, 5, 10, 30),
    );
    await events.insertEvent(
      responsibilityId: respId,
      title: 'روز پژوهش',
      startAt: today,
      endAt: today,
      allDay: true,
    );
    await tasks.insertTask(
      responsibilityId: respId,
      title: 'کار امروز',
      dueDate: today,
    );
    final Task other = await tasks.insertTask(
      responsibilityId: respId,
      title: 'کار دوم امروز',
      dueDate: today,
      dueTime: '12:00',
    );
    await tasks.insertTask(responsibilityId: respId, title: 'کار بدون تاریخ');

    await openDashboard(tester);

    // ۲ رویداد فعال (یکی تمام‌روز) و ۳ وظیفه‌ی باز.
    expect(find.text('۲ رویداد • ۳ کار باز'), findsOneWidget);
    expect(find.text('جلسه‌ی صبح'), findsOneWidget);
    expect(find.text('روز پژوهش'), findsOneWidget);
    expect(find.text('کار امروز'), findsOneWidget);
    expect(find.text('کار دوم امروز'), findsOneWidget);
    // رویداد ۹:۰۰ تا ۱۰:۳۰ یعنی ۱۳۵۰ دقیقه آزاد.
    expect(find.text('۲۲ ساعت و ۳۰ دقیقه'), findsOneWidget);

    // تکمیل سریع از داشبورد.
    await tester.tap(
      find.descendant(
        of: find.byKey(dashboardTaskTileKey(other.id)),
        matching: find.byType(Checkbox),
      ),
    );
    await tester.pumpAndSettle();

    final Task? reloaded = await tasks.getTaskById(other.id);
    expect(reloaded?.status, TaskStatus.completed);
    expect(find.text('۲ رویداد • ۲ کار باز'), findsOneWidget);
  });

  testWidgets('ساخت وظیفه از صفحه‌ی وظایف، داشبورد را تازه می‌کند', (
    WidgetTester tester,
  ) async {
    await openDashboard(tester);

    await tester.tap(find.text('وظایف').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('وظیفه‌ی جدید'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(taskEditorTitleKey), 'جمع‌بندی مقاله');
    await tester.enterText(find.byKey(taskEditorDateKey), '۱۴۰۵/۰۸/۱۴');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ذخیره وظیفه'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ذخیره وظیفه'));
    await tester.pumpAndSettle();

    expect(find.text('جمع‌بندی مقاله'), findsWidgets);

    await tester.tap(find.text('خانه').first);
    await tester.pumpAndSettle();

    // داشبورد باید بدون بازگشایی مجدد اپ، عدد تازه را نشان دهد.
    expect(find.text('۰ رویداد • ۱ کار باز'), findsOneWidget);
    expect(find.text('جمع‌بندی مقاله'), findsOneWidget);
  });

  testWidgets('روز خالی داشبورد پیام و اقدام نشان می‌دهد', (
    WidgetTester tester,
  ) async {
    await openDashboard(tester);

    expect(find.text('۰ رویداد • ۰ کار باز'), findsOneWidget);
    expect(find.text('برنامه‌ی امروز خالی است'), findsOneWidget);
    expect(find.text('وظیفه‌ای برای امروز نیست'), findsOneWidget);
    expect(find.textContaining('کل روز آزاد است'), findsOneWidget);
    expect(find.text('۲۴ ساعت'), findsOneWidget);
  });
}
