import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/database_providers.dart';
import '../../../database/responsibility_repository_impl.dart';
import 'responsibility_seed.dart';

/// تنها مسیر دسترسی UI به repository مسئولیت‌ها.
final Provider<ResponsibilityRepository> responsibilityRepositoryProvider =
    Provider<ResponsibilityRepository>((Ref ref) {
      return DriftResponsibilityRepository(ref.watch(appDatabaseProvider));
    });

/// وضعیت فهرست مسئولیت‌ها برای UI.
///
/// خواندن از دیتابیس، seed اولیه و همه‌ی تغییرها از همین‌جا می‌گذرد تا
/// صفحه‌ها هیچ‌وقت به Drift دسترسی مستقیم نداشته باشند.
final AsyncNotifierProvider<ResponsibilitiesController, List<Responsibility>>
responsibilitiesControllerProvider =
    AsyncNotifierProvider<ResponsibilitiesController, List<Responsibility>>(
      ResponsibilitiesController.new,
    );

class ResponsibilitiesController extends AsyncNotifier<List<Responsibility>> {
  ResponsibilityRepository get _repository =>
      ref.read(responsibilityRepositoryProvider);

  @override
  Future<List<Responsibility>> build() async {
    final ResponsibilityRepository repository = ref.watch(
      responsibilityRepositoryProvider,
    );
    await seedDefaultResponsibilities(repository);
    return repository.getAllResponsibilities();
  }

  /// فهرست مسئولیت‌های فعال، مرتب بر اساس `sortOrder`.
  List<Responsibility> get active {
    final List<Responsibility> all =
        state.value ?? const <Responsibility>[];
    return all
        .where((Responsibility r) => r.isActive && r.archivedAt == null)
        .toList(growable: false);
  }

  /// فهرست مسئولیت‌های بایگانی‌شده.
  List<Responsibility> get archived {
    final List<Responsibility> all =
        state.value ?? const <Responsibility>[];
    return all
        .where((Responsibility r) => !r.isActive || r.archivedAt != null)
        .toList(growable: false);
  }

  Future<void> create({
    required String name,
    required Color color,
    String? iconKey,
    String? description,
  }) async {
    final List<Responsibility> all = await _repository.getAllResponsibilities();
    final int nextSortOrder = all.isEmpty
        ? 0
        : all
                  .map((Responsibility r) => r.sortOrder)
                  .reduce((int a, int b) => math.max(a, b)) +
              1;

    await _repository.insertResponsibility(
      id: _newId(),
      name: name,
      color: color,
      iconKey: iconKey,
      description: description,
      sortOrder: nextSortOrder,
    );
    await _reload();
  }

  Future<void> edit({
    required String id,
    String? name,
    Color? color,
    String? iconKey,
    String? description,
  }) async {
    await _repository.updateResponsibility(
      id: id,
      name: name,
      color: color,
      iconKey: iconKey,
      description: description,
    );
    await _reload();
  }

  Future<void> archive(String id) async {
    await _repository.archiveResponsibility(id);
    await _reload();
  }

  Future<void> activate(String id) async {
    await _repository.activateResponsibility(id);
    await _reload();
  }

  /// جابه‌جایی یک مسئولیت فعال با همسایه‌ی بالا یا پایینش.
  ///
  /// ترتیب با رد و بدل کردن `sortOrder` دو ردیف ذخیره می‌شود؛ بنابراین
  /// بعد از بستن و باز کردن برنامه هم حفظ می‌شود.
  Future<void> move(String id, {required bool up}) async {
    final List<Responsibility> ordered = await _repository
        .getActiveResponsibilities();
    final int index = ordered.indexWhere((Responsibility r) => r.id == id);
    if (index < 0) {
      return;
    }
    final int target = up ? index - 1 : index + 1;
    if (target < 0 || target >= ordered.length) {
      return;
    }

    final Responsibility current = ordered[index];
    final Responsibility neighbour = ordered[target];
    await _repository.updateResponsibility(
      id: current.id,
      sortOrder: neighbour.sortOrder,
    );
    await _repository.updateResponsibility(
      id: neighbour.id,
      sortOrder: current.sortOrder,
    );
    await _reload();
  }

  Future<void> _reload() async {
    state = AsyncData<List<Responsibility>>(
      await _repository.getAllResponsibilities(),
    );
  }

  String _newId() {
    final int stamp = DateTime.now().microsecondsSinceEpoch;
    return 'resp-${stamp.toRadixString(36)}';
  }
}
