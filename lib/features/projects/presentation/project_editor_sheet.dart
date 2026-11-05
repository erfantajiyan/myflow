import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/date_time/jalali_date_service.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/widgets/app_button.dart';
import '../../../database/project_repository_impl.dart';
import '../../../database/responsibility_repository_impl.dart';
import '../../../shared/enums/app_enums.dart';
import '../../events/presentation/event_editor_sheet.dart'
    show parseJalaliDateInput;
import '../../responsibilities/data/responsibilities_controller.dart';
import '../data/projects_controller.dart';

const Key projectEditorTitleKey = Key('project-editor-title');
const Key projectEditorStartKey = Key('project-editor-start');
const Key projectEditorDueKey = Key('project-editor-due');

enum ProjectEditorResult { created, updated }

/// فرم ساخت/ویرایش پروژه — بخش ۷.۵ سند.
class ProjectEditorSheet extends ConsumerStatefulWidget {
  const ProjectEditorSheet({super.key, this.existing});

  final Project? existing;

  @override
  ConsumerState<ProjectEditorSheet> createState() =>
      _ProjectEditorSheetState();
}

class _ProjectEditorSheetState extends ConsumerState<ProjectEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _startController;
  late final TextEditingController _dueController;

  String? _responsibilityId;
  ProjectStatus _status = ProjectStatus.planned;
  ProgressMode _progressMode = ProgressMode.automatic;
  double _manualProgress = 0;
  String? _errorText;
  bool _isSaving = false;

  static const List<Color> _palette = <Color>[
    Color(0xFF3B82F6),
    Color(0xFF22A06B),
    Color(0xFFA855F7),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF64748B),
  ];

  Color _color = _palette.first;

  @override
  void initState() {
    super.initState();
    final Project? existing = widget.existing;
    final JalaliDateService jalali = ref.read(jalaliDateServiceProvider);
    _titleController = TextEditingController(text: existing?.title ?? '');
    _startController = TextEditingController(
      text: existing?.startDateLocal == null
          ? ''
          : jalali.formatShort(
              existing!.startDateLocal!,
              usePersianDigits: false,
            ),
    );
    _dueController = TextEditingController(
      text: existing?.dueDateLocal == null
          ? ''
          : jalali.formatShort(
              existing!.dueDateLocal!,
              usePersianDigits: false,
            ),
    );
    _responsibilityId = existing?.responsibilityId;
    _status = existing?.status ?? ProjectStatus.planned;
    _progressMode = existing?.progressMode ?? ProgressMode.automatic;
    _manualProgress = (existing?.manualProgress ?? 0).toDouble();
    _color = existing?.color ?? _palette.first;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _startController.dispose();
    _dueController.dispose();
    super.dispose();
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
      setState(() => _errorText = 'عنوان پروژه نمی‌تواند خالی باشد.');
      return;
    }

    final JalaliDateService dates = ref.read(jalaliDateServiceProvider);
    final String startText = _startController.text.trim();
    final DateTime? start = startText.isEmpty
        ? null
        : parseJalaliDateInput(startText, dates);
    if (startText.isNotEmpty && start == null) {
      setState(() => _errorText = 'تاریخ شروع را به شکل ۱۴۰۴/۰۸/۱۰ وارد کنید.');
      return;
    }

    final String dueText = _dueController.text.trim();
    final DateTime? due = dueText.isEmpty
        ? null
        : parseJalaliDateInput(dueText, dates);
    if (dueText.isNotEmpty && due == null) {
      setState(() => _errorText = 'تاریخ پایان را به شکل ۱۴۰۴/۰۸/۱۰ وارد کنید.');
      return;
    }

    final String? responsibilityId = _effectiveResponsibilityId();
    if (responsibilityId == null) {
      setState(() => _errorText = 'برای پروژه یک مسئولیت انتخاب کنید.');
      return;
    }

    setState(() {
      _errorText = null;
      _isSaving = true;
    });

    final ProjectsController controller = ref.read(
      projectsControllerProvider.notifier,
    );

    try {
      if (widget.existing == null) {
        await controller.create(
          responsibilityId: responsibilityId,
          title: title,
          status: _status,
          startDate: start,
          dueDate: due,
          colorHex: _hexOf(_color),
          progressMode: _progressMode,
          manualProgress: _progressMode == ProgressMode.manual
              ? _manualProgress.round()
              : null,
        );
      } else {
        await controller.edit(
          id: widget.existing!.id,
          responsibilityId: responsibilityId,
          title: title,
          status: _status,
          startDate: start,
          dueDate: due,
          colorHex: _hexOf(_color),
          progressMode: _progressMode,
          manualProgress: _progressMode == ProgressMode.manual
              ? _manualProgress.round()
              : null,
          clearStartDate: start == null,
          clearDueDate: due == null,
        );
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(
        widget.existing == null
            ? ProjectEditorResult.created
            : ProjectEditorResult.updated,
      );
    } on ProjectRepositoryException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _errorText = error.message;
      });
    }
  }

  String _hexOf(Color color) {
    final String hex = color.toARGB32().toRadixString(16).padLeft(8, '0');
    return '#${hex.substring(2).toUpperCase()}';
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
    final String? selectedResponsibility =
        _responsibilityId ??
        (responsibilities.isEmpty ? null : responsibilities.first.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TextFormField(
          key: projectEditorTitleKey,
          controller: _titleController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'عنوان پروژه',
            hintText: 'مثلاً: آماده‌سازی همایش علمی',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(
          initialValue: selectedResponsibility,
          decoration: const InputDecoration(labelText: 'مسئولیت اصلی'),
          items: <DropdownMenuItem<String>>[
            for (final Responsibility item in responsibilities)
              DropdownMenuItem<String>(value: item.id, child: Text(item.name)),
          ],
          onChanged: (String? value) =>
              setState(() => _responsibilityId = value),
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<ProjectStatus>(
          initialValue: _status == ProjectStatus.archived
              ? ProjectStatus.planned
              : _status,
          decoration: const InputDecoration(labelText: 'وضعیت'),
          items: const <DropdownMenuItem<ProjectStatus>>[
            DropdownMenuItem<ProjectStatus>(
              value: ProjectStatus.planned,
              child: Text('برنامه‌ریزی‌شده'),
            ),
            DropdownMenuItem<ProjectStatus>(
              value: ProjectStatus.active,
              child: Text('در جریان'),
            ),
            DropdownMenuItem<ProjectStatus>(
              value: ProjectStatus.paused,
              child: Text('متوقف'),
            ),
            DropdownMenuItem<ProjectStatus>(
              value: ProjectStatus.completed,
              child: Text('تکمیل‌شده'),
            ),
          ],
          onChanged: (ProjectStatus? value) {
            if (value != null) {
              setState(() => _status = value);
            }
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            Expanded(
              child: TextFormField(
                key: projectEditorStartKey,
                controller: _startController,
                decoration: const InputDecoration(
                  labelText: 'شروع (شمسی)',
                  hintText: '۱۴۰۴/۰۸/۱۰',
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextFormField(
                key: projectEditorDueKey,
                controller: _dueController,
                decoration: const InputDecoration(
                  labelText: 'پایان (شمسی)',
                  hintText: '۱۴۰۴/۰۹/۱۰',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('پیشرفت خودکار'),
          subtitle: Text(
            _progressMode == ProgressMode.automatic
                ? 'درصد از روی وظایف تکمیل‌شده حساب می‌شود.'
                : 'درصد را خودتان تعیین می‌کنید.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          value: _progressMode == ProgressMode.automatic,
          onChanged: (bool value) => setState(() {
            _progressMode = value
                ? ProgressMode.automatic
                : ProgressMode.manual;
          }),
        ),
        if (_progressMode == ProgressMode.manual) ...<Widget>[
          Slider(
            value: _manualProgress,
            max: 100,
            divisions: 20,
            label: '${_manualProgress.round()}٪',
            onChanged: (double value) =>
                setState(() => _manualProgress = value),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            'رنگ پروژه',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          children: <Widget>[
            for (final Color color in _palette)
              GestureDetector(
                onTap: () => setState(() => _color = color),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color == _color
                          ? AppColors.textPrimary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
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
          label: 'ذخیره پروژه',
          isLoading: _isSaving,
          expand: true,
          onPressed: _isSaving ? null : _save,
        ),
      ],
    );
  }
}
