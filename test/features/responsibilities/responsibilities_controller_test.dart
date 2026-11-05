import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myflow/database/app_database.dart';
import 'package:myflow/database/database_providers.dart';
import 'package:myflow/database/responsibility_repository_impl.dart';
import 'package:myflow/features/responsibilities/data/responsibilities_controller.dart';
import 'package:myflow/features/responsibilities/data/responsibility_seed.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWith((Ref ref) => db),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  ResponsibilitiesController controller() =>
      container.read(responsibilitiesControllerProvider.notifier);

  Future<List<Responsibility>> load() =>
      container.read(responsibilitiesControllerProvider.future);

  group('بارگذاری اولیه', () {
    test('اولین باز شدن، چهار مسئولیت اولیه را seed می‌کند', () async {
      final List<Responsibility> items = await load();

      expect(items, hasLength(4));
      expect(items.first.name, 'دانشجو');
      expect(controller().active, hasLength(4));
      expect(controller().archived, isEmpty);
    });
  });

  group('ساخت', () {
    test('مسئولیت جدید بعد از بقیه قرار می‌گیرد', () async {
      await load();

      await controller().create(
        name: 'کار داوطلبانه',
        color: const Color(0xFF38BDF8),
        iconKey: 'favorite',
        description: 'فعالیت‌های خیریه',
      );

      final List<Responsibility> items = container
          .read(responsibilitiesControllerProvider)
          .requireValue;
      expect(items, hasLength(5));
      final Responsibility created = items.last;
      expect(created.name, 'کار داوطلبانه');
      expect(created.sortOrder, 4);
      expect(created.iconKey, 'favorite');
      expect(created.description, 'فعالیت‌های خیریه');
      expect(created.isActive, isTrue);
    });

    test('نام خالی رد می‌شود و فهرست دست‌نخورده می‌ماند', () async {
      await load();

      await expectLater(
        controller().create(name: '   ', color: const Color(0xFF38BDF8)),
        throwsA(isA<ResponsibilityValidationException>()),
      );

      final List<Responsibility> items = container
          .read(responsibilitiesControllerProvider)
          .requireValue;
      expect(items, hasLength(4));
    });
  });

  group('ویرایش', () {
    test('نام و رنگ و آیکون ذخیره می‌شود', () async {
      await load();

      await controller().edit(
        id: SeedResponsibilityIds.student,
        name: 'دانشجوی ارشد',
        color: const Color(0xFFF59E0B),
        iconKey: 'star',
        description: 'پایان‌نامه',
      );

      final List<Responsibility> items = container
          .read(responsibilitiesControllerProvider)
          .requireValue;
      final Responsibility edited = items.firstWhere(
        (Responsibility r) => r.id == SeedResponsibilityIds.student,
      );
      expect(edited.name, 'دانشجوی ارشد');
      expect(edited.color, const Color(0xFFF59E0B));
      expect(edited.iconKey, 'star');
      expect(edited.description, 'پایان‌نامه');
    });

    test('ویرایش شناسه‌ی ناموجود خطای قابل تست می‌دهد', () async {
      await load();

      await expectLater(
        controller().edit(id: 'missing', name: 'هرچی'),
        throwsA(isA<ResponsibilityNotFoundException>()),
      );
    });
  });

  group('بایگانی و فعال‌سازی', () {
    test('بایگانی از فهرست فعال خارج و به بایگانی می‌رود', () async {
      await load();

      await controller().archive(SeedResponsibilityIds.personal);

      expect(controller().active, hasLength(3));
      expect(controller().archived, hasLength(1));
      expect(
        controller().archived.single.name,
        'شخصی',
      );
    });

    test('فعال‌سازی دوباره مسئولیت را برمی‌گرداند', () async {
      await load();
      await controller().archive(SeedResponsibilityIds.personal);
      await controller().activate(SeedResponsibilityIds.personal);

      expect(controller().active, hasLength(4));
      expect(controller().archived, isEmpty);
    });
  });

  group('ترتیب', () {
    test('انتقال به بالا ترتیب دو مسئولیت را جابه‌جا می‌کند', () async {
      await load();

      await controller().move(SeedResponsibilityIds.personal, up: true);

      final List<String> names = controller().active
          .map((Responsibility r) => r.name)
          .toList();
      expect(names, <String>['دانشجو', 'معاونت علمی', 'شخصی', 'انجمن']);
    });

    test('اولین مسئولیت جایی برای بالاتر رفتن ندارد', () async {
      await load();

      await controller().move(SeedResponsibilityIds.student, up: true);

      expect(
        controller().active.first.name,
        'دانشجو',
      );
    });

    test('آخرین مسئولیت جایی برای پایین رفتن ندارد', () async {
      await load();

      await controller().move(SeedResponsibilityIds.personal, up: false);

      expect(
        controller().active.last.name,
        'شخصی',
      );
    });
  });
}
