import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/persian_digits.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../../core/widgets/app_section_header.dart';
import '../../../database/responsibility_repository_impl.dart';
import '../data/responsibilities_controller.dart';
import 'responsibility_editor_sheet.dart';
import 'responsibility_icons.dart';

/// مسئولیت‌ها — بخش ۵ و ۷.۷ سند.
///
/// صفحه‌ی واقعی مدیریت مسئولیت‌ها: فهرست از دیتابیس، ساخت، ویرایش، رنگ،
/// آیکون، ترتیب و بایگانی. هیچ داده‌ای در UI ساخته نمی‌شود؛ همه از
/// [ResponsibilitiesController] می‌آید.
class ResponsibilitiesPage extends ConsumerWidget {
  const ResponsibilitiesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Responsibility>> asyncItems = ref.watch(
      responsibilitiesControllerProvider,
    );

    return AppPageScaffold(
      title: 'مسئولیت‌ها',
      subtitle: 'نقش‌ها و حوزه‌هایی که زمان شما بین آن‌ها تقسیم می‌شود',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('مسئولیت جدید'),
      ),
      child: asyncItems.when(
        loading: () => const AppLoading(label: 'در حال خواندن مسئولیت‌ها…'),
        error: (Object error, StackTrace stackTrace) => AppErrorState(
          title: 'خواندن مسئولیت‌ها ممکن نشد',
          message:
              'ارتباط با دیتابیس محلی برقرار نشد. یک بار دیگر تلاش کنید؛ '
              'اگر تکرار شد برنامه را ببندید و باز کنید.',
          onRetry: () =>
              ref.invalidate(responsibilitiesControllerProvider),
        ),
        data: (List<Responsibility> items) => _ResponsibilityList(items: items),
      ),
    );
  }
}

/// باز کردن فرم ساخت/ویرایش و نمایش پیام نتیجه.
Future<void> _openEditor(
  BuildContext context, {
  Responsibility? existing,
}) async {
  final ResponsibilityEditorResult? result =
      await showAppBottomSheet<ResponsibilityEditorResult>(
        context: context,
        title: existing == null ? 'مسئولیت جدید' : 'ویرایش مسئولیت',
        builder: (BuildContext sheetContext) =>
            ResponsibilityEditorSheet(existing: existing),
      );

  if (!context.mounted || result == null) {
    return;
  }

  final String message = switch (result) {
    ResponsibilityEditorResult.created => 'مسئولیت جدید ساخته شد.',
    ResponsibilityEditorResult.updated => 'تغییرات ذخیره شد.',
    ResponsibilityEditorResult.archived => 'مسئولیت بایگانی شد.',
  };
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

class _ResponsibilityList extends ConsumerWidget {
  const _ResponsibilityList({required this.items});

  final List<Responsibility> items;

  bool _isActive(Responsibility item) =>
      item.isActive && item.archivedAt == null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return AppEmptyState(
        icon: Icons.badge_outlined,
        title: 'هنوز مسئولیتی تعریف نشده',
        message:
            'مسئولیت‌ها فعالیت‌های شما را بر اساس نقش دسته‌بندی می‌کنند؛ '
            'مثلاً دانشجو، معاونت علمی، انجمن و شخصی.',
        action: AppButton(
          label: 'ساخت اولین مسئولیت',
          icon: Icons.add_rounded,
          onPressed: () => _openEditor(context),
        ),
      );
    }

    final List<Responsibility> active =
        items.where(_isActive).toList(growable: false);
    final List<Responsibility> archived =
        items.where((Responsibility item) => !_isActive(item)).toList(
              growable: false,
            );

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl * 2),
      children: <Widget>[
        AppSectionHeader(
          title: 'فعال (${PersianDigits.fromInt(active.length)})',
        ),
        if (active.isEmpty)
          const AppCard(
            child: Text(
              'همه‌ی مسئولیت‌ها بایگانی شده‌اند. یکی را از بخش '
              '«بایگانی‌شده» فعال کنید.',
            ),
          )
        else
          for (int index = 0; index < active.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: _ResponsibilityTile(
                item: active[index],
                canMoveUp: index > 0,
                canMoveDown: index < active.length - 1,
              ),
            ),
        if (archived.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.sectionGap),
          AppSectionHeader(
            title: 'بایگانی‌شده (${PersianDigits.fromInt(archived.length)})',
          ),
          for (final Responsibility item in archived)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: _ResponsibilityTile(
                item: item,
                isArchived: true,
                canMoveUp: false,
                canMoveDown: false,
              ),
            ),
        ],
      ],
    );
  }
}

