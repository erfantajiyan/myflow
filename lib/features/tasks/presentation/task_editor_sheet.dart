import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/date_time/jalali_date_service.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/utils/persian_digits.dart';
import '../../../core/widgets/app_button.dart';
import '../../../database/project_repository_impl.dart';
import '../../../database/responsibility_repository_impl.dart';
import '../../../database/task_repository_impl.dart';
import '../../../shared/enums/app_enums.dart';
import '../../events/presentation/event_editor_sheet.dart'
    show parseJalaliDateInput;
import '../../projects/data/projects_controller.dart';
import '../../responsibilities/data/responsibilities_controller.dart';
import '../data/tasks_controller.dart';

const Key taskEditorFormKey = Key('task-editor-form');
const Key taskEditorTitleKey = Key('task-editor-title');
const Key taskEditorDateKey = Key('task-editor-date');
const Key taskEditorTimeKey = Key('task-editor-time');
const Key taskEditorEstimateKey = Key('task-editor-estimate');

enum TaskEditorResult { created, updated }

/// فرم ساخت/ویرایش وظیفه — بخش ۷.۴ سند.
///
/// وظیفه می‌تواند فقط تاریخ داشته باشد (بدون ساعت) و همین «وظیفه‌ی روزانه»
/// را از رویداد جدا می‌کند.
class TaskEditorSheet extends ConsumerStatefulWidget {
  const TaskEditorSheet({super.key, this.existing});

  final Task? existing;

  @override
  ConsumerState<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends ConsumerState<TaskEditorSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _dateController;
  late final TextEditingController _timeController;
  late final TextEditingController _estimateController;

