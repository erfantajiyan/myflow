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
import '../../../database/project_repository_impl.dart';
import '../../../database/responsibility_repository_impl.dart';
import '../../../shared/enums/app_enums.dart';
import '../../responsibilities/data/responsibilities_controller.dart';
import '../data/projects_controller.dart';
import 'project_editor_sheet.dart';

/// پروژه‌ها — بخش ۷.۵ سند.
class ProjectsPage extends ConsumerWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ProjectSummary>> asyncProjects = ref.watch(
      projectsControllerProvider,
    );

    return AppPageScaffold(
      title: 'پروژه‌ها',
      subtitle: 'هدف‌های بزرگ‌تر و پیشرفتشان',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('پروژه‌ی جدید'),
      ),
      child: asyncProjects.when(
        loading: () => const AppLoading(label: 'در حال خواندن پروژه‌ها…'),
        error: (Object error, StackTrace stackTrace) => AppErrorState(
          title: 'خواندن پروژه‌ها ممکن نشد',
          message:
              'ارتباط با دیتابیس محلی برقرار نشد. یک بار دیگر تلاش کنید.',
          onRetry: () => ref.invalidate(projectsControllerProvider),
        ),
        data: (List<ProjectSummary> summaries) =>
            _ProjectList(summaries: summaries),
      ),
    );
  }
}

Future<void> _openEditor(BuildContext context, {Project? existing}) async {
  final ProjectEditorResult? result =
      await showAppBottomSheet<ProjectEditorResult>(
        context: context,
        title: existing == null ? 'پروژه‌ی جدید' : 'ویرایش پروژه',
        builder: (BuildContext sheetContext) =>
            ProjectEditorSheet(existing: existing),
      );

  if (!context.mounted || result == null) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        switch (result) {
          ProjectEditorResult.created => 'پروژه ساخته شد.',
          ProjectEditorResult.updated => 'تغییرات پروژه ذخیره شد.',
        },
      ),
    ),
  );
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

class _ProjectList extends ConsumerWidget {
  const _ProjectList({required this.summaries});

  final List<ProjectSummary> summaries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (summaries.isEmpty) {
      return const AppEmptyState(
        icon: Icons.folder_outlined,
        title: 'هنوز پروژه‌ای ساخته نشده',
        message:
            'هر پروژه یک مسئولیت اصلی دارد و وظایف متصل به آن، درصد پیشرفت '
            'را می‌سازند.',
      );
    }

    final List<Responsibility> responsibilities =
        ref.watch(responsibilitiesControllerProvider).value ??
        const <Responsibility>[];
    final Map<String, String> names = <String, String>{
      for (final Responsibility item in responsibilities) item.id: item.name,
    };

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl * 2),
      itemCount: summaries.length,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: AppSpacing.xs),
      itemBuilder: (BuildContext context, int index) => _ProjectTile(
        summary: summaries[index],
        responsibilityName: names[summaries[index].project.responsibilityId],
      ),
    );
  }
}

enum _ProjectAction { edit, archive, restore, delete }

class _ProjectTile extends ConsumerWidget {
  const _ProjectTile({required this.summary, this.responsibilityName});

  final ProjectSummary summary;
  final String? responsibilityName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Project project = summary.project;
    final ProjectProgress progress = summary.progress;
    final TextTheme text = Theme.of(context).textTheme;
    final JalaliDateService jalali = ref.watch(jalaliDateServiceProvider);
    final Color accent = project.color ?? AppColors.accent;

    return AppCard(
      onTap: () => _openEditor(context, existing: project),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  project.title,
                  style: text.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${PersianDigits.fromInt(progress.percent)}٪',
                style: text.titleSmall?.copyWith(color: accent),
              ),
              PopupMenuButton<_ProjectAction>(
                tooltip: 'اقدام‌های ${project.title}',
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: AppColors.textSecondary,
                ),
                onSelected: (_ProjectAction action) =>
                    _handle(context, ref, action),
                itemBuilder: (BuildContext context) =>
                    <PopupMenuEntry<_ProjectAction>>[
                      const PopupMenuItem<_ProjectAction>(
                        value: _ProjectAction.edit,
                        child: Text('ویرایش'),
                      ),
                      if (project.isArchived)
                        const PopupMenuItem<_ProjectAction>(
                          value: _ProjectAction.restore,
                          child: Text('بازگردانی'),
                        )
                      else
                        const PopupMenuItem<_ProjectAction>(
                          value: _ProjectAction.archive,
                          child: Text('بایگانی'),
                        ),
                      const PopupMenuItem<_ProjectAction>(
                        value: _ProjectAction.delete,
                        child: Text('حذف پروژه'),
                      ),
                    ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: progress.percent / 100,
              minHeight: 6,
              backgroundColor: AppColors.surfaceHigh,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _metaLine(jalali, progress),
            style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  String _metaLine(JalaliDateService jalali, ProjectProgress progress) {
    final List<String> parts = <String>[
      _statusLabel(summary.project.status),
      ?responsibilityName,
      progress.hasTasks
          ? '${PersianDigits.fromInt(progress.completedTasks)} از '
                '${PersianDigits.fromInt(progress.totalTasks)} وظیفه'
          : 'بدون وظیفه',
    ];
    final DateTime? due = summary.project.dueDateLocal;
    if (due != null) {
      parts.add('پایان ${jalali.formatShort(due)}');
    }
    return parts.join(' • ');
  }

  String _statusLabel(ProjectStatus status) => switch (status) {
    ProjectStatus.planned => 'برنامه‌ریزی‌شده',
    ProjectStatus.active => 'در جریان',
    ProjectStatus.paused => 'متوقف',
    ProjectStatus.completed => 'تکمیل‌شده',
    ProjectStatus.archived => 'بایگانی‌شده',
  };

  Future<void> _handle(
    BuildContext context,
    WidgetRef ref,
    _ProjectAction action,
  ) async {
    final ProjectsController controller = ref.read(
      projectsControllerProvider.notifier,
    );

    switch (action) {
      case _ProjectAction.edit:
        await _openEditor(context, existing: summary.project);
      case _ProjectAction.archive:
        try {
          await controller.archive(summary.project.id);
        } on ProjectRepositoryException catch (error) {
          if (context.mounted) {
            _showMessage(context, error.message);
          }
        }
      case _ProjectAction.restore:
        try {
          await controller.restore(summary.project.id);
        } on ProjectRepositoryException catch (error) {
          if (context.mounted) {
            _showMessage(context, error.message);
          }
        }
      case _ProjectAction.delete:
        final bool confirmed = await showAppConfirmDialog(
          context: context,
          title: 'حذف پروژه',
          message:
              '«${summary.project.title}» حذف می‌شود، ولی وظایف و '
              'رویدادهای متصل باقی می‌مانند و فقط از پروژه جدا می‌شوند.',
          confirmLabel: 'حذف',
          isDestructive: true,
        );
        if (!confirmed || !context.mounted) {
          return;
        }
        try {
          await controller.remove(summary.project.id);
          if (context.mounted) {
            _showMessage(context, 'پروژه حذف شد؛ فعالیت‌ها حفظ شدند.');
          }
        } on ProjectRepositoryException catch (error) {
          if (context.mounted) {
            _showMessage(context, error.message);
          }
        }
    }
  }
}
