import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date_time/jalali_date_parts.dart';
import '../../../core/date_time/jalali_date_service.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/providers/data_revision_provider.dart';
import '../../../database/event_repository_impl.dart';
import '../../../database/task_repository_impl.dart';
import '../../events/data/events_controller.dart';
import '../../tasks/data/tasks_controller.dart';

/// نمای فعال تقویم — بخش ۷.۲ سند (نمای ماهانه و هفتگی).
enum CalendarViewMode {
  month('ماه'),
  week('هفته');

  const CalendarViewMode(this.label);

  final String label;
}

/// ماهی که تقویم نشان می‌دهد؛ همیشه روز اول همان ماه شمسی.
final NotifierProvider<CalendarMonthController, DateTime> calendarMonthProvider =
    NotifierProvider<CalendarMonthController, DateTime>(
      CalendarMonthController.new,
    );

class CalendarMonthController extends Notifier<DateTime> {
  JalaliDateService get _dates => ref.read(jalaliDateServiceProvider);

  @override
  DateTime build() {
    final JalaliDateService dates = ref.watch(jalaliDateServiceProvider);
    final DateTime now = ref.watch(nowProvider)();
    return firstDayOfMonth(dates, now);
  }

  /// رفتن به ماهی که [day] در آن است و انتخاب روز اول آن ماه.
  ///
  /// با تغییر ماه، انتخاب قبلی که به ماه دیگر تعلق دارد بی‌معنا می‌شود؛ پس
  /// انتخاب روی روز اول ماه جدید می‌نشیند تا خلاصه‌ی روز همیشه با شبکه
  /// هم‌خوان باشد.
  void selectMonthOf(DateTime day) {
    final DateTime target = firstDayOfMonth(_dates, day);
    state = target;
    ref.read(calendarSelectedDayProvider.notifier).select(target);
  }

  void previous() {
    final DateTime previousMonth = firstDayOfMonth(
      _dates,
      _dates.addMonths(state, -1),
    );
    state = previousMonth;
    ref.read(calendarSelectedDayProvider.notifier).select(previousMonth);
  }

  void next() {
    final DateTime nextMonth = firstDayOfMonth(
      _dates,
      _dates.addMonths(state, 1),
    );
    state = nextMonth;
    ref.read(calendarSelectedDayProvider.notifier).select(nextMonth);
  }

  void goToToday() {
    final DateTime now = ref.read(nowProvider)();
    state = firstDayOfMonth(_dates, now);
    ref.read(calendarSelectedDayProvider.notifier).select(now);
  }
}

/// روز اول ماه شمسیِ تاریخ داده‌شده، بدون ساعت.
DateTime firstDayOfMonth(JalaliDateService dates, DateTime day) {
  final JalaliDateParts parts = dates.partsOf(day);
  return dates.toDateTime(
    JalaliDateParts(year: parts.year, month: parts.month, day: 1),
  );
}

/// روز انتخاب‌شده در تقویم (بدون ساعت، به وقت محلی).
final NotifierProvider<CalendarSelectedDayController, DateTime>
calendarSelectedDayProvider =
    NotifierProvider<CalendarSelectedDayController, DateTime>(
      CalendarSelectedDayController.new,
    );

class CalendarSelectedDayController extends Notifier<DateTime> {
  @override
  DateTime build() {
    final DateTime now = ref.watch(nowProvider)();
    return DateTime(now.year, now.month, now.day);
  }

  void select(DateTime day) {
    state = DateTime(day.year, day.month, day.day);
  }
}

/// نمای فعال ماه/هفته.
final NotifierProvider<CalendarViewModeController, CalendarViewMode>
calendarViewModeProvider =
    NotifierProvider<CalendarViewModeController, CalendarViewMode>(
      CalendarViewModeController.new,
    );

class CalendarViewModeController extends Notifier<CalendarViewMode> {
  @override
  CalendarViewMode build() => CalendarViewMode.month;

  void select(CalendarViewMode mode) => state = mode;
}

