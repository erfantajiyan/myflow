import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/date_time/jalali_date_service.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/utils/persian_digits.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_loading.dart';
import '../../../core/widgets/app_page_scaffold.dart';
import '../../../database/responsibility_repository_impl.dart';
import '../../../database/task_repository_impl.dart';
import '../../../shared/enums/app_enums.dart';
import '../../responsibilities/data/responsibilities_controller.dart';
import '../data/tasks_controller.dart';
import 'task_editor_sheet.dart';

/// وظایف — بخش ۷.۴ سند.
class TasksPage extends ConsumerWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Task>> asyncTasks = ref.watch(
      tasksControllerProvider,
    );
    final TaskFilter filter = ref.watch(taskFilterProvider);

    return AppPageScaffold(
      title: 'وظایف',
      subtitle: 'امروز، آینده، عقب‌افتاده و تکمیل‌شده',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('وظیفه‌ی جدید'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (final TaskFilter option in TaskFilter.values)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: AppSpacing.xs,
                    ),
                    child: ChoiceChip(
                      label: Text(option.label),
                      selected: option == filter,
                      onSelected: (bool _) => ref
                          .read(taskFilterProvider.notifier)
                          .select(option),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: asyncTasks.when(
              loading: () => const AppLoading(label: 'در حال خواندن وظایف…'),
              error: (Object error, StackTrace stackTrace) => AppErrorState(
                title: 'خواندن وظایف ممکن نشد',
                message:
                    'ارتباط با دیتابیس محلی برقرار نشد. یک بار دیگر تلاش کنید.',
                onRetry: () => ref.invalidate(tasksControllerProvider),
              ),
              data: (List<Task> tasks) => _TaskList(
                tasks: tasks,
                filter: filter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _openEditor(BuildContext context, {Task? existing}) async {
  final TaskEditorResult? result = await showAppBottomSheet<TaskEditorResult>(
    context: context,
    title: existing == null ? 'وظیفه‌ی جدید' : 'ویرایش وظیفه',
    builder: (BuildContext sheetContext) =>
        TaskEditorSheet(existing: existing),
  );

  if (!context.mounted || result == null) {
    return;
  }
  _showMessage(
    context,
    switch (result) {
      TaskEditorResult.created => 'وظیفه ساخته شد.',
      TaskEditorResult.updated => 'تغییرات وظیفه ذخیره شد.',
    },
  );
}

/// پیام تازه، پیام قبلی را کنار می‌زند.
///
/// ScaffoldMessenger پیام‌ها را صف می‌کند؛ بدون این، نتیجه‌ی اقدام کاربر
/// (مثلاً تبدیل به رویداد) تا ۴ ثانیه پشت پیام قبلی می‌ماند.
void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _TaskList extends ConsumerWidget {
  const _TaskList({required this.tasks, required this.filter});

  final List<Task> tasks;
  final TaskFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tasks.isEmpty) {
      return AppEmptyState(
        icon: Icons.checklist_rounded,
        title: switch (filter) {
          TaskFilter.all => 'هنوز وظیفه‌ای ثبت نشده',
          TaskFilter.today => 'برای امروز وظیفه‌ای نیست',
          TaskFilter.upcoming => 'وظیفه‌ی آینده‌ای نیست',
          TaskFilter.overdue => 'هیچ وظیفه‌ای عقب نیفتاده',
          TaskFilter.completed => 'هنوز وظیفه‌ای تکمیل نشده',
        },
        message: 'وظیفه می‌تواند فقط تاریخ داشته باشد یا ساعت هم بگیرد.',
      );
    }

    final List<Responsibility> responsibilities =
        ref.watch(responsibilitiesControllerProvider).value ??
        const <Responsibility>[];
    final Map<String, String> names = <String, String>{
      for (final Responsibility item in responsibilities) item.id: item.name,
    };
    final Map<String, Color> colors = <String, Color>{
      for (final Responsibility item in responsibilities)
        item.id: item.color,
    };

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl * 2),
      itemCount: tasks.length,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: AppSpacing.xs),
      itemBuilder: (BuildContext context, int index) => _TaskTile(
        task: tasks[index],
        responsibilityName: names[tasks[index].responsibilityId],
        responsibilityColor: colors[tasks[index].responsibilityId],
      ),
    );
  }
}

enum _TaskAction { edit, convert, archive }

