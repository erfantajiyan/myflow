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
import 'package:myflow/features/reports/presentation/reports_page.dart';

void main() {
  final DateTime fixedNow = DateTime(2025, 3, 21, 9, 30);
  const String respId = 'resp-reports-ui';

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await DriftResponsibilityRepository(db).insertResponsibility(
      id: respId,
      name: 'تحصیل',
      color: const Color(0xFF5BA8FF),
    );
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

  Future<void> openReports(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('گزارش‌ها'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ReportsPage), findsOneWidget);
  }

  testWidgets('اعداد گزارش از رویدادها و وظایف ساخته می‌شود', (
    WidgetTester tester,
  ) async {
    final DriftEventRepository events = DriftEventRepository(db);
    await events.insertEvent(
      responsibilityId: respId,
      title: 'کلاس',
      startAt: DateTime(2025, 3, 22, 10),
      endAt: DateTime(2025, 3, 22, 11, 30),
    );
    await DriftTaskRepository(db).insertTask(
      responsibilityId: respId,
      title: 'عقب‌افتاده',
      dueDate: DateTime(2025, 3, 20),
    );

    await openReports(tester);

    expect(find.text('فروردین ۱۴۰۴'), findsOneWidget);
    expect(find.text('رویدادها'), findsOneWidget);
    expect(find.text('۱.۵ ساعت'), findsOneWidget);
    expect(find.text('تفکیک مسئولیت'), findsOneWidget);
    expect(find.text('تحصیل'), findsOneWidget);
    expect(find.text('روند تکمیل هفتگی'), findsOneWidget);
  });

  testWidgets('ماه بدون داده حالت خالی نشان می‌دهد', (
    WidgetTester tester,
  ) async {
    await openReports(tester);

    await tester.tap(find.byTooltip('ماه بعد'));
    await tester.pumpAndSettle();

    expect(find.text('اردیبهشت ۱۴۰۴'), findsOneWidget);
    expect(find.text('داده‌ای برای این ماه نیست'), findsOneWidget);
  });
}
