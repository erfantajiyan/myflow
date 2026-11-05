import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../database/responsibility_repository_impl.dart';

/// شناسه‌های ثابت چهار مسئولیت اولیه (بخش ۵.۳ سند).
///
/// ثابت بودن شناسه‌ها یعنی seed کردن دوباره هیچ ردیف تکراری نمی‌سازد و
/// داده‌های بعدی (رویداد/وظیفه) می‌توانند با اطمینان به این شناسه‌ها
/// ارجاع بدهند.
abstract final class SeedResponsibilityIds {
  static const String student = 'resp-student';
  static const String scienceVice = 'resp-science-vice';
  static const String association = 'resp-association';
  static const String personal = 'resp-personal';
}

/// یک ردیف از مسئولیت‌های اولیه.
class SeedResponsibility {
  const SeedResponsibility({
    required this.id,
    required this.name,
    required this.color,
    required this.iconKey,
    required this.description,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final Color color;
  final String iconKey;
  final String description;
  final int sortOrder;
}

/// چهار مسئولیت اولیه‌ی سند، به ترتیبی که باید نمایش داده شوند.
///
/// این‌ها فقط «مقدار اولیه» هستند؛ کاربر می‌تواند نام، رنگ، آیکون و ترتیب
/// همه را تغییر دهد یا بایگانی کند.
const List<SeedResponsibility> defaultResponsibilities = <SeedResponsibility>[
  SeedResponsibility(
    id: SeedResponsibilityIds.student,
    name: 'دانشجو',
    color: AppColors.responsibilityStudent,
    iconKey: 'school',
    description: 'درس، پژوهش و پروژه‌های دانشگاهی',
    sortOrder: 0,
  ),
  SeedResponsibility(
    id: SeedResponsibilityIds.scienceVice,
    name: 'معاونت علمی',
    color: AppColors.responsibilityViceChancellor,
    iconKey: 'science',
    description: 'جلسات، گزارش‌ها و پیگیری‌های معاونت',
    sortOrder: 1,
  ),
  SeedResponsibility(
    id: SeedResponsibilityIds.association,
    name: 'انجمن',
    color: AppColors.responsibilityAssociation,
    iconKey: 'groups',
    description: 'رویدادها و هماهنگی‌های انجمن علمی',
    sortOrder: 2,
  ),
  SeedResponsibility(
    id: SeedResponsibilityIds.personal,
    name: 'شخصی',
    color: AppColors.responsibilityPersonal,
    iconKey: 'person',
    description: 'زندگی شخصی، خانواده و سلامت',
    sortOrder: 3,
  ),
];

/// ساخت چهار مسئولیت اولیه، فقط اگر جدول مسئولیت‌ها خالی باشد.
///
/// خروجی `true` یعنی seed انجام شد و `false` یعنی داده از قبل وجود داشت؛
/// بنابراین فراخوانی دوباره (هر بار باز شدن صفحه) بی‌خطر و idempotent است.
Future<bool> seedDefaultResponsibilities(
  ResponsibilityRepository repository,
) async {
  final List<Responsibility> existing =
      await repository.getAllResponsibilities();
  if (existing.isNotEmpty) {
    return false;
  }

  for (final SeedResponsibility seed in defaultResponsibilities) {
    await repository.insertResponsibility(
      id: seed.id,
      name: seed.name,
      color: seed.color,
      iconKey: seed.iconKey,
      description: seed.description,
      sortOrder: seed.sortOrder,
    );
  }
  return true;
}