enum _TileAction { edit, moveUp, moveDown, archive, activate }

class _ResponsibilityTile extends ConsumerWidget {
  const _ResponsibilityTile({
    required this.item,
    required this.canMoveUp,
    required this.canMoveDown,
    this.isArchived = false,
  });

  final Responsibility item;
  final bool canMoveUp;
  final bool canMoveDown;
  final bool isArchived;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextTheme text = Theme.of(context).textTheme;
    final String? description = item.description;

    return AppCard(
      onTap: () => _openEditor(context, existing: item),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: isArchived ? 0.10 : 0.18),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              responsibilityIcon(item.iconKey),
              size: 22,
              color: isArchived
                  ? item.color.withValues(alpha: 0.55)
                  : item.color,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        item.name,
                        style: text.titleSmall?.copyWith(
                          color: isArchived
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (isArchived) ...<Widget>[
                      const SizedBox(width: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          'بایگانی‌شده',
                          style: text.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (description != null && description.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<_TileAction>(
            tooltip: 'اقدام‌های ${item.name}',
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppColors.textSecondary,
            ),
            onSelected: (action) => _handle(context, ref, action),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<_TileAction>>[
              const PopupMenuItem<_TileAction>(
                value: _TileAction.edit,
                child: Text('ویرایش'),
              ),
              if (!isArchived) ...<PopupMenuEntry<_TileAction>>[
                PopupMenuItem<_TileAction>(
                  value: _TileAction.moveUp,
                  enabled: canMoveUp,
                  child: const Text('انتقال به بالا'),
                ),
                PopupMenuItem<_TileAction>(
                  value: _TileAction.moveDown,
                  enabled: canMoveDown,
                  child: const Text('انتقال به پایین'),
                ),
                const PopupMenuItem<_TileAction>(
                  value: _TileAction.archive,
                  child: Text('بایگانی'),
                ),
              ] else
                const PopupMenuItem<_TileAction>(
                  value: _TileAction.activate,
                  child: Text('فعال‌سازی دوباره'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handle(
    BuildContext context,
    WidgetRef ref,
    _TileAction action,
  ) async {
    final ResponsibilitiesController controller = ref.read(
      responsibilitiesControllerProvider.notifier,
    );

    switch (action) {
      case _TileAction.edit:
        await _openEditor(context, existing: item);
      case _TileAction.moveUp:
        await _run(context, () => controller.move(item.id, up: true));
      case _TileAction.moveDown:
        await _run(context, () => controller.move(item.id, up: false));
      case _TileAction.archive:
        final bool confirmed = await showAppConfirmDialog(
          context: context,
          title: 'بایگانی مسئولیت',
          message:
              '«${item.name}» بایگانی می‌شود و در فرم‌های جدید انتخاب '
              'نمی‌شود. داده‌های قبلی حذف نمی‌شوند.',
          confirmLabel: 'بایگانی',
        );
        if (!confirmed || !context.mounted) {
          return;
        }
        await _run(context, () => controller.archive(item.id));
      case _TileAction.activate:
        await _run(context, () => controller.activate(item.id));
    }
  }

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on ResponsibilityRepositoryException catch (error) {
      if (!context.mounted) {
        return;
      }
      _showMessage(context, error.message);
    }
  }
}
