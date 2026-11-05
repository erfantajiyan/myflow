import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myflow/database/app_database.dart';
import 'package:myflow/database/event_repository_impl.dart';
import 'package:myflow/database/responsibility_repository_impl.dart';
import 'package:myflow/shared/enums/app_enums.dart';

void main() {
  const String respId = 'resp-test';
  final DateTime day = DateTime(2026, 3, 21);

  late AppDatabase db;
  late DriftEventRepository events;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    events = DriftEventRepository(db);
    await DriftResponsibilityRepository(db).insertResponsibility(
      id: respId,
      name: 'کار',
      color: const Color(0xFF5BA8FF),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<Event> create({
    String title = 'جلسه',
    DateTime? start,
    DateTime? end,
    bool allDay = false,
    EventStatus status = EventStatus.planned,
  }) {
    return events.insertEvent(
      responsibilityId: respId,
      title: title,
      startAt: start ?? DateTime(2026, 3, 21, 10, 0),
      endAt: end ?? DateTime(2026, 3, 21, 11, 0),
      allDay: allDay,
      status: status,
    );
  }

  group('درج و خواندن', () {
    test('رویداد با همه‌ی فیلدها برگردانده می‌شود', () async {
      final Event created = await create();

      expect(created.title, 'جلسه');
      expect(created.responsibilityId, respId);
      expect(created.allDay, isFalse);
      expect(created.status, EventStatus.planned);
      expect(created.startLocal, DateTime(2026, 3, 21, 10, 0));
      expect(created.endLocal, DateTime(2026, 3, 21, 11, 0));
      expect(created.duration, const Duration(hours: 1));

      final Event? fetched = await events.getEventById(created.id);
      expect(fetched, isNotNull);
      expect(fetched!.id, created.id);
      expect(fetched.startLocal, created.startLocal);
    });

    test('شناسه‌ی ناموجود null برمی‌گرداند', () async {
      expect(await events.getEventById('missing'), isNull);
    });
  });

  group('اعتبارسنجی', () {
    test('عنوان خالی رد می‌شود و چیزی ذخیره نمی‌شود', () async {
      await expectLater(
        create(title: '   '),
        throwsA(isA<EventValidationException>()),
      );
      expect(await events.getEventsForDay(day), isEmpty);
    });

    test('عنوان بلندتر از ۲۰۰ کاراکتر رد می‌شود', () async {
      await expectLater(
        create(title: 'ا' * 201),
        throwsA(isA<EventValidationException>()),
      );
    });

    test('پایان مساوی شروع رد می‌شود', () async {
      await expectLater(
        events.insertEvent(
          responsibilityId: respId,
          title: 'بد',
          startAt: DateTime(2026, 3, 21, 10, 0),
          endAt: DateTime(2026, 3, 21, 10, 0),
        ),
        throwsA(isA<EventValidationException>()),
      );
    });

    test('تداخل با بازه‌ی معکوس خطا می‌دهد', () async {
      await expectLater(
        events.findConflicts(
          startAt: DateTime(2026, 3, 21, 12, 0),
          endAt: DateTime(2026, 3, 21, 11, 0),
        ),
        throwsA(isA<EventValidationException>()),
      );
    });
  });

  group('تمام‌روز', () {
    test('ساعت ورودی نادیده گرفته و کل روز پوشش داده می‌شود', () async {
      final Event created = await create(
        allDay: true,
        start: DateTime(2026, 3, 21, 14, 30),
        end: DateTime(2026, 3, 21, 15, 30),
      );

      expect(created.allDay, isTrue);
      expect(created.startLocal, DateTime(2026, 3, 21));
      expect(created.endLocal, DateTime(2026, 3, 22));
      expect(created.duration, const Duration(hours: 24));
    });

    test('تبدیل رویداد ساعت‌دار به تمام‌روز، بازه را کامل می‌کند', () async {
      final Event created = await create();

      await events.updateEvent(id: created.id, allDay: true);

      final Event? updated = await events.getEventById(created.id);
      expect(updated!.allDay, isTrue);
      expect(updated.startLocal, DateTime(2026, 3, 21));
      expect(updated.endLocal, DateTime(2026, 3, 22));
    });
  });

  group('تداخل زمانی', () {
    test('همپوشانی پیدا می‌شود', () async {
      await create();

      final List<Event> conflicts = await events.findConflicts(
        startAt: DateTime(2026, 3, 21, 10, 30),
        endAt: DateTime(2026, 3, 21, 11, 30),
      );

      expect(conflicts, hasLength(1));
      expect(conflicts.single.title, 'جلسه');
    });

    test('رویدادهای چسبیده به هم تداخل ندارند', () async {
      await create();

      expect(
        await events.findConflicts(
          startAt: DateTime(2026, 3, 21, 11, 0),
          endAt: DateTime(2026, 3, 21, 12, 0),
        ),
        isEmpty,
      );
      expect(
        await events.findConflicts(
          startAt: DateTime(2026, 3, 21, 9, 0),
          endAt: DateTime(2026, 3, 21, 10, 0),
        ),
        isEmpty,
      );
    });

    test('خودِ رویداد با exclude از تداخل کنار گذاشته می‌شود', () async {
      final Event created = await create();

      final List<Event> conflicts = await events.findConflicts(
        startAt: created.startLocal,
        endAt: created.endLocal,
        excludeEventId: created.id,
      );

      expect(conflicts, isEmpty);
    });

    test('رویداد لغوشده تداخل حساب نمی‌شود', () async {
      await create(title: 'فعال');
      await create(title: 'لغوشده', status: EventStatus.cancelled);

      final List<Event> conflicts = await events.findConflicts(
        startAt: DateTime(2026, 3, 21, 10, 15),
        endAt: DateTime(2026, 3, 21, 10, 45),
      );

      expect(conflicts, hasLength(1));
      expect(conflicts.single.title, 'فعال');
    });
  });

  group('مرز نیمه‌شب', () {
    test('رویداد ۲۳:۰۰ تا ۰۰:۳۰ در هر دو روز دیده می‌شود', () async {
      await create(
        start: DateTime(2026, 3, 21, 23, 0),
        end: DateTime(2026, 3, 22, 0, 30),
      );

      expect(await events.getEventsForDay(day), hasLength(1));
      expect(
        await events.getEventsForDay(DateTime(2026, 3, 22)),
        hasLength(1),
      );
    });

    test('رویدادی که دقیقاً ۰۰:۰۰ تمام می‌شود به روز بعد سرریز نمی‌کند', () async {
      await create(
        start: DateTime(2026, 3, 21, 22, 0),
        end: DateTime(2026, 3, 22),
      );

      expect(await events.getEventsForDay(day), hasLength(1));
      expect(
        await events.getEventsForDay(DateTime(2026, 3, 22)),
        isEmpty,
      );
    });

    test('رویداد روز دیگر در این روز دیده نمی‌شود', () async {
      await create(
        start: DateTime(2026, 3, 22, 10, 0),
        end: DateTime(2026, 3, 22, 11, 0),
      );

      expect(await events.getEventsForDay(day), isEmpty);
    });
  });

  group('ویرایش', () {
    test('ویرایش عنوان زمان‌ها را دست نمی‌زند', () async {
      final Event created = await create();

      await events.updateEvent(id: created.id, title: 'جلسه‌ی فوری');

      final Event? updated = await events.getEventById(created.id);
      expect(updated!.title, 'جلسه‌ی فوری');
      expect(updated.startLocal, DateTime(2026, 3, 21, 10, 0));
      expect(updated.endLocal, DateTime(2026, 3, 21, 11, 0));
    });

    test('زمان جدید پذیرفته می‌شود', () async {
      final Event created = await create();

      await events.updateEvent(
        id: created.id,
        startAt: DateTime(2026, 3, 21, 16, 0),
        endAt: DateTime(2026, 3, 21, 17, 30),
      );

      final Event? updated = await events.getEventById(created.id);
      expect(updated!.startLocal, DateTime(2026, 3, 21, 16, 0));
      expect(updated.endLocal, DateTime(2026, 3, 21, 17, 30));
    });

    test('ویرایش با پایان قبل از شروع رد می‌شود', () async {
      final Event created = await create();

      await expectLater(
        events.updateEvent(
          id: created.id,
          endAt: DateTime(2026, 3, 21, 9, 0),
        ),
        throwsA(isA<EventValidationException>()),
      );
    });

    test('ویرایش شناسه‌ی ناموجود خطا می‌دهد', () async {
      await expectLater(
        events.updateEvent(id: 'missing', title: 'جدید'),
        throwsA(isA<EventNotFoundException>()),
      );
    });
  });

  group('حذف', () {
    test('حذف نرم رویداد را از فهرست روز برمی‌دارد', () async {
      final Event created = await create();

      await events.deleteEvent(created.id);

      expect(await events.getEventById(created.id), isNull);
      expect(await events.getEventsForDay(day), isEmpty);
    });

    test('حذف شناسه‌ی ناموجود خطا می‌دهد', () async {
      await expectLater(
        events.deleteEvent('missing'),
        throwsA(isA<EventNotFoundException>()),
      );
    });

    test('حذف فیزیکی ردیف را کاملاً پاک می‌کند', () async {
      final Event created = await create();

      await events.permanentlyDeleteEvent(created.id);

      expect(await events.getEventById(created.id), isNull);
      expect(await events.getEventsForDay(day), isEmpty);
    });
  });

  group('کلید خارجی', () {
    test('رویداد با مسئولیت ناموجود رد می‌شود', () async {
      await expectLater(
        events.insertEvent(
          responsibilityId: 'missing',
          title: 'بی‌مسئولیت',
          startAt: DateTime(2026, 3, 21, 10, 0),
          endAt: DateTime(2026, 3, 21, 11, 0),
        ),
        throwsA(anything),
      );
    });
  });
}
