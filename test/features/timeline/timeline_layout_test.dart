import 'package:flutter_test/flutter_test.dart';
import 'package:myflow/database/event_repository_impl.dart';
import 'package:myflow/features/timeline/presentation/timeline_layout.dart';
import 'package:myflow/shared/enums/app_enums.dart';

void main() {
  final DateTime day = DateTime(2026, 3, 21);

  Event event({
    String title = 'رویداد',
    required DateTime start,
    required DateTime end,
    bool allDay = false,
  }) {
    return Event(
      id: title,
      responsibilityId: 'resp-1',
      title: title,
      startAtUtc: start.toUtc(),
      endAtUtc: end.toUtc(),
      timezoneId: 'Asia/Tehran',
      allDay: allDay,
      status: EventStatus.planned,
      createdAt: DateTime(2026, 3, 1),
      updatedAt: DateTime(2026, 3, 1),
    );
  }

  group('بلوک‌های تایم‌لاین', () {
    test('رویداد عادی موقعیت و ارتفاع درست می‌گیرد', () {
      final List<TimelineBlock> blocks = TimelineLayout.blocksFor(<Event>[
        event(
          title: 'کلاس',
          start: DateTime(2026, 3, 21, 9, 30),
          end: DateTime(2026, 3, 21, 11, 0),
        ),
      ], day);

      expect(blocks, hasLength(1));
      expect(blocks.single.startMinute, 9 * 60 + 30);
      expect(blocks.single.endMinute, 11 * 60);
      expect(blocks.single.columns, 1);
      expect(blocks.single.column, 0);
      expect(blocks.single.heightFactor, closeTo(90 / 1440, 0.0001));
    });

    test('رویداد عبوری از نیمه‌شب در همان روز تا ۲۴:۰۰ بریده می‌شود', () {
      final List<TimelineBlock> blocks = TimelineLayout.blocksFor(<Event>[
        event(
          title: 'شبانه',
          start: DateTime(2026, 3, 21, 23, 0),
          end: DateTime(2026, 3, 22, 0, 30),
        ),
      ], day);

      expect(blocks.single.startMinute, 23 * 60);
      expect(blocks.single.endMinute, 24 * 60);
      expect(blocks.single.topFactor, closeTo(1380 / 1440, 0.0001));
    });

    test('رویداد شب قبل از ۰۰:۰۰ شروع روز بریده می‌شود', () {
      final List<TimelineBlock> blocks = TimelineLayout.blocksFor(<Event>[
        event(
          title: 'ادامه‌ی شبانه',
          start: DateTime(2026, 3, 20, 23, 0),
          end: DateTime(2026, 3, 21, 2, 0),
        ),
      ], day);

      expect(blocks.single.startMinute, 0);
      expect(blocks.single.endMinute, 120);
    });

    test('رویداد تمام‌روز وارد محور ساعت‌دار نمی‌شود', () {
      final Event allDay = event(
        title: 'تعطیل',
        start: DateTime(2026, 3, 21),
        end: DateTime(2026, 3, 22),
        allDay: true,
      );

      expect(TimelineLayout.blocksFor(<Event>[allDay], day), isEmpty);
      expect(TimelineLayout.allDayEvents(<Event>[allDay]), hasLength(1));
      expect(
        TimelineLayout.freeRanges(
          TimelineLayout.blocksFor(<Event>[allDay], day),
        ).single.startMinute,
        0,
      );
    });

    test('رویداد کوتاه‌تر از ۱۵ دقیقه قابل مشاهده می‌ماند', () {
      final List<TimelineBlock> blocks = TimelineLayout.blocksFor(<Event>[
        event(
          title: 'کوتاه',
          start: DateTime(2026, 3, 21, 8, 0),
          end: DateTime(2026, 3, 21, 8, 5),
        ),
      ], day);

      expect(blocks.single.durationMinutes, greaterThanOrEqualTo(15));
    });

    test('دو رویداد هم‌پوشان دو ستون می‌گیرند', () {
      final List<TimelineBlock> blocks = TimelineLayout.blocksFor(<Event>[
        event(
          title: 'الف',
          start: DateTime(2026, 3, 21, 9, 0),
          end: DateTime(2026, 3, 21, 10, 0),
        ),
        event(
          title: 'ب',
          start: DateTime(2026, 3, 21, 9, 30),
          end: DateTime(2026, 3, 21, 10, 30),
        ),
      ], day);

      expect(blocks, hasLength(2));
      expect(blocks.every((TimelineBlock block) => block.columns == 2), isTrue);
      expect(
        blocks.map((TimelineBlock block) => block.column),
        <int>[0, 1],
      );
    });

    test('رویداد پشت‌سرهم ستون کامل نمی‌گیرد', () {
      final List<TimelineBlock> blocks = TimelineLayout.blocksFor(<Event>[
        event(
          title: 'الف',
          start: DateTime(2026, 3, 21, 9, 0),
          end: DateTime(2026, 3, 21, 10, 0),
        ),
        event(
          title: 'ب',
          start: DateTime(2026, 3, 21, 9, 30),
          end: DateTime(2026, 3, 21, 10, 30),
        ),
        event(
          title: 'ج',
          start: DateTime(2026, 3, 21, 10, 30),
          end: DateTime(2026, 3, 21, 11, 0),
        ),
      ], day);

      final TimelineBlock third = blocks.firstWhere(
        (TimelineBlock block) => block.event.title == 'ج',
      );
      expect(third.columns, 1);
      expect(third.column, 0);
    });
  });

  group('بازه‌های آزاد', () {
    test('روز خالی یک بازه‌ی کامل آزاد دارد', () {
      final List<FreeRange> free = TimelineLayout.freeRanges(
        const <TimelineBlock>[],
      );

      expect(free, hasLength(1));
      expect(free.single.startMinute, 0);
      expect(free.single.endMinute, 1440);
    });

    test('تفاضل روز با رویدادها درست حساب می‌شود', () {
      final List<TimelineBlock> blocks = TimelineLayout.blocksFor(<Event>[
        event(
          title: 'کلاس',
          start: DateTime(2026, 3, 21, 9, 0),
          end: DateTime(2026, 3, 21, 10, 0),
        ),
      ], day);

      final List<FreeRange> free = TimelineLayout.freeRanges(blocks);

      expect(free, hasLength(2));
      expect(free.first.startMinute, 0);
      expect(free.first.endMinute, 9 * 60);
      expect(free.last.startMinute, 10 * 60);
      expect(free.last.endMinute, 1440);
      expect(TimelineLayout.totalFreeMinutes(free), 1380);
    });

    test('فاصله‌ی کوتاه‌تر از حد، بازه‌ی آزاد جدا نمی‌سازد', () {
      final List<TimelineBlock> blocks = TimelineLayout.blocksFor(<Event>[
        event(
          title: 'الف',
          start: DateTime(2026, 3, 21, 9, 0),
          end: DateTime(2026, 3, 21, 10, 0),
        ),
        event(
          title: 'ب',
          start: DateTime(2026, 3, 21, 10, 15),
          end: DateTime(2026, 3, 21, 11, 0),
        ),
      ], day);

      final List<FreeRange> free = TimelineLayout.freeRanges(blocks);

      expect(free, hasLength(2));
      expect(free.first.endMinute, 9 * 60);
      expect(free.last.startMinute, 11 * 60);
    });
  });
}