  String? _responsibilityId;
  String? _projectId;
  Priority _priority = Priority.medium;
  DateTime? _dueDate;
  String? _errorText;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final Task? existing = widget.existing;
    final JalaliDateService jalali = ref.read(jalaliDateServiceProvider);
    _titleController = TextEditingController(text: existing?.title ?? '');
    _dateController = TextEditingController(
      text: existing?.dueDateLocal == null
          ? ''
          : jalali.formatShort(
              existing!.dueDateLocal!,
              usePersianDigits: false,
            ),
    );
    _timeController = TextEditingController(
      text: existing?.dueTime == null
          ? ''
          : existing!.dueTime!.substring(0, 5),
    );
    _estimateController = TextEditingController(
      text: existing?.estimatedMinutes?.toString() ?? '',
    );
    _responsibilityId = existing?.responsibilityId;
    _projectId = existing?.projectId;
    _priority = existing?.priority ?? Priority.medium;
    _dueDate = existing?.dueDateLocal;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _estimateController.dispose();
    super.dispose();
  }

  /// `HH:mm` یا ارقام فارسی → دقیقه‌ی روز.
  int? _parseMinutes(String raw) {
    final String value = PersianDigits.toLatin(raw.trim());
    if (value.isEmpty) {
      return null;
    }
    final List<String> parts = value.split(':');
    if (parts.length != 2) {
      return -1;
    }
    final int? hour = int.tryParse(parts[0]);
    final int? minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return -1;
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return -1;
    }
    return hour * 60 + minute;
  }

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
      setState(() => _errorText = 'عنوان وظیفه نمی‌تواند خالی باشد.');
      return;
    }

    final String dateText = _dateController.text.trim();
    DateTime? date = _dueDate;
    if (dateText.isNotEmpty) {
      date = parseJalaliDateInput(
        dateText,
        ref.read(jalaliDateServiceProvider),
      );
      if (date == null) {
        setState(() => _errorText = 'تاریخ را به شکل ۱۴۰۴/۰۸/۱۰ وارد کنید.');
        return;
      }
    } else {
      date = null;
    }

    final String timeText = _timeController.text.trim();
    final int? minutes = _parseMinutes(timeText);
    final String? time;
    if (timeText.isEmpty) {
      time = null;
    } else if (minutes == null || minutes < 0) {
      setState(() => _errorText = 'ساعت را به شکل ۱۰:۳۰ وارد کنید.');
      return;
    } else {
      final String hh = (minutes ~/ 60).toString().padLeft(2, '0');
      final String mm = (minutes % 60).toString().padLeft(2, '0');
      time = '$hh:$mm';
    }

    if (time != null && date == null) {
      setState(
        () => _errorText = 'برای ثبت ساعت، تاریخ سررسید هم لازم است.',
      );
      return;
    }

    final String estimateText = _estimateController.text.trim();
    final int? estimate = estimateText.isEmpty
        ? null
        : int.tryParse(PersianDigits.toLatin(estimateText));
    if (estimateText.isNotEmpty && (estimate == null || estimate <= 0)) {
      setState(() => _errorText = 'زمان تخمینی باید عددی بیشتر از صفر باشد.');
      return;
    }

    final String? responsibilityId = _effectiveResponsibilityId();
    if (responsibilityId == null) {
      setState(() => _errorText = 'برای وظیفه یک مسئولیت انتخاب کنید.');
      return;
    }

    setState(() {
      _errorText = null;
      _isSaving = true;
    });

    final TasksController controller = ref.read(
      tasksControllerProvider.notifier,
    );

    try {
      if (widget.existing == null) {
        await controller.create(
          responsibilityId: responsibilityId,
          title: title,
          projectId: _projectId,
          priority: _priority,
          dueDate: date,
          dueTime: time,
          estimatedMinutes: estimate,
        );
      } else {
        await controller.edit(
          id: widget.existing!.id,
          responsibilityId: responsibilityId,
          title: title,
          priority: _priority,
          dueDate: date,
          dueTime: time,
          estimatedMinutes: estimate,
          projectId: _projectId,
          clearProjectId: _projectId == null,
          clearDueDate: date == null,
          clearDueTime: time == null,
        );
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(
        widget.existing == null
            ? TaskEditorResult.created
            : TaskEditorResult.updated,
      );
    } on TaskRepositoryException catch (error) {
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
    final List<Responsibility> responsibilities =
        (ref.watch(responsibilitiesControllerProvider).value ??
                const <Responsibility>[])
            .where(
              (Responsibility item) =>
                  item.isActive || item.id == _responsibilityId,
            )
            .toList();
    final List<ProjectSummary> projects =
        ref.watch(projectsControllerProvider).value ??
        const <ProjectSummary>[];

    final String? selectedResponsibility =
        _responsibilityId ??
        (responsibilities.isEmpty ? null : responsibilities.first.id);
    final bool hasSelectedProject = projects.any(
      (ProjectSummary summary) => summary.project.id == _projectId,
    );

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextFormField(
            key: taskEditorTitleKey,
            controller: _titleController,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'عنوان وظیفه',
              hintText: 'مثلاً: ارسال گزارش هفتگی',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: selectedResponsibility,
            decoration: const InputDecoration(labelText: 'مسئولیت'),
            items: <DropdownMenuItem<String>>[
              for (final Responsibility item in responsibilities)
                DropdownMenuItem<String>(
                  value: item.id,
                  child: Text(item.name),
                ),
            ],
            onChanged: (String? value) =>
                setState(() => _responsibilityId = value),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String?>(
            initialValue: hasSelectedProject ? _projectId : null,
            decoration: const InputDecoration(labelText: 'پروژه (اختیاری)'),
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('بدون پروژه'),
              ),
              for (final ProjectSummary summary in projects)
                if (summary.project.archivedAt == null)
                  DropdownMenuItem<String?>(
                    value: summary.project.id,
                    child: Text(summary.project.title),
                  ),
            ],
            onChanged: (String? value) => setState(() => _projectId = value),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: TextFormField(
                  key: taskEditorDateKey,
                  controller: _dateController,
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(
                    labelText: 'سررسید (شمسی)',
                    hintText: '۱۴۰۴/۰۸/۱۰',
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextFormField(
                  key: taskEditorTimeKey,
                  controller: _timeController,
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(
                    labelText: 'ساعت (اختیاری)',
                    hintText: '۱۰:۳۰',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            key: taskEditorEstimateKey,
            controller: _estimateController,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: const InputDecoration(
              labelText: 'زمان تخمینی (دقیقه، اختیاری)',
              hintText: '۳۰',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              'اولویت',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SegmentedButton<Priority>(
            segments: const <ButtonSegment<Priority>>[
              ButtonSegment<Priority>(value: Priority.low, label: Text('کم')),
              ButtonSegment<Priority>(
                value: Priority.medium,
                label: Text('متوسط'),
              ),
              ButtonSegment<Priority>(
                value: Priority.high,
                label: Text('زیاد'),
              ),
            ],
            selected: <Priority>{_priority},
            onSelectionChanged: (Set<Priority> values) =>
                setState(() => _priority = values.first),
          ),
          if (_errorText != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _errorText!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.error,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'ذخیره وظیفه',
            isLoading: _isSaving,
            expand: true,
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
    );
  }
}
