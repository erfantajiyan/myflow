import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../database/responsibility_repository_impl.dart';
import '../data/responsibilities_controller.dart';
import 'responsibility_icons.dart';

/// نتیجه‌ی بسته شدن فرم، تا صفحه بداند چه پیامی نشان دهد.
enum ResponsibilityEditorResult { created, updated, archived }

const Key responsibilityEditorFormKey = Key('responsibilityEditorForm');

/// رنگ‌های پیشنهادی برای مسئولیت.
const List<Color> responsibilityColorPresets = <Color>[
  AppColors.responsibilityStudent,
  AppColors.responsibilityViceChancellor,
  AppColors.responsibilityAssociation,
  AppColors.responsibilityPersonal,
  AppColors.accent,
  AppColors.success,
  AppColors.warning,
  AppColors.error,
];

/// فرم مشترک ساخت و ویرایش مسئولیت.
///
/// همان فرم برای هر دو حالت استفاده می‌شود تا رفتار کاربر در همه‌ی
/// مسیرها یکسان بماند (بخش ۵ سند).
class ResponsibilityEditorSheet extends ConsumerStatefulWidget {
  const ResponsibilityEditorSheet({super.key, this.existing});

  final Responsibility? existing;

  @override
  ConsumerState<ResponsibilityEditorSheet> createState() =>
      _ResponsibilityEditorSheetState();
}

class _ResponsibilityEditorSheetState
    extends ConsumerState<ResponsibilityEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late Color _color;
  late String? _iconKey;

  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final Responsibility? existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    _color = existing?.color ?? responsibilityColorPresets.first;
    _iconKey = existing?.iconKey ?? responsibilityIcons.keys.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'نام مسئولیت نمی‌تواند خالی باشد.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    final ResponsibilitiesController controller = ref.read(
      responsibilitiesControllerProvider.notifier,
    );
    // رشته‌ی خالی یعنی «بدون توضیح»؛ با همین مقدار، پاک کردن توضیح در ویرایش
    // هم درست ذخیره می‌شود.
    final String description = _descriptionController.text.trim();

    try {
      if (widget.existing == null) {
        await controller.create(
          name: name,
          color: _color,
          iconKey: _iconKey,
          description: description,
        );
      } else {
        await controller.edit(
          id: widget.existing!.id,
          name: name,
          color: _color,
          iconKey: _iconKey,
          description: description,
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(
        widget.existing == null
            ? ResponsibilityEditorResult.created
            : ResponsibilityEditorResult.updated,
      );
    } on ResponsibilityRepositoryException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _errorText = error.message;
      });
    }
  }

  Future<void> _archive() async {
    final Responsibility? existing = widget.existing;
    if (existing == null) {
      return;
    }

    final bool confirmed = await showAppConfirmDialog(
      context: context,
      title: 'بایگانی مسئولیت',
      message:
          '«${existing.name}» بایگانی می‌شود و در فرم‌های جدید انتخاب '
          'نمی‌شود. داده‌های قبلی حذف نمی‌شوند و از بخش «بایگانی‌شده» '
          'می‌توانید دوباره فعالش کنید.',
      confirmLabel: 'بایگانی',
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(responsibilitiesControllerProvider.notifier)
          .archive(existing.id);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(ResponsibilityEditorResult.archived);
    } on ResponsibilityRepositoryException catch (error) {
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
    final bool isEditing = widget.existing != null;

    return Column(
      key: responsibilityEditorFormKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppTextField(
          controller: _nameController,
          label: 'نام مسئولیت',
          hint: 'مثلاً دانشجو',
          autofocus: !isEditing,
          textInputAction: TextInputAction.next,
          errorText: _errorText,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _descriptionController,
          label: 'توضیح (اختیاری)',
          hint: 'این حوزه شامل چه کارهایی است؟',
          maxLines: 3,
        ),
        const SizedBox(height: AppSpacing.md),
        Text('رنگ', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            for (final Color preset in responsibilityColorPresets)
              _ColorSwatch(
                color: preset,
                isSelected: preset.toARGB32() == _color.toARGB32(),
                onTap: () => setState(() => _color = preset),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text('آیکون', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            for (final MapEntry<String, IconData> entry
                in responsibilityIcons.entries)
              _IconChoice(
                icon: entry.value,
                isSelected: entry.key == _iconKey,
                onTap: () => setState(() => _iconKey = entry.key),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: isEditing ? 'ذخیره تغییرات' : 'ساخت مسئولیت',
          icon: Icons.check_rounded,
          expand: true,
          isLoading: _isSaving,
          onPressed: _isSaving ? null : _save,
        ),
        if (isEditing) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          AppButton(
            label: 'بایگانی مسئولیت',
            icon: Icons.archive_outlined,
            variant: AppButtonVariant.ghost,
            expand: true,
            onPressed: _isSaving ? null : _archive,
          ),
        ],
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          width: AppSpacing.minTouchTarget,
          height: AppSpacing.minTouchTarget,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? AppColors.textPrimary : AppColors.border,
              width: isSelected ? 2.5 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: isSelected
                ? const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: AppColors.onAccent,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: AppSpacing.minTouchTarget,
        height: AppSpacing.minTouchTarget,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceHigh : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isSelected ? AppColors.accent : AppColors.textSecondary,
        ),
      ),
    );
  }
}
