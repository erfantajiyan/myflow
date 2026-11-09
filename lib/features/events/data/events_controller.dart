import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/providers/data_revision_provider.dart';
import '../../../database/database_providers.dart';
import '../../../database/event_repository_impl.dart';
import '../../../shared/enums/app_enums.dart';

/// تنها مسیر دسترسی UI به repository رویدادها.
final Provider<EventRepository> eventRepositoryProvider =
    Provider<EventRepository>((Ref ref) {
      return DriftEventRepository(ref.watch(appDatabaseProvider));
    });

/// روزی که صفحه‌ی رویدادها نشان می‌دهد (بدون ساعت، به وقت محلی).
final NotifierProvider<SelectedEventDay, DateTime> selectedEventDayProvider =
    NotifierProvider<SelectedEventDay, DateTime>(SelectedEventDay.new);

class SelectedEventDay extends Notifier<DateTime> {
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

  void _shift(int days) {
    final DateTime shifted = ref
        .read(jalaliDateServiceProvider)
        .addDays(state, days);
    select(shifted);
  }
}

/// رویدادهای روز انتخاب‌شده.
final AsyncNotifierProvider<DayEventsController, List<Event>> dayEventsProvider =
    AsyncNotifierProvider<DayEventsController, List<Event>>(
      DayEventsController.new,
    );

class DayEventsController extends AsyncNotifier<List<Event>> {
  EventRepository get _repository => ref.read(eventRepositoryProvider);

  @override
  Future<List<Event>> build() async {
    final DateTime day = ref.watch(selectedEventDayProvider);
    return ref.watch(eventRepositoryProvider).getEventsForDay(day);
  }

  Future<void> refresh() async {
    final DateTime day = ref.read(selectedEventDayProvider);
    state = AsyncData<List<Event>>(await _repository.getEventsForDay(day));
  }

  /// تداخل‌های بازه‌ی داده‌شده، برای هشدار پیش از ذخیره.
  Future<List<Event>> conflictsFor({
    required DateTime startAt,
    required DateTime endAt,
    String? excludeEventId,
  }) {
    return _repository.findConflicts(
      startAt: startAt,
      endAt: endAt,
      excludeEventId: excludeEventId,
    );
  }

  /// ساخت رویداد و رفتن به روز همان رویداد.
  Future<Event> create({
    required String responsibilityId,
    required String title,
    required DateTime startAt,
    required DateTime endAt,
    bool allDay = false,
    String? description,
    String? location,
    EventStatus status = EventStatus.planned,
  }) async {
    final Event created = await _repository.insertEvent(
      responsibilityId: responsibilityId,
      title: title,
      startAt: startAt,
      endAt: endAt,
      allDay: allDay,
      description: description,
      location: location,
      status: status,
    );
    ref.read(selectedEventDayProvider.notifier).select(created.startLocal);
    ref.read(dataRevisionProvider.notifier).bump();
    await refresh();
    return created;
  }

  Future<void> updateEvent({
    required String id,
    String? responsibilityId,
    String? title,
    String? description,
    String? location,
    DateTime? startAt,
    DateTime? endAt,
    bool? allDay,
    EventStatus? status,
  }) async {
    await _repository.updateEvent(
      id: id,
      responsibilityId: responsibilityId,
      title: title,
      description: description,
      location: location,
      startAt: startAt,
      endAt: endAt,
      allDay: allDay,
      status: status,
    );
    ref.read(dataRevisionProvider.notifier).bump();
    await refresh();
  }

  Future<void> delete(String id) async {
    await _repository.deleteEvent(id);
    ref.read(dataRevisionProvider.notifier).bump();
    await refresh();
  }
}
