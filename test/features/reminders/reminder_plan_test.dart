import 'package:flutter_test/flutter_test.dart';
import 'package:myflow/features/reminders/domain/reminder_plan.dart';

void main() {
  ReminderTarget target({
    required List<DateTime> starts,
    int minutesBefore = 10,
    String reminderId = 'rem-1',
  }) {
    return ReminderTarget(
      reminderId: reminderId,
      parentId: 'evt-1',
      title: 'کلاس',
      body: 'شروع کلاس',
      minutesBefore: minutesBefore,
      occurrences: <ReminderOccurrence>[
        for (final DateTime start in starts)
          ReminderOccurrence(instanceKey: start.toIso8601String(), startLocal: start),
      ],
    );
  }

  test('فاصله‌ی یادآوری از شروع کم می‌شود', () {
    final DateTime now = DateTime(2026, 11, 9, 8);
    final List<PlannedReminder> plan = buildReminderPlan(
      targets: <ReminderTarget>[
        target(starts: <DateTime>[DateTime(2026, 11, 9, 10)], minutesBefore: 15),
      ],
      now: now,
    );

    expect(plan, hasLength(1));
    expect(plan.single.whenLocal, DateTime(2026, 11, 9, 9, 45));
    expect(plan.single.whenUtc.isUtc, isTrue);
  });

  test('لحظه‌های گذشته ثبت نمی‌شوند', () {
    final DateTime now = DateTime(2026, 11, 9, 8);
    final List<PlannedReminder> plan = buildReminderPlan(
      targets: <ReminderTarget>[
        target(
          starts: <DateTime>[
            DateTime(2026, 11, 9, 7, 30),
            DateTime(2026, 11, 9, 8, 5),
            DateTime(2026, 11, 9, 9),
          ],
        ),
      ],
      now: now,
    );

    expect(plan, hasLength(1));
    expect(plan.single.whenLocal, DateTime(2026, 11, 9, 8, 50));
  });

  test('فقط پنجره‌ی لغزان ثبت می‌شود', () {
    final DateTime now = DateTime(2026, 11, 9, 8);
    final List<PlannedReminder> plan = buildReminderPlan(
      targets: <ReminderTarget>[
        target(
          starts: <DateTime>[
            now.add(const Duration(days: 13)),
            now.add(const Duration(days: 15)),
          ],
          minutesBefore: 0,
        ),
      ],
      now: now,
    );

    expect(plan, hasLength(1));
    expect(plan.single.whenLocal, now.add(const Duration(days: 13)));
  });

  test('شناسه‌ی اعلان قطعی و یکتاست', () {
    final int first = notificationIdFor('rem-a', '2026-11-09');
    final int again = notificationIdFor('rem-a', '2026-11-09');
    final int other = notificationIdFor('rem-a', '2026-11-16');

    expect(first, again);
    expect(first, isNot(other));
    expect(first, greaterThan(0));
    expect(first, lessThan(1 << 31));
    expect(notificationIdFor('', ''), greaterThan(0));
  });

  test('هر شناسه فقط یک بار و خروجی مرتب است', () {
    final DateTime now = DateTime(2026, 11, 9, 8);
    final List<PlannedReminder> plan = buildReminderPlan(
      targets: <ReminderTarget>[
        target(starts: <DateTime>[DateTime(2026, 11, 10, 9)]),
        target(starts: <DateTime>[DateTime(2026, 11, 10, 9)]),
        target(
          reminderId: 'rem-2',
          starts: <DateTime>[DateTime(2026, 11, 9, 12)],
        ),
      ],
      now: now,
    );

    expect(plan, hasLength(2));
    expect(
      plan.first.whenLocal.isBefore(plan.last.whenLocal),
      isTrue,
      reason: 'برنامه باید بر اساس زمان صعودی مرتب باشد',
    );
  });

  test('سقف تعداد اعلان رعایت می‌شود', () {
    final DateTime now = DateTime(2026, 11, 9, 8);
    final List<DateTime> starts = <DateTime>[
      for (int i = 0; i < 80; i++) now.add(Duration(hours: i + 1)),
    ];
    final List<PlannedReminder> plan = buildReminderPlan(
      targets: <ReminderTarget>[target(starts: starts, minutesBefore: 0)],
      now: now,
      maxNotifications: 60,
    );

    expect(plan, hasLength(60));
    expect(plan.first.whenLocal, now.add(const Duration(hours: 1)));
  });
}
