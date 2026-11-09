import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/date_time/jalali_date_parts.dart';
import '../../../core/date_time/jalali_date_service.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../database/event_repository_impl.dart';
import '../../../shared/enums/app_enums.dart';
import '../../../database/responsibility_repository_impl.dart';
import '../../recurrence/domain/recurrence_rule.dart';
import '../../recurrence/presentation/recurrence_scope_dialog.dart';
import '../../responsibilities/data/responsibilities_controller.dart';
import '../data/events_controller.dart';

/// خروجی فرم رویداد.
enum EventEditorResult { created, updated }

const Key eventEditorFormKey = Key('eventEditorForm');
const Key eventEditorTitleKey = Key('eventEditorTitle');
const Key eventEditorDateKey = Key('eventEditorDate');
const Key eventEditorStartKey = Key('eventEditorStart');
const Key eventEditorEndKey = Key('eventEditorEnd');
const Key eventEditorRecurrenceKey = Key('eventEditorRecurrence');
const Key eventEditorIntervalKey = Key('eventEditorInterval');
const Key eventEditorUntilKey = Key('eventEditorUntil');

/// تبدیل ارقام فارسی/عربی به لاتین تا ورودی کاربر قابل تجزیه باشد.
String _toLatinDigits(String input) {
  const String persian = '۰۱۲۳۴۵۶۷۸۹';
  const String arabic = '٠١٢٣٤٥٦٧٨٩';
  final StringBuffer buffer = StringBuffer();
  for (final int rune in input.runes) {
    final String char = String.fromCharCode(rune);
    final int persianIndex = persian.indexOf(char);
    if (persianIndex >= 0) {
      buffer.write(persianIndex);
      continue;
    }
    final int arabicIndex = arabic.indexOf(char);
    if (arabicIndex >= 0) {
      buffer.write(arabicIndex);
      continue;
    }
    buffer.write(char);
  }
  return buffer.toString();
}

/// تجزیه‌ی تاریخ شمسی `YYYY/MM/DD` (ارقام فارسی هم پذیرفته می‌شود).
DateTime? parseJalaliDateInput(String raw, JalaliDateService dates) {
  final List<String> parts = _toLatinDigits(raw)
      .trim()
      .split(RegExp(r'[/\-.]'))
      .map((String part) => part.trim())
      .toList();
  if (parts.length != 3) {
    return null;
  }
  final int? year = int.tryParse(parts[0]);
  final int? month = int.tryParse(parts[1]);
  final int? day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) {
    return null;
  }
  if (!dates.isValid(year, month, day)) {
    return null;
  }
  return dates.toDateTime(
    JalaliDateParts(year: year, month: month, day: day),
  );
}

/// تجزیه‌ی ساعت `HH:MM` به دقیقه‌ی روز.
int? parseTimeOfDayInput(String raw) {
  final List<String> parts = _toLatinDigits(raw)
      .trim()
      .replaceAll('.', ':')
      .replaceAll('٫', ':')
      .split(':');
  if (parts.length != 2) {
    return null;
  }
  final int? hour = int.tryParse(parts[0].trim());
  final int? minute = int.tryParse(parts[1].trim());
  if (hour == null || minute == null) {
    return null;
  }
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return null;
  }
  return (hour * 60) + minute;
}

