import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myflow/app/theme/app_colors.dart';
import 'package:myflow/database/app_database.dart';
import 'package:myflow/database/responsibility_repository_impl.dart';
import 'package:myflow/features/responsibilities/data/responsibility_seed.dart';

void main() {
  late AppDatabase db;
  late DriftResponsibilityRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftResponsibilityRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('seed مسئولیت‌های اولیه', () {
    test('دیتابیس خالی با چهار مسئولیت سند پر می‌شود', () async {
      final bool seeded = await seedDefaultResponsibilities(repository);

      expect(seeded, isTrue);
      final List<Responsibility> items =
          await repository.getAllResponsibilities();
      expect(items, hasLength(4));
      expect(
        items.map((Responsibility r) => r.name).toList(),
        <String>['دانشجو', 'معاونت علمی', 'انجمن', 'شخصی'],
      );
      expect(
        items.map((Responsibility r) => r.id).toList(),
        <String>[
          SeedResponsibilityIds.student,
          SeedResponsibilityIds.scienceVice,
          SeedResponsibilityIds.association,
          SeedResponsibilityIds.personal,
        ],
      );
      expect(
        items.map((Responsibility r) => r.sortOrder).toList(),
        <int>[0, 1, 2, 3],
      );
      expect(items.first.color, AppColors.responsibilityStudent);
      expect(items.last.color, AppColors.responsibilityPersonal);
      expect(items.every((Responsibility r) => r.isActive), isTrue);
    });

    test('خروجی seed در دیتابیس خالی، همه‌ی مسئولیت‌ها فعال است', () async {
      await seedDefaultResponsibilities(repository);

      final List<Responsibility> active =
          await repository.getActiveResponsibilities();
      expect(active, hasLength(4));
    });

    test('اجرای دوباره seed ردیف تکراری نمی‌سازد', () async {
      await seedDefaultResponsibilities(repository);
      final bool secondRun = await seedDefaultResponsibilities(repository);

      expect(secondRun, isFalse);
      expect(await repository.getAllResponsibilities(), hasLength(4));
    });

    test('اگر داده وجود داشته باشد seed دست نمی‌زند', () async {
      await repository.insertResponsibility(
        id: 'resp-custom',
        name: 'مسئولیت سفارشی',
        color: AppColors.accent,
      );

      final bool seeded = await seedDefaultResponsibilities(repository);

      expect(seeded, isFalse);
      final List<Responsibility> items =
          await repository.getAllResponsibilities();
      expect(items, hasLength(1));
      expect(items.single.name, 'مسئولیت سفارشی');
    });

    test('حتی وقتی همه بایگانی شده‌اند، seed دوباره اجرا نمی‌شود', () async {
      await seedDefaultResponsibilities(repository);
      for (final SeedResponsibility seed in defaultResponsibilities) {
        await repository.archiveResponsibility(seed.id);
      }

      final bool seeded = await seedDefaultResponsibilities(repository);

      expect(seeded, isFalse);
      expect(await repository.getAllResponsibilities(), hasLength(4));
      expect(await repository.getActiveResponsibilities(), isEmpty);
    });
  });
}
