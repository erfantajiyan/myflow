import 'dart:math' as math;

import '../../../database/event_repository_impl.dart';

/// بلوک یک رویداد در تایم‌لاین روزانه.
///
/// موقعیت با «دقیقه‌ی روز» بیان می‌شود، نه با ساعت؛ همین باعث می‌شود محاسبه
/// ارتفاع و تست منطق به ویجت وابسته نباشد (بخش ۷.۳ سند).
class TimelineBlock {
  const TimelineBlock({
    required this.event,
    required this.startMinute,
    required this.endMinute,
    required this.column,
    required this.columns,
  });

  final Event event;

  /// دقیقه‌ی شروع از ۰۰:۰۰، بریده‌شده در بازه‌ی همان روز.
  final int startMinute;

  /// دقیقه‌ی پایان؛ همیشه بزرگ‌تر از [startMinute].
  final int endMinute;

  /// ستون افقی در گروه رویدادهای هم‌پوشان (۰ یعنی چپ‌ترین/اولین).
  final int column;

  /// تعداد ستون‌های گروه هم‌پوشان؛ برای عرض بلوک استفاده می‌شود.
  final int columns;

  int get durationMinutes => endMinute - startMinute;

  /// نسبت موقعیت عمودی به کل روز (۰ تا ۱).
  double get topFactor => startMinute / TimelineLayout.minutesPerDay;

  /// نسبت ارتفاع به کل روز (۰ تا ۱).
  double get heightFactor => durationMinutes / TimelineLayout.minutesPerDay;
}

/// بازه‌ی آزاد روز؛ محاسبه‌شده و **ذخیره‌نشده** (بخش ۷.۳ سند).
class FreeRange {
  const FreeRange({required this.startMinute, required this.endMinute});

  final int startMinute;
  final int endMinute;

  int get durationMinutes => endMinute - startMinute;
}

/// محاسبه‌های خالص تایم‌لاین ۲۴ ساعته.
abstract final class TimelineLayout {
  static const int minutesPerDay = 24 * 60;

  /// کمترین ارتفاع مؤثر یک رویداد تا خوانا بماند (۱۵ دقیقه).
  static const int minVisibleMinutes = 15;

  /// فاصله‌های کوتاه‌تر از این مقدار به عنوان بازه‌ی آزاد گزارش نمی‌شوند تا
  /// فهرست شلوغ نشود.
  static const int minFreeRangeMinutes = 30;

  /// رویدادهای تمام‌روز جدا می‌شوند؛ در تایم‌لاین ساعت‌دار نمی‌آیند.
  static List<Event> allDayEvents(List<Event> events) => events
      .where((Event event) => event.allDay)
      .toList(growable: false);