class _TaskTile extends ConsumerWidget {
  const _TaskTile({
    required this.task,
    this.responsibilityName,
    this.responsibilityColor,
  });

  final Task task;
  final String? responsibilityName;
  final Color? responsibilityColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextTheme text = Theme.of(context).textTheme;
    final JalaliDateService jalali = ref.watch(jalaliDateServiceProvider);
    final DateTime now = DateTime.now();

    final List<String> meta = <String>[
      ?responsibilityName,
      _dueLabel(jalali, now),
      _priorityLabel(task.priority),
      if (task.estimatedMinutes != null)
        '${PersianDigits.fromInt(task.estimatedMinutes!)} دقیقه',
    ];

    return AppCard(
      onTap: () => _openEditor(context, existing: task),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: task.isCompleted ? 'بازگشایی وظیفه' : 'تکمیل وظیفه',
            onPressed: () => _toggle(context, ref, now),
            icon: Icon(
              task.isCompleted
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: task.isCompleted
                  ? AppColors.success
                  : (responsibilityColor ?? AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall?.copyWith(
                    color: task.isCompleted
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                    decoration: task.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  meta.join(' • '),
                  style: text.bodySmall?.copyWith(
                    color: task.isOverdue(now)
                        ? AppColors.error
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<_TaskAction>(
            tooltip: 'اقدام‌های ${task.title}',
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppColors.textSecondary,
            ),
            onSelected: (_TaskAction action) =>
                _handle(context, ref, action),
            itemBuilder: (BuildContext context) =>
                const <PopupMenuEntry<_TaskAction>>[
                  PopupMenuItem<_TaskAction>(
                    value: _TaskAction.edit,
                    child: Text('ویرایش'),
                  ),
                  PopupMenuItem<_TaskAction>(
                    value: _TaskAction.convert,
                    child: Text('تبدیل به رویداد'),
                  ),
                  PopupMenuItem<_TaskAction>(
                    value: _TaskAction.archive,
                    child: Text('بایگانی'),
                  ),
                ],
          ),
        ],
      ),
    );
  }

  String _dueLabel(JalaliDateService jalali, DateTime now) {
    final DateTime? due = task.dueDateLocal;
    if (due == null) {
      return 'بدون سررسید';
    }
    final String date = jalali.formatShort(due);
    if (task.dueTime != null) {
      return '$date ${PersianDigits.convert(task.dueTime!.substring(0, 5))}';
    }
    return date;
  }

  String _priorityLabel(Priority priority) => switch (priority) {
    Priority.low => 'اولویت کم',
    Priority.medium => 'اولویت متوسط',
    Priority.high => 'اولویت زیاد',
  };

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    DateTime now,
  ) async {
    final TasksController controller = ref.read(
      tasksControllerProvider.notifier,
    );
    try {
      if (task.isCompleted) {
        await controller.reopen(task.id);
      } else {
        await controller.complete(task.id);
      }
    } on TaskRepositoryException catch (error) {
      if (context.mounted) {
        _showMessage(context, error.message);
      }
    }
  }

  Future<void> _handle(
    BuildContext context,
    WidgetRef ref,
    _TaskAction action,
  ) async {
    final TasksController controller = ref.read(
      tasksControllerProvider.notifier,
    );

    switch (action) {
      case _TaskAction.edit:
        await _openEditor(context, existing: task);
      case _TaskAction.convert:
        try {
          await controller.convertToEvent(task);
          if (context.mounted) {
            _showMessage(
              context,
              'رویداد ۰۹:۰۰ تا ۱۰:۰۰ برای این وظیفه ساخته شد.',
            );
          }
        } on Object catch (error) {
          if (context.mounted) {
            _showMessage(context, 'ساخت رویداد ممکن نشد: $error');
          }
        }
      case _TaskAction.archive:
        final bool confirmed = await showAppConfirmDialog(
          context: context,
          title: 'بایگانی وظیفه',
          message:
              '«${task.title}» بایگانی می‌شود و از فهرست‌ها بیرون می‌رود. '
              'داده حذف نمی‌شود.',
          confirmLabel: 'بایگانی',
        );
        if (!confirmed || !context.mounted) {
          return;
        }
        try {
          await controller.archive(task.id);
        } on TaskRepositoryException catch (error) {
          if (context.mounted) {
            _showMessage(context, error.message);
          }
        }
    }
  }
}