/// فیلتر مسئولیت تقویم؛ `null` یعنی همه‌ی مسئولیت‌ها.
final NotifierProvider<CalendarFilterController, String?>
calendarResponsibilityFilterProvider =
    NotifierProvider<CalendarFilterController, String?>(
      CalendarFilterController.new,
    );

class CalendarFilterController extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? responsibilityId) => state = responsibilityId;
}

/// فعالیت یک روز: رویدادها و وظایف همان روز.
class CalendarDayActivity {
  const CalendarDayActivity({
    this.events = const <Event>[],
    this.tasks = const <Task>[],
  });

  static const CalendarDayActivity empty = CalendarDayActivity();

  final List<Event> events;
  final List<Task> tasks;

  bool get isEmpty => events.isEmpty && tasks.isEmpty;

  /// رویدادهای لغوشده هم نمایش داده می‌شوند (با خط‌خوردگی) ولی شمارش
  /// برنامه‌ی روز فقط رویدادهای معتبر را می‌شمارد.
  int get activeEventCount =>
      events.where((Event event) => !event.isCancelled).length;

  int get pendingTaskCount => tasks
      .where((Task task) => !task.isCompleted && !task.isCancelled)
      .length;
}

/// فعالیت روزهای بازه‌ی نمای فعلی، با کلید تاریخ محلی بدون ساعت.
final AsyncNotifierProvider<
  CalendarActivityController,
  Map<DateTime, CalendarDayActivity>
>
calendarActivityProvider =
    AsyncNotifierProvider<
      CalendarActivityController,
      Map<DateTime, CalendarDayActivity>
    >(CalendarActivityController.new);

