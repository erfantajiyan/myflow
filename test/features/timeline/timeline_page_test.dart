import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myflow/app/app.dart';
import 'package:myflow/app/router.dart';
import 'package:myflow/core/providers/core_providers.dart';
import 'package:myflow/database/app_database.dart';
import 'package:myflow/database/database_providers.dart';
import 'package:myflow/database/event_repository_impl.dart';
import 'package:myflow/database/responsibility_repository_impl.dart';
import 'package:myflow/features/timeline/presentation/timeline_page.dart';

void main() {
  const String respId = 'resp-test';
  final DateTime now = DateTime(2026, 3, 21, 10, 0);

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

  Future<void> openTimeline(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(find.byType(MyFlowApp));
    ProviderScope.containerOf(context)
        .read(appRouterProvider)
        .go('/timeline?date=2026-03-21');
    await tester.pumpAndSettle();
  }

  testWidgets('رویدادها و رویداد تمام‌روز روی محور دیده می‌شوند', (
    WidgetTester tester,
  ) async {
    final Event event = await DriftEventRepository(db).insertEvent(
      responsibilityId: respId,
      title: 'کلاس تحلیل',
      startAt: DateTime(2026, 3, 21, 9, 0),
      endAt: DateTime(2026, 3, 21, 10, 0),
    );
    await DriftEventRepository(db).insertEvent(
      responsibilityId: respId,
      title: 'روز پژوهش',
      startAt: DateTime(2026, 3, 21),
      endAt: DateTime(2026, 3, 21),
      allDay: true,
    );

    await openTimeline(tester);

    expect(find.byKey(timelineBlockKey(event.id)), findsOneWidget);
    expect(find.text('کلاس تحلیل'), findsOneWidget);
    expect(find.textContaining('روز پژوهش'), findsOneWidget);
    expect(find.byKey(timelineNowLineKey), findsOneWidget);
    expect(find.textContaining('۲ رویداد'), findsOneWidget);
  });

  testWidgets('لمس بازه‌ی آزاد فرم رویداد را با همان ساعت باز می‌کند', (
    WidgetTester tester,
  ) async {
    await openTimeline(tester);

    expect(find.byKey(timelineEmptyNoticeKey), findsOneWidget);
    expect(find.byKey(timelineFreeSlotKey(0)), findsOneWidget);

    // محور به‌طور پیش‌فرض روی ساعت جاری اسکرول شده است؛ برای لمس ساعت
    // ۰۰:۰۰ اول به بالای محور برمی‌گردیم.
    await tester.drag(find.byKey(timelineAxisKey), const Offset(0, 2000));
    await tester.pumpAndSettle();
    final Offset axisTop = tester.getTopLeft(find.byKey(timelineAxisKey));
    await tester.tapAt(axisTop + const Offset(30, 30));
    await tester.pumpAndSettle();

    expect(find.text('ذخیره رویداد'), findsOneWidget);
    expect(find.text('00:00'), findsWidgets);
  });

  testWidgets('روز بعد، برنامه‌ی روز دیگر را نشان می‌دهد', (
    WidgetTester tester,
  ) async {
    await openTimeline(tester);

    await tester.tap(find.byKey(timelineNextKey));
    await tester.pumpAndSettle();

    expect(find.textContaining('۲ فروردین ۱۴۰۵'), findsOneWidget);
    expect(find.byKey(timelineNowLineKey), findsNothing);
  });
}
