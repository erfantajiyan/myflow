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
import 'package:myflow/features/calendar/presentation/calendar_page.dart';
import 'package:myflow/shared/enums/app_enums.dart';

void main() {
  const String respId = 'resp-test';
  final DateTime now = DateTime(2026, 3, 21, 10, 0);
  final DateTime day = DateTime(2026, 3, 21);

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

  Future<void> openCalendar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('تقویم').first);
    await tester.pumpAndSettle();
  }

  Future<Event> seedEvent() {
    return DriftEventRepository(db).insertEvent(
      responsibilityId: respId,
      title: 'جلسه‌ی شورا',
      startAt: DateTime(2026, 3, 21, 9, 0),
      endAt: DateTime(2026, 3, 21, 10, 0),
    );
  }

  Future<Task> seedTask() {
    return DriftTaskRepository(db).insertTask(
      responsibilityId: respId,
      title: 'ارسال گزارش',
      dueDate: day,
      dueTime: '08:00',
    );
  }

  testWidgets('شبکه‌ی ماه و خلاصه‌ی روز از دیتابیس پر می‌شود', (
    WidgetTester tester,
  ) async {
    await seedEvent();
    await seedTask();
    await openCalendar(tester);

    expect(find.text('فروردین ۱۴۰۵'), findsWidgets);
    expect(find.byKey(calendarDayCellKey(day)), findsOneWidget);
    expect(find.byKey(calendarDaySummaryKey), findsOneWidget);
    expect(find.text('جلسه‌ی شورا'), findsOneWidget);
    expect(find.text('ارسال گزارش'), findsOneWidget);
    // روز اول ماه، ستون اول (شنبه) است.
    expect(find.text('شنبه • ۱ فروردین ۱۴۰۵'), findsOneWidget);
  });

  testWidgets('روز خالی پیام روشن نشان می‌دهد', (WidgetTester tester) async {
    await openCalendar(tester);
    await tester.tap(find.byKey(calendarDayCellKey(DateTime(2026, 3, 25))));
    await tester.pumpAndSettle();

    expect(
      find.text('برای این روز رویداد یا وظیفه‌ای ثبت نشده است.'),
      findsOneWidget,
    );
  });

  testWidgets('تکمیل وظیفه از خلاصه‌ی روز در دیتابیس ذخیره می‌شود', (
    WidgetTester tester,
  ) async {
    final Task task = await seedTask();
    await openCalendar(tester);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    final Task? reloaded = await DriftTaskRepository(db).getTaskById(task.id);
    expect(reloaded?.status, TaskStatus.completed);
  });

  testWidgets('ماه قبل و بعد جابه‌جا می‌شود', (WidgetTester tester) async {
    await openCalendar(tester);

    await tester.tap(find.byKey(calendarNextKey));
    await tester.pumpAndSettle();
    expect(find.text('اردیبهشت ۱۴۰۵'), findsWidgets);

    await tester.tap(find.byKey(calendarPreviousKey));
    await tester.pumpAndSettle();
    expect(find.text('فروردین ۱۴۰۵'), findsWidgets);
  });

  testWidgets('نمای هفتگی هفت روز را نشان می‌دهد', (WidgetTester tester) async {
    await seedEvent();
    await openCalendar(tester);

    await tester.tap(find.byKey(calendarWeekModeKey));
    await tester.pumpAndSettle();

    // هفته از شنبه ۱ فروردین شروع می‌شود و تا جمعه ۷ فروردین می‌رود.
    expect(find.byKey(calendarWeekDayCardKey(day)), findsOneWidget);
    expect(
      find.byKey(calendarWeekDayCardKey(DateTime(2026, 3, 27))),
      findsOneWidget,
    );
    expect(find.text('جلسه‌ی شورا'), findsOneWidget);
  });
}