  /// رویدادهای ساعت‌دار در فضای یک روز، با ستون‌بندی هم‌پوشانی.
  static List<TimelineBlock> blocksFor(List<Event> events, DateTime day) {
    final DateTime dayStart = DateTime(day.year, day.month, day.day);
    final List<_Draft> drafts = <_Draft>[];

    for (final Event event in events) {
      if (event.allDay) continue;
      final int rawStart = event.startLocal.difference(dayStart).inMinutes;
      final int rawEnd = event.endLocal.difference(dayStart).inMinutes;
      if (rawEnd <= 0 || rawStart >= minutesPerDay) continue;

      int start = rawStart.clamp(0, minutesPerDay);
      int end = rawEnd.clamp(0, minutesPerDay);
      if (end <= start) {
        end = math.min(start + minVisibleMinutes, minutesPerDay);
        start = math.max(0, end - minVisibleMinutes);
      } else if (end - start < minVisibleMinutes) {
        // رویداد کوتاه‌تر از ۱۵ دقیقه هم باید لمس‌پذیر و خوانا بماند.
        end = math.min(start + minVisibleMinutes, minutesPerDay);
        start = math.max(0, end - minVisibleMinutes);
      }
      if (end <= start) continue;
      drafts.add(_Draft(event: event, start: start, end: end));
    }

    drafts.sort((_Draft a, _Draft b) {
      final int byStart = a.start.compareTo(b.start);
      if (byStart != 0) return byStart;
      return a.end.compareTo(b.end);
    });
    if (drafts.isEmpty) return const <TimelineBlock>[];

    // ستون‌بندی حریصانه: هر رویداد در اولین ستونی می‌نشیند که تا شروع آن
    // خالی شده باشد.
    final List<int> columnEnds = <int>[];
    for (final _Draft draft in drafts) {
      int column = -1;
      for (int index = 0; index < columnEnds.length; index++) {
        if (columnEnds[index] <= draft.start) {
          column = index;
          break;
        }
      }
      if (column == -1) {
        column = columnEnds.length;
        columnEnds.add(draft.end);
      } else {
        columnEnds[column] = draft.end;
      }
      draft.column = column;
    }

    // هر گروه هم‌پوشان (زنجیره‌ای) عرض مشترک می‌گیرد.
    final List<TimelineBlock> blocks = <TimelineBlock>[];
    int groupStart = 0;
    int groupMaxEnd = drafts.first.end;
    int groupColumns = drafts.first.column + 1;

    void flush(int endIndex) {
      for (int index = groupStart; index < endIndex; index++) {
        final _Draft draft = drafts[index];
        blocks.add(
          TimelineBlock(
            event: draft.event,
            startMinute: draft.start,
            endMinute: draft.end,
            column: draft.column,
            columns: groupColumns,
          ),
        );
      }
    }

    for (int index = 1; index < drafts.length; index++) {
      final _Draft draft = drafts[index];
      if (draft.start >= groupMaxEnd) {
        flush(index);
        groupStart = index;
        groupMaxEnd = draft.end;
        groupColumns = draft.column + 1;
        continue;
      }
      groupMaxEnd = math.max(groupMaxEnd, draft.end);
      groupColumns = math.max(groupColumns, draft.column + 1);
    }
    flush(drafts.length);
    return blocks;
  }

  /// بازه‌های خالی روز از تفاضل ۰۰:۰۰–۲۴:۰۰ با بلوک‌های ساعت‌دار.
  static List<FreeRange> freeRanges(
    List<TimelineBlock> blocks, {
    int minMinutes = minFreeRangeMinutes,
  }) {
    if (blocks.isEmpty) {
      return const <FreeRange>[
        FreeRange(startMinute: 0, endMinute: minutesPerDay),
      ];
    }

    final List<FreeRange> busy = List<FreeRange>.of(
      blocks.map(
        (TimelineBlock block) => FreeRange(
          startMinute: block.startMinute,
          endMinute: block.endMinute,
        ),
      ),
    )..sort(
      (FreeRange a, FreeRange b) => a.startMinute.compareTo(b.startMinute),
    );

    final List<FreeRange> merged = <FreeRange>[];
    for (final FreeRange range in busy) {
      if (merged.isEmpty) {
        merged.add(range);
        continue;
      }
      final FreeRange last = merged.last;
      if (range.startMinute <= last.endMinute) {
        if (range.endMinute > last.endMinute) {
          merged[merged.length - 1] = FreeRange(
            startMinute: last.startMinute,
            endMinute: range.endMinute,
          );
        }
        continue;
      }
      merged.add(range);
    }

    final List<FreeRange> free = <FreeRange>[];
    int cursor = 0;
    for (final FreeRange range in merged) {
      if (range.startMinute - cursor >= minMinutes) {
        free.add(FreeRange(startMinute: cursor, endMinute: range.startMinute));
      }
      cursor = math.max(cursor, range.endMinute);
    }
    if (minutesPerDay - cursor >= minMinutes) {
      free.add(FreeRange(startMinute: cursor, endMinute: minutesPerDay));
    }
    return free;
  }

  /// مجموع دقیقه‌های آزاد روز.
  static int totalFreeMinutes(List<FreeRange> ranges) => ranges.fold(
    0,
    (int sum, FreeRange range) => sum + range.durationMinutes,
  );
}

class _Draft {
  _Draft({required this.event, required this.start, required this.end});

  final Event event;
  final int start;
  final int end;
  int column = 0;
}
