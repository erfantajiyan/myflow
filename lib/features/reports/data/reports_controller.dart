import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date_time/jalali_date_parts.dart';
import '../../../core/date_time/jalali_date_service.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/providers/data_revision_provider.dart';
import '../../../database/report_repository_impl.dart';
import '../../events/data/events_controller.dart';
import '../../projects/data/projects_controller.dart';
import '../../responsibilities/data/responsibilities_controller.dart';
import '../../tasks/data/tasks_controller.dart';
import '../domain/report_data.dart';

/// تنها مسیر دسترسی UI به گزارش‌ها.
final Provider<ReportRepository> reportRepositoryProvider =
    Provider<ReportRepository>((Ref ref) {
      return DriftReportRepository(
        eventRepository: ref.watch(eventRepositoryProvider),
        taskRepository: ref.watch(taskRepositoryProvider),
        projectRepository: ref.watch(projectRepositoryProvider),
        responsibilityRepository: ref.watch(responsibilityRepositoryProvider),
      );
    });

/// ماه شمسی انتخاب‌شده در صفحه‌ی گزارش؛ همیشه روز اول آن ماه است.
final NotifierProvider<ReportMonthController, DateTime> reportMonthProvider =
    NotifierProvider<ReportMonthController, DateTime>(
      ReportMonthController.new,
    );

class ReportMonthController extends Notifier<DateTime> {
  JalaliDateService get _dates => ref.read(jalaliDateServiceProvider);

  @override
  DateTime build() {
    final DateTime now = ref.watch(nowProvider)();
    return _firstDayOfMonth(now);
  }

  void previous() => state = _shiftMonth(state, -1);

  void next() => state = _shiftMonth(state, 1);

  void select(DateTime day) => state = _firstDayOfMonth(day);

  DateTime _firstDayOfMonth(DateTime day) {
    final JalaliDateParts parts = _dates.partsOf(day);
    return _dates.toDateTime(
      JalaliDateParts(year: parts.year, month: parts.month, day: 1),
    );
  }

  DateTime _shiftMonth(DateTime monthStart, int delta) {
    final JalaliDateParts parts = _dates.partsOf(monthStart);
    int year = parts.year;
    int month = parts.month + delta;
    if (month > 12) {
      month = 1;
      year++;
    } else if (month < 1) {
      month = 12;
      year--;
    }
    return _dates.toDateTime(JalaliDateParts(year: year, month: month, day: 1));
  }
}

/// شروع ماه بعد؛ برای بازه‌ی نیم‌باز گزارش.
final reportRangeEndProvider =
    Provider.family<DateTime, DateTime>((Ref ref, DateTime monthStart) {
      final JalaliDateService dates = ref.watch(jalaliDateServiceProvider);
      final JalaliDateParts parts = dates.partsOf(monthStart);
      int year = parts.year;
      int month = parts.month + 1;
      if (month > 12) {
        month = 1;
        year++;
      }
      return dates.toDateTime(
        JalaliDateParts(year: year, month: month, day: 1),
      );
    });

/// گزارش ماه انتخاب‌شده.
final AsyncNotifierProvider<ReportsController, ReportData> reportsProvider =
    AsyncNotifierProvider<ReportsController, ReportData>(
      ReportsController.new,
    );

class ReportsController extends AsyncNotifier<ReportData> {
  @override
  Future<ReportData> build() async {
    final DateTime monthStart = ref.watch(reportMonthProvider);
    final DateTime rangeEnd = ref.watch(reportRangeEndProvider(monthStart));
    // هر تغییر داده باید اعداد گزارش را تازه کند.
    ref.watch(dataRevisionProvider);
    final DateTime now = ref.watch(nowProvider)();
    return ref
        .watch(reportRepositoryProvider)
        .buildReport(
          rangeStart: monthStart,
          rangeEnd: rangeEnd,
          today: now,
        );
  }

  Future<void> refresh() async {
    state = const AsyncLoading<ReportData>();
    state = await AsyncValue.guard(build);
  }
}
