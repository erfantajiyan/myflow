import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/database_providers.dart';
import '../../../database/project_repository_impl.dart';
import '../../../shared/enums/app_enums.dart';

final Provider<ProjectRepository> projectRepositoryProvider =
    Provider<ProjectRepository>(
      (ref) => DriftProjectRepository(ref.watch(appDatabaseProvider)),
    );

final AsyncNotifierProvider<ProjectsController, List<ProjectSummary>>
projectsControllerProvider =
    AsyncNotifierProvider<ProjectsController, List<ProjectSummary>>(
      ProjectsController.new,
    );

class ProjectsController extends AsyncNotifier<List<ProjectSummary>> {
  @override
  Future<List<ProjectSummary>> build() {
    return ref.read(projectRepositoryProvider).getProjectSummaries();
  }

  Future<void> refresh() async {
    state = const AsyncValue<List<ProjectSummary>>.loading();
    state = await AsyncValue.guard(
      () => ref.read(projectRepositoryProvider).getProjectSummaries(),
    );
  }

  Future<Project> create({
    required String responsibilityId,
    required String title,
    String? description,
    ProjectStatus status = ProjectStatus.planned,
    Priority priority = Priority.medium,
    DateTime? startDate,
    DateTime? dueDate,
    String? colorHex,
    ProgressMode progressMode = ProgressMode.automatic,
    int? manualProgress,
  }) async {
    final Project created = await ref
        .read(projectRepositoryProvider)
        .insertProject(
          responsibilityId: responsibilityId,
          title: title,
          description: description,
          status: status,
          priority: priority,
          startDate: startDate,
          dueDate: dueDate,
          colorHex: colorHex,
          progressMode: progressMode,
          manualProgress: manualProgress,
        );
    await refresh();
    return created;
  }

  Future<void> edit({
    required String id,
    String? responsibilityId,
    String? title,
    String? description,
    ProjectStatus? status,
    Priority? priority,
    DateTime? startDate,
    DateTime? dueDate,
    String? colorHex,
    ProgressMode? progressMode,
    int? manualProgress,
    bool clearStartDate = false,
    bool clearDueDate = false,
  }) async {
    await ref
        .read(projectRepositoryProvider)
        .updateProject(
          id: id,
          responsibilityId: responsibilityId,
          title: title,
          description: description,
          status: status,
          priority: priority,
          startDate: startDate,
          dueDate: dueDate,
          colorHex: colorHex,
          progressMode: progressMode,
          manualProgress: manualProgress,
          clearStartDate: clearStartDate,
          clearDueDate: clearDueDate,
        );
    await refresh();
  }

  Future<void> archive(String id) async {
    await ref.read(projectRepositoryProvider).archiveProject(id);
    await refresh();
  }

  Future<void> restore(String id) async {
    await ref.read(projectRepositoryProvider).restoreProject(id);
    await refresh();
  }

  Future<void> remove(String id) async {
    await ref.read(projectRepositoryProvider).deleteProject(id);
    await refresh();
  }
}