String _formatMinutes(int minutes) {
  final String hour = (minutes ~/ 60).toString().padLeft(2, '0');
  final String minute = (minutes % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}

DateTime _atMinutes(DateTime day, int minutes) => DateTime(
  day.year,
  day.month,
  day.day,
  minutes ~/ 60,
  minutes % 60,
);

DateTime _midnight(DateTime day) => DateTime(day.year, day.month, day.day);

DateTime _nextMidnight(DateTime day) =>
    DateTime(day.year, day.month, day.day + 1);

/// فرم مشترک ساخت و ویرایش رویداد.
class EventEditorSheet extends ConsumerStatefulWidget {
  const EventEditorSheet({
    super.key,
    required this.initialDate,
    this.existing,
    this.initialStartMinutes,
    this.initialEndMinutes,
  });

  final DateTime initialDate;
  final Event? existing;

  /// ساعت اولیه‌ی شروع به دقیقه‌ی روز؛ تایم‌لاین با لمس فضای خالی آن را
  /// می‌دهد تا کاربر از همان ساعت شروع کند.
  final int? initialStartMinutes;

  /// ساعت اولیه‌ی پایان؛ اگر داده نشود یک ساعت بعد از شروع است.
  final int? initialEndMinutes;

  @override
  ConsumerState<EventEditorSheet> createState() => _EventEditorSheetState();
}

class _EventEditorSheetState extends ConsumerState<EventEditorSheet> {
  late final JalaliDateService _dates;
  late final TextEditingController _titleController;
  late final TextEditingController _dateController;
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  late final TextEditingController _locationController;
  late final TextEditingController _descriptionController;

  late final TextEditingController _intervalController;
  late final TextEditingController _untilController;

  late bool _allDay;
  String? _responsibilityId;
  RecurrenceFrequency? _frequency;
  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _dates = ref.read(jalaliDateServiceProvider);
    final Event? existing = widget.existing;

    _titleController = TextEditingController(text: existing?.title ?? '');
    _locationController = TextEditingController(text: existing?.location ?? '');
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );

    final DateTime date = existing?.startLocal ?? widget.initialDate;
    _dateController = TextEditingController(
      text: _dates.formatShort(date, usePersianDigits: false),
    );

    _allDay = existing?.allDay ?? false;
    final int startMinutes = existing == null || existing.allDay
        ? (widget.initialStartMinutes ?? (10 * 60))
        : (existing.startLocal.hour * 60) + existing.startLocal.minute;
    int endMinutes = existing == null || existing.allDay
        ? (widget.initialEndMinutes ?? startMinutes + 60)
        : (existing.endLocal.hour * 60) + existing.endLocal.minute;
    if (endMinutes <= startMinutes) {
      endMinutes = startMinutes + 60;
    }
    _startController = TextEditingController(
      text: _formatMinutes(startMinutes),
    );
    _endController = TextEditingController(text: _formatMinutes(endMinutes));

    _intervalController = TextEditingController(text: '۱');
    _untilController = TextEditingController();
    _responsibilityId = existing?.responsibilityId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _dateController.dispose();
    _startController.dispose();
    _endController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _intervalController.dispose();
    _untilController.dispose();
    super.dispose();
  }

  /// مسئولیت انتخاب‌شده؛ اگر کاربر چیزی انتخاب نکرده باشد، اولین مسئولیت
  /// فعال. مقدار نمایشی Dropdown (initialValue) خودش به فیلد state ما
  /// منتقل نمی‌شود، پس بدون این پل، ذخیره‌ی رویداد جدید همیشه با
  /// «مسئولیت انتخاب کنید» رد می‌شد.
  String? _effectiveResponsibilityId() {
    final String? selected = _responsibilityId;
    if (selected != null) {
      return selected;
    }
    final List<Responsibility> all =
        ref.read(responsibilitiesControllerProvider).value ??
        const <Responsibility>[];
    for (final Responsibility responsibility in all) {
      if (responsibility.isActive && responsibility.archivedAt == null) {
        return responsibility.id;
      }
    }
    return null;
  }

  Future<void> _save() async {
    final String title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorText = 'عنوان رویداد نمی‌تواند خالی باشد.');
      return;
    }

    final String? responsibilityId = _effectiveResponsibilityId();
    if (responsibilityId == null) {
      setState(() => _errorText = 'برای رویداد یک مسئولیت انتخاب کنید.');
      return;
    }

    final DateTime? date = parseJalaliDateInput(
      _dateController.text,
      _dates,
    );
    if (date == null) {
      setState(
        () => _errorText = 'تاریخ را به شکل ۱۴۰۴/۰۸/۱۰ و در تقویم شمسی وارد کنید.',
      );
      return;
    }

    DateTime startAt;
    DateTime endAt;
    if (_allDay) {
      startAt = _midnight(date);
      endAt = _nextMidnight(date);
    } else {
      final int? startMinutes = parseTimeOfDayInput(_startController.text);
      final int? endMinutes = parseTimeOfDayInput(_endController.text);
      if (startMinutes == null) {
        setState(() => _errorText = 'ساعت شروع را به شکل ۱۰:۰۰ وارد کنید.');
        return;
      }
      if (endMinutes == null) {
        setState(() => _errorText = 'ساعت پایان را به شکل ۱۱:۰۰ وارد کنید.');
        return;
      }
      startAt = _atMinutes(date, startMinutes);
      // پایان کوچک‌تر یا مساوی شروع یعنی رویداد پس از نیمه‌شب تمام می‌شود.
      endAt = endMinutes <= startMinutes
          ? _atMinutes(_nextMidnight(date), endMinutes)
          : _atMinutes(date, endMinutes);
    }

    RecurrenceFrequency? frequency;
    int interval = 1;
    DateTime? untilLocalDate;
    if (widget.existing == null && _frequency != null) {
      final int? parsedInterval = int.tryParse(
        _toLatinDigits(_intervalController.text).trim(),
      );
      if (parsedInterval == null || parsedInterval < 1) {
        setState(
          () => _errorText = 'بازه‌ی تکرار باید یک عدد بزرگ‌تر از صفر باشد.',
        );
        return;
      }
      interval = parsedInterval;
      frequency = _frequency;
      final String untilText = _untilController.text.trim();
      if (untilText.isNotEmpty) {
        untilLocalDate = parseJalaliDateInput(untilText, _dates);
        if (untilLocalDate == null) {
          setState(
            () => _errorText =
                'تاریخ پایان تکرار را به شکل ۱۴۰۴/۰۸/۱۰ وارد کنید یا خالی بگذارید.',
          );
          return;
        }
      }
    }

    setState(() => _errorText = null);

    final DayEventsController controller = ref.read(
      dayEventsProvider.notifier,
    );

    try {
      final List<Event> conflicts = await controller.conflictsFor(
        startAt: startAt,
        endAt: endAt,
        excludeEventId: widget.existing?.id,
      );

      if (conflicts.isNotEmpty) {
        if (!mounted) {
          return;
        }
        final String titles = conflicts
            .take(3)
            .map((Event event) => '«${event.title}»')
            .join('، ');
        final bool confirmed = await showAppConfirmDialog(
          context: context,
          title: 'همپوشانی زمانی',
          message:
              'این رویداد با $titles هم‌پوشانی دارد. '
              'می‌توانید زمان را اصلاح کنید یا با وجود تداخل ثبت کنید.',
          confirmLabel: 'ثبت با تداخل',
        );
        if (!confirmed) {
          return;
        }
      }

      // دامنه‌ی ویرایش سری هم پیش از روشن شدن نشانگر پرسیده می‌شود، به
      // همان دلیل دیالوگ تداخل.
      RecurrenceEditScope? scope;
      if (!mounted) {
        return;
      }
      if (widget.existing?.isOccurrence ?? false) {
        scope = await showRecurrenceScopeDialog(
          context: context,
          title: 'ویرایش رویداد تکراری',
        );
        if (scope == null) {
          return;
        }
      }

      // نشانگر بارگذاری فقط بعد از تصمیم کاربر روشن می‌شود؛ اگر پیش از
      // دیالوگ روشن شود، پشت مودال می‌چرخد و در تست‌ها pumpAndSettle
      // هرگز آرام نمی‌گیرد.
      if (!mounted) {
        return;
      }
      setState(() => _isSaving = true);

      final String description = _descriptionController.text.trim();
      final String location = _locationController.text.trim();

      if (widget.existing == null) {
        await controller.create(
          responsibilityId: responsibilityId,
          title: title,
          startAt: startAt,
          endAt: endAt,
          allDay: _allDay,
          description: description.isEmpty ? null : description,
          location: location.isEmpty ? null : location,
          frequency: frequency,
          interval: interval,
          untilLocalDate: untilLocalDate,
        );
      } else if (widget.existing!.isOccurrence && scope != null) {
        await controller.updateOccurrence(
          id: widget.existing!.id,
          scope: scope,
          responsibilityId: responsibilityId,
          title: title,
          startAt: startAt,
          endAt: endAt,
          allDay: _allDay,
          description: description,
          location: location,
        );
      } else {
        await controller.updateEvent(
          id: widget.existing!.id,
          responsibilityId: responsibilityId,
          title: title,
          startAt: startAt,
          endAt: endAt,
          allDay: _allDay,
          description: description,
          location: location,
        );
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(
        widget.existing == null
            ? EventEditorResult.created
            : EventEditorResult.updated,
      );
    } on EventRepositoryException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _errorText = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Responsibility> all =
        ref.watch(responsibilitiesControllerProvider).value ??
        const <Responsibility>[];
    final List<Responsibility> active = all
        .where((Responsibility r) => r.isActive && r.archivedAt == null)
        .toList();
    final List<Responsibility> options = <Responsibility>[...active];
    final String? currentId = _responsibilityId;
    if (currentId != null &&
        !options.any((Responsibility r) => r.id == currentId)) {
      options.addAll(
        all.where((Responsibility r) => r.id == currentId),
      );
    }

    final String? initialResponsibility = currentId != null &&
            options.any((Responsibility r) => r.id == currentId)
        ? currentId
        : (options.isEmpty ? null : options.first.id);

    return Column(
      key: eventEditorFormKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppTextField(
          key: eventEditorTitleKey,
          controller: _titleController,
          label: 'عنوان رویداد',
          hint: 'مثلاً جلسه‌ی شورای علمی',
          autofocus: widget.existing == null,
          textInputAction: TextInputAction.next,
          errorText: _errorText,
        ),
        const SizedBox(height: AppSpacing.md),
        if (options.isEmpty)
          const Text(
            'برای ثبت رویداد ابتدا یک مسئولیت فعال بسازید.',
            style: TextStyle(color: AppColors.warning),
          )
        else
          DropdownButtonFormField<String>(
            initialValue: initialResponsibility,
            decoration: const InputDecoration(labelText: 'مسئولیت'),
            items: <DropdownMenuItem<String>>[
              for (final Responsibility responsibility in options)
                DropdownMenuItem<String>(
                  value: responsibility.id,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: responsibility.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(responsibility.name),
                    ],
                  ),
                ),
            ],
            onChanged: (String? value) =>
                setState(() => _responsibilityId = value),
          ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          key: eventEditorDateKey,
          controller: _dateController,
          label: 'تاریخ (شمسی)',
          hint: '۱۴۰۴/۰۸/۱۰',
          keyboardType: TextInputType.datetime,
        ),
        const SizedBox(height: AppSpacing.md),
        SwitchListTile.adaptive(
          value: _allDay,
          contentPadding: EdgeInsets.zero,
          title: const Text('تمام‌روز'),
          subtitle: const Text('رویداد کل این روز را می‌پوشاند'),
          onChanged: (bool value) => setState(() => _allDay = value),
        ),
        if (!_allDay)
          Row(
            children: <Widget>[
              Expanded(
                child: AppTextField(
                  key: eventEditorStartKey,
                  controller: _startController,
                  label: 'شروع',
                  hint: '۱۰:۰۰',
                  keyboardType: TextInputType.datetime,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppTextField(
                  key: eventEditorEndKey,
                  controller: _endController,
                  label: 'پایان',
                  hint: '۱۱:۰۰',
                  keyboardType: TextInputType.datetime,
                  helperText: 'اگر پایان از شروع کوچک‌تر باشد، روز بعد حساب می‌شود.',
                ),
              ),
            ],
          ),
        const SizedBox(height: AppSpacing.md),
        if (widget.existing == null) ...<Widget>[
          DropdownButtonFormField<RecurrenceFrequency?>(
            key: eventEditorRecurrenceKey,
            initialValue: _frequency,
            decoration: const InputDecoration(labelText: 'تکرار'),
            items: const <DropdownMenuItem<RecurrenceFrequency?>>[
              DropdownMenuItem<RecurrenceFrequency?>(
                value: null,
                child: Text('بدون تکرار'),
              ),
              DropdownMenuItem<RecurrenceFrequency?>(
                value: RecurrenceFrequency.daily,
                child: Text('روزانه'),
              ),
              DropdownMenuItem<RecurrenceFrequency?>(
                value: RecurrenceFrequency.weekly,
                child: Text('هفتگی'),
              ),
              DropdownMenuItem<RecurrenceFrequency?>(
                value: RecurrenceFrequency.monthly,
                child: Text('ماهانه'),
              ),
              DropdownMenuItem<RecurrenceFrequency?>(
                value: RecurrenceFrequency.yearly,
                child: Text('سالانه'),
              ),
            ],
            onChanged: (RecurrenceFrequency? value) =>
                setState(() => _frequency = value),
          ),
          if (_frequency != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              key: eventEditorIntervalKey,
              controller: _intervalController,
              label: 'هر چند بار',
              hint: '۱',
              keyboardType: TextInputType.number,
              helperText: 'مثلاً ۲ یعنی یک‌درمیان. تکرار هفتگی روی همان روز '
                  'هفته‌ی تاریخ انتخاب‌شده و تکرار ماهانه روی همان روز ماه است.',
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              key: eventEditorUntilKey,
              controller: _untilController,
              label: 'تا تاریخ (اختیاری)',
              hint: '۱۴۰۴/۱۲/۲۹',
              keyboardType: TextInputType.datetime,
              helperText: 'خالی یعنی سری بدون پایان.',
            ),
          ],
        ] else if (widget.existing!.isOccurrence)
          const Text(
            'این رویداد بخشی از یک سری تکراری است؛ هنگام ذخیره انتخاب '
            'می‌کنید تغییر روی کدام بخش اعمال شود.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _locationController,
          label: 'مکان (اختیاری)',
          hint: 'مثلاً دفتر دانشکده',
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _descriptionController,
          label: 'توضیح (اختیاری)',
          maxLines: 3,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'ذخیره رویداد',
          icon: Icons.check_rounded,
          expand: true,
          isLoading: _isSaving,
          onPressed: _isSaving || options.isEmpty ? null : _save,
        ),
      ],
    );
  }
}
