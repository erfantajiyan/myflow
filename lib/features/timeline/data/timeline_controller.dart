import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date_time/jalali_date_service.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/providers/data_revision_provider.dart';
import '../../../database/event_repository_impl.dart';
import '../../events/data/events_controller.dart';

/// روزی که تایم‌لاین نشان می‌دهد (بدون ساعت، به وقت محلی).
final NotifierProvider<TimelineDayController, DateTime> timelineDayProvider =
    NotifierProvider<TimelineDayController, DateTime>(
      TimelineDayController.new,
    );

class TimelineDayController extends Notifier<DateTime> {
  @override
  DateTime build() {
    final DateTime now = ref.watch(nowProvider)();
    return DateTime(now.year, now.month, now.day);
  }

  void select(DateTime day) {
    state = DateTime(day.year, day.month, day.day);
  }

  void previousDay() => _shift(-1);

  void nextDay() => _shift(1);

  void goToToday() => select(ref.read(nowProvider)());

  void _shift(int days) {
    final JalaliDateService dates = ref.read(jalaliDateServiceProvider);
    select(dates.addDays(state, days));
  }
}

/// فیلتر مسئولیت تایم‌لاین؛ `null` یعنی همه.
final NotifierProvider<TimelineFilterController, String?>
timelineResponsibilityFilterProvider =
    NotifierProvider<TimelineFilterController, String?>(
      TimelineFilterController.new,
    );

class TimelineFilterController extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? responsibilityId) => state = responsibilityId;
}

/// رویدادهای روز انتخابی تایم‌لاین، با فیلتر مسئولیت.
final AsyncNotifierProvider<TimelineEventsController, List<Event>>
timelineEventsProvider =
    AsyncNotifierProvider<TimelineEventsController, List<Event>>(
      TimelineEventsController.new,
    );

class TimelineEventsController extends AsyncNotifier<List<Event>> {
  @override
  Future<List<Event>> build() async {
    ref.watch(dataRevisionProvider);
    final DateTime day = ref.watch(timelineDayProvider);
    final String? responsibilityId = ref.watch(
      timelineResponsibilityFilterProvider,
    );

    final List<Event> events = await ref
        .read(eventRepositoryProvider)
        .getEventsForDay(day);
    if (responsibilityId == null) {
      return events;
    }
    return events
        .where(
          (Event event) => event.responsibilityId == responsibilityId,
        )
        .toList(growable: false);
  }

  /// بازخوانی پس از افزودن/ویرایش/حذف رویداد.
  void refresh() => ref.invalidateSelf();
}
