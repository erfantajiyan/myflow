import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myflow/database/app_database.dart';
import 'package:myflow/database/event_repository_impl.dart';
import 'package:myflow/database/responsibility_repository_impl.dart';
import 'package:myflow/features/recurrence/domain/recurrence_rule.dart';
import 'package:myflow/shared/enums/app_enums.dart';

void main() {
  const String respId = 'resp-test';

  late AppDatabase db;
  late DriftEventRepository events;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    events = DriftEventRepository(db);
    await DriftResponsibilityRepository(db).insertResponsibility(
      id: respId,
      name: 'تحصیل',
      color: const Color(0xFF5BA8FF),
    );
  });

  tearDown(() async {
    await db.close();
  });

  /// سری هفتگی: هر شنبه ۱۰:۰۰ تا ۱۱:۰۰ از ۱۴۰۵/۰۱/۰۱.
  Future<Event> createWeekly({
    DateTime? start,
    DateTime? end,
    DateTime? until,
    int? countLimit,
    int interval = 1,
  }) {
    final DateTime startAt = start ?? DateTime(2026, 3, 21, 10, 0);
    return events.createRecurringEvent(
      responsibilityId: respId,
      title: 'کلاس روش تحقیق',
      startAt: startAt,
      endAt: end ?? startAt.add(const Duration(hours: 1)),
      frequency: RecurrenceFrequency.weekly,
      interval: interval,
      untilLocalDate: until,
      countLimit: countLimit,
    );
  }

  Future<List<Event>> range(DateTime from, DateTime to) =>
      events.getEventsInRange(fromDay: from, toDay: to);

  group('ساخت سری و گسترش نمونه‌ها', () {
    test('نمونه‌ها محاسبه می‌شوند و شناسه‌ی نمایشی دارند', () async {
      final Event master = await createWeekly();

      final List<Event> occurrences = await range(
        DateTime(2026, 3, 21),
        DateTime(2026, 3, 31),
      );

      expect(occurrences, hasLength(2));
      expect(occurrences[0].id, startsWith('${master.id}@'));
      expect(occurrences[0].isOccurrence, isTrue);
      expect(occurrences[0].masterId, master.id);
      expect(occurrences[0].startLocal, DateTime(2026, 3, 21, 10, 0));
      expect(occurrences[1].startLocal, DateTime(2026, 3, 28, 10, 0));
    });

    test('روشن‌ترین master به‌تنهایی در بازه برنمی‌گردد', () async {
      final Event master = await createWeekly();

      final List<Event> occurrences = await range(
        DateTime(2026, 3, 21),
        DateTime(2026, 3, 22),
      );

      expect(occurrences, hasLength(1));
      expect(occurrences.single.id, isNot(master.id));
    });

    test('count_limit تعداد نمونه‌ها را محدود می‌کند', () async {
      await createWeekly(countLimit: 2);

      final List<Event> occurrences = await range(
        DateTime(2026, 3, 1),
        DateTime(2026, 4, 30),
      );

      expect(occurrences, hasLength(2));
    });

    test('تا تاریخ مشخص، بعد از آن نمونه‌ای ساخته نمی‌شود', () async {
      await createWeekly(until: DateTime(2026, 4, 4));

      final List<Event> occurrences = await range(
        DateTime(2026, 3, 1),
        DateTime(2026, 5, 1),
      );

      expect(
        occurrences.map((Event event) => event.startLocal),
        <DateTime>[
          DateTime(2026, 3, 21, 10, 0),
          DateTime(2026, 3, 28, 10, 0),
          DateTime(2026, 4, 4, 10, 0),
        ],
      );
    });

    test('قاعده‌ی سری از repository خوانده می‌شود', () async {
      final Event master = await createWeekly(countLimit: 5);

      final RecurrenceRule? rule = await events.getRecurrenceRule(
        master.recurrenceRuleId!,
      );

      expect(rule, isNotNull);
      expect(rule!.frequency, RecurrenceFrequency.weekly);
      expect(rule.interval, 1);
      expect(rule.countLimit, 5);
      expect(rule.startLocalDate, DateTime(2026, 3, 21));
      expect(rule.startMinutes, 600);
    });

    test('getEventById شناسه‌ی نمایشی را به نمونه تبدیل می‌کند', () async {
      await createWeekly();
      final List<Event> occurrences = await range(
        DateTime(2026, 3, 28),
        DateTime(2026, 3, 28),
      );

      final Event? fetched = await events.getEventById(occurrences.single.id);

      expect(fetched, isNotNull);
      expect(fetched!.startLocal, DateTime(2026, 3, 28, 10, 0));
      expect(fetched.title, 'کلاس روش تحقیق');
    });
  });

  group('ویرایش با دامنه', () {
    test('فقط این مورد: بقیه‌ی سری دست‌نخورده می‌ماند', () async {
      await createWeekly();
      final List<Event> before = await range(
        DateTime(2026, 3, 21),
        DateTime(2026, 3, 28),
      );
      final Event second = before[1];

      await events.updateOccurrence(
        occurrenceId: second.id,
        scope: RecurrenceEditScope.thisOnly,
        title: 'کلاس جبرانی',
        startAt: DateTime(2026, 3, 28, 16, 0),
        endAt: DateTime(2026, 3, 28, 17, 0),
      );

      final List<Event> after = await range(
        DateTime(2026, 3, 21),
        DateTime(2026, 3, 28),
      );

      expect(after[0].title, 'کلاس روش تحقیق');
      expect(after[0].startLocal, DateTime(2026, 3, 21, 10, 0));
      expect(after[1].title, 'کلاس جبرانی');
      expect(after[1].startLocal, DateTime(2026, 3, 28, 16, 0));
      expect(after[1].isOccurrence, isTrue);
    });

    test('لغو یک نمونه آن را حذف می‌کند و بقیه می‌مانند', () async {
      await createWeekly();
      final List<Event> before = await range(
        DateTime(2026, 3, 21),
        DateTime(2026, 3, 28),
      );

      await events.deleteOccurrence(
        occurrenceId: before[0].id,
        scope: RecurrenceEditScope.thisOnly,
      );

      final List<Event> after = await range(
        DateTime(2026, 3, 21),
        DateTime(2026, 3, 28),
      );

      expect(after, hasLength(1));
      expect(after.single.startLocal, DateTime(2026, 3, 28, 10, 0));
    });

    test('نمونه‌ی منتقل‌شده فقط در روز جدید دیده می‌شود', () async {
      await createWeekly();
      final List<Event> before = await range(
        DateTime(2026, 3, 28),
        DateTime(2026, 3, 28),
      );

      await events.updateOccurrence(
        occurrenceId: before.single.id,
        scope: RecurrenceEditScope.thisOnly,
        startAt: DateTime(2026, 3, 29, 9, 0),
        endAt: DateTime(2026, 3, 29, 10, 0),
      );

      expect(
        await range(DateTime(2026, 3, 28), DateTime(2026, 3, 28)),
        isEmpty,
      );
      final List<Event> moved = await range(
        DateTime(2026, 3, 29),
        DateTime(2026, 3, 29),
      );
      expect(moved, hasLength(1));
      expect(moved.single.startLocal, DateTime(2026, 3, 29, 9, 0));
      expect(
        moved.single.recurrenceInstanceKey,
        before.single.recurrenceInstanceKey,
      );
    });

    test('این و بعدی‌ها: سری به دو بخش تقسیم می‌شود', () async {
      await createWeekly();
      final List<Event> before = await range(
        DateTime(2026, 3, 28),
        DateTime(2026, 3, 28),
      );

      await events.updateOccurrence(
        occurrenceId: before.single.id,
        scope: RecurrenceEditScope.thisAndFollowing,
        title: 'کارگاه',
        startAt: DateTime(2026, 3, 28, 12, 0),
        endAt: DateTime(2026, 3, 28, 13, 0),
      );

      final List<Event> all = await range(
        DateTime(2026, 3, 1),
        DateTime(2026, 4, 30),
      );

      expect(all.first.title, 'کلاس روش تحقیق');
      expect(all.first.startLocal, DateTime(2026, 3, 21, 10, 0));
      final List<Event> later = all
          .where((Event event) => !event.startLocal.isBefore(DateTime(2026, 3, 28)))
          .toList();
      expect(later, isNotEmpty);
      expect(later.every((Event event) => event.title == 'کارگاه'), isTrue);
      expect(later.every((Event event) => event.startLocal.hour == 12), isTrue);
      // سری جدید شناسه‌ی master تازه دارد ولی همان قاعده‌ی هفتگی است.
      expect(later.first.masterId, isNot(all.first.masterId));
      expect(later, hasLength(5)); // ۲۸ فروردین تا ۲۵ اردیبهشت
    });

    test('کل سری: ساعت همه‌ی نمونه‌ها تغییر می‌کند', () async {
      await createWeekly();

      await events.updateOccurrence(
        occurrenceId: (await range(
          DateTime(2026, 3, 21),
          DateTime(2026, 3, 21),
        ))
            .single
            .id,
        scope: RecurrenceEditScope.allSeries,
        startAt: DateTime(2026, 3, 21, 8, 30),
        endAt: DateTime(2026, 3, 21, 9, 30),
      );

      final List<Event> all = await range(
        DateTime(2026, 3, 21),
        DateTime(2026, 4, 4),
      );

      expect(all, hasLength(3));
      expect(
        all.every(
          (Event event) =>
              event.startLocal.hour == 8 && event.startLocal.minute == 30,
        ),
        isTrue,
      );
    });

    test('کل سری استثنای نمونه را حفظ می‌کند', () async {
      await createWeekly();
      final List<Event> before = await range(
        DateTime(2026, 3, 28),
        DateTime(2026, 3, 28),
      );
      await events.updateOccurrence(
        occurrenceId: before.single.id,
        scope: RecurrenceEditScope.thisOnly,
        title: 'استثنا',
      );

      await events.updateOccurrence(
        occurrenceId: (await range(
          DateTime(2026, 3, 21),
          DateTime(2026, 3, 21),
        ))
            .single
            .id,
        scope: RecurrenceEditScope.allSeries,
        startAt: DateTime(2026, 3, 21, 9, 0),
        endAt: DateTime(2026, 3, 21, 10, 0),
      );

      final List<Event> all = await range(
        DateTime(2026, 3, 21),
        DateTime(2026, 3, 28),
      );

      expect(all, hasLength(2));
      expect(all[0].startLocal.hour, 9);
      expect(all[1].title, 'استثنا');
    });
  });

  group('حذف سری', () {
    test('حذف کل سری هیچ نمونه‌ای باقی نمی‌گذارد', () async {
      await createWeekly();
      final List<Event> before = await range(
        DateTime(2026, 3, 21),
        DateTime(2026, 3, 28),
      );

      await events.deleteOccurrence(
        occurrenceId: before.first.id,
        scope: RecurrenceEditScope.allSeries,
      );

      expect(
        await range(DateTime(2026, 3, 1), DateTime(2026, 4, 30)),
        isEmpty,
      );
    });

    test('این و بعدی‌ها نمونه‌های بعدی را حذف می‌کند و قبلی‌ها می‌مانند', () async {
      await createWeekly();
      final List<Event> before = await range(
        DateTime(2026, 3, 28),
        DateTime(2026, 3, 28),
      );

      await events.deleteOccurrence(
        occurrenceId: before.single.id,
        scope: RecurrenceEditScope.thisAndFollowing,
      );

      final List<Event> after = await range(
        DateTime(2026, 3, 1),
        DateTime(2026, 4, 30),
      );

      expect(after, hasLength(1));
      expect(after.single.startLocal, DateTime(2026, 3, 21, 10, 0));
    });
  });

  group('تداخل با نمونه‌های تکراری', () {
    test('findConflicts نمونه‌ی تکراری را می‌بیند', () async {
      await createWeekly();

      final List<Event> conflicts = await events.findConflicts(
        startAt: DateTime(2026, 3, 28, 10, 30),
        endAt: DateTime(2026, 3, 28, 11, 30),
      );

      expect(conflicts, hasLength(1));
      expect(conflicts.single.isOccurrence, isTrue);
    });

    test('ویرایش نمونه با exclude خودش را تداخل حساب نمی‌کند', () async {
      await createWeekly();
      final Event occurrence = (await range(
        DateTime(2026, 3, 28),
        DateTime(2026, 3, 28),
      ))
          .single;

      final List<Event> conflicts = await events.findConflicts(
        startAt: occurrence.startLocal,
        endAt: occurrence.endLocal,
        excludeEventId: occurrence.id,
      );

      expect(conflicts, isEmpty);
    });
  });
}