class CalendarActivityController
    extends AsyncNotifier<Map<DateTime, CalendarDayActivity>> {
  @override
  Future<Map<DateTime, CalendarDayActivity>> build() async {
    ref.watch(dataRevisionProvider);
    final JalaliDateService dates = ref.watch(jalaliDateServiceProvider);
    final CalendarViewMode mode = ref.watch(calendarViewModeProvider);
    final DateTime month = ref.watch(calendarMonthProvider);
    final DateTime selected = ref.watch(calendarSelectedDayProvider);
    final String? responsibilityId = ref.watch(
      calendarResponsibilityFilterProvider,
    );

    final (DateTime from, DateTime to) = _visibleRange(
      dates: dates,
      mode: mode,
      month: month,
      selected: selected,
    );

    return _load(
      dates: dates,
      from: from,
      to: to,
      responsibilityId: responsibilityId,
    );
  }

  /// بازه‌ی روزهایی که کاربر می‌بیند: کل شبکه‌ی ماه (با روزهای ماه قبل/بعد)
  /// یا هفته‌ی روز انتخاب‌شده.
  static (DateTime, DateTime) _visibleRange({
    required JalaliDateService dates,
    required CalendarViewMode mode,
    required DateTime month,
    required DateTime selected,
  }) {
    switch (mode) {
      case CalendarViewMode.month:
        final JalaliDateParts parts = dates.partsOf(month);
        final List<List<JalaliMonthCell>> grid = dates.monthGrid(
          parts.year,
          parts.month,
        );
        return (grid.first.first.date, grid.last.last.date);
      case CalendarViewMode.week:
        final DateTime weekStart = _dayOnly(dates.startOfWeek(selected));
        return (weekStart, dates.addDays(weekStart, 6));
    }
  }

  Future<Map<DateTime, CalendarDayActivity>> _load({
    required JalaliDateService dates,
    required DateTime from,
    required DateTime to,
    required String? responsibilityId,
  }) async {
    final List<Event> events = await ref
        .read(eventRepositoryProvider)
        .getEventsInRange(fromDay: from, toDay: to);
    final List<Task> tasks = await ref
        .read(taskRepositoryProvider)
        .getTasksDueBetween(fromDay: from, toDay: to);

    // فیلتر در حافظه اعمال می‌شود: کوئری بازه فقط یک بار به دیتابیس می‌زند
    // و حجم یک ماه در بدترین حالت چند صد ردیف است.
    final List<Event> visibleEvents = responsibilityId == null
        ? events
        : events
              .where((Event event) => event.responsibilityId == responsibilityId)
              .toList(growable: false);
    final List<Task> visibleTasks = responsibilityId == null
        ? tasks
        : tasks
              .where((Task task) => task.responsibilityId == responsibilityId)
              .toList(growable: false);

    final Map<DateTime, List<Event>> eventsByDay = <DateTime, List<Event>>{};
    for (final Event event in visibleEvents) {
      for (final DateTime day in _daysCoveredBy(
        event: event,
        dates: dates,
        from: from,
        to: to,
      )) {
        (eventsByDay[day] ??= <Event>[]).add(event);
      }
    }

    final Map<DateTime, List<Task>> tasksByDay = <DateTime, List<Task>>{};
    for (final Task task in visibleTasks) {
      final DateTime? due = task.dueDateLocal;
      if (due == null) continue;
      final DateTime key = _dayOnly(due);
      if (key.isBefore(from) || key.isAfter(to)) continue;
      (tasksByDay[key] ??= <Task>[]).add(task);
    }

    final Set<DateTime> days = <DateTime>{
      ...eventsByDay.keys,
      ...tasksByDay.keys,
    };

    final Map<DateTime, CalendarDayActivity> result =
        <DateTime, CalendarDayActivity>{};
    for (final DateTime day in days) {
      final List<Event> dayEvents = eventsByDay[day] ?? const <Event>[];
      final List<Event> sortedEvents = List<Event>.of(dayEvents)
        ..sort(_compareEvents);
      final List<Task> dayTasks = tasksByDay[day] ?? const <Task>[];
      final List<Task> sortedTasks = List<Task>.of(dayTasks)..sort(_compareTasks);
      result[day] = CalendarDayActivity(
        events: sortedEvents,
        tasks: sortedTasks,
      );
    }
    return result;
  }

  /// روزهایی از بازه که این رویداد با آن‌ها هم‌پوشانی دارد.
  ///
  /// رویداد عبوری از نیمه‌شب در هر دو روز دیده می‌شود و رویدادی که دقیقاً
  /// نیمه‌شب تمام می‌شود به روز بعد سرریز نمی‌کند (بازه‌ی نیم‌باز).
  static Iterable<DateTime> _daysCoveredBy({
    required Event event,
    required JalaliDateService dates,
    required DateTime from,
    required DateTime to,
  }) sync* {
    final DateTime firstDay = _dayOnly(event.startLocal);
    final DateTime lastMoment = event.endLocal.subtract(
      const Duration(milliseconds: 1),
    );
    final DateTime lastDay = _dayOnly(
      lastMoment.isBefore(event.startLocal) ? event.startLocal : lastMoment,
    );

    DateTime cursor = firstDay.isBefore(from) ? from : firstDay;
    final DateTime limit = lastDay.isAfter(to) ? to : lastDay;
    while (!cursor.isAfter(limit)) {
      yield cursor;
      cursor = dates.addDays(cursor, 1);
    }
  }

  /// فعالیت روز داده‌شده از نقشه‌ی بارگذاری‌شده.
  static CalendarDayActivity activityFor(
    Map<DateTime, CalendarDayActivity> map,
    DateTime day,
  ) {
    return map[_dayOnly(day)] ?? CalendarDayActivity.empty;
  }
}

DateTime _dayOnly(DateTime date) =>
    DateTime(date.year, date.month, date.day);

int _compareEvents(Event a, Event b) {
  if (a.allDay != b.allDay) {
    return a.allDay ? -1 : 1;
  }
  final int byStart = a.startLocal.compareTo(b.startLocal);
  if (byStart != 0) return byStart;
  return a.title.compareTo(b.title);
}

int _compareTasks(Task a, Task b) {
  final int byTime = (a.dueTime ?? '').compareTo(b.dueTime ?? '');
  if (byTime != 0) return byTime;
  return a.title.compareTo(b.title);
}
