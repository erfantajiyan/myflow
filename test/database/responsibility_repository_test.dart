import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myflow/database/app_database.dart';
import 'package:myflow/database/responsibility_repository_impl.dart';

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

  group('درج و خواندن مسئولیت', () {
    test('مسئولیت درج‌شده با همه‌ی فیلدها برگردانده می‌شود', () async {
      final created = await repository.insertResponsibility(
        id: 'resp-work',
        name: 'کار',
        color: const Color(0xFF5BA8FF),
        iconKey: 'work',
        description: 'کارهای حرفه‌ای',
        sortOrder: 2,
      );

      expect(created.id, 'resp-work');
      expect(created.name, 'کار');
      expect(created.iconKey, 'work');
      expect(created.description, 'کارهای حرفه‌ای');
      expect(created.sortOrder, 2);
      expect(created.isActive, isTrue);
      expect(created.archivedAt, isNull);
      expect(created.color, const Color(0xFF5BA8FF));

      final fetched = await repository.getResponsibilityById('resp-work');
      expect(fetched, isNotNull);
      expect(fetched!.name, 'کار');
      expect(fetched.color, const Color(0xFF5BA8FF));
    });

    test('نام با فاصله‌ی اضافه تمیز ذخیره می‌شود', () async {
      final created = await repository.insertResponsibility(
        id: 'resp-trim',
        name: '  خانواده  ',
        color: const Color(0xFF22C55E),
      );
      expect(created.name, 'خانواده');
    });

    test('شناسه‌ی ناموجود null برمی‌گرداند', () async {
      expect(await repository.getResponsibilityById('missing'), isNull);
    });
  });

  group('اعتبارسنجی ورودی', () {
    test('نام خالی خطای قابل تست می‌دهد و چیزی ذخیره نمی‌کند', () async {
      await expectLater(
        repository.insertResponsibility(
          id: 'resp-empty',
          name: '   ',
          color: const Color(0xFF5BA8FF),
        ),
        throwsA(isA<ResponsibilityValidationException>()),
      );
      expect(await repository.getAllResponsibilities(), isEmpty);
    });

    test('نام بلندتر از ۸۰ کاراکتر رد می‌شود', () async {
      await expectLater(
        repository.insertResponsibility(
          id: 'resp-long',
          name: 'ا' * 81,
          color: const Color(0xFF5BA8FF),
        ),
        throwsA(isA<ResponsibilityValidationException>()),
      );
    });

    test('کد رنگ نامعتبر خطا می‌دهد', () {
      expect(
        () => hexToColor('ABC'),
        throwsA(isA<ResponsibilityValidationException>()),
      );
    });
  });

  group('خطاهای “یافت نشد”', () {
    test('ویرایش شناسه‌ی ناموجود خطا می‌دهد', () async {
      await expectLater(
        repository.updateResponsibility(id: 'missing', name: 'جدید'),
        throwsA(isA<ResponsibilityNotFoundException>()),
      );
    });

    test('بایگانی شناسه‌ی ناموجود خطا می‌دهد', () async {
      await expectLater(
        repository.archiveResponsibility('missing'),
        throwsA(isA<ResponsibilityNotFoundException>()),
      );
    });

    test('فعال‌سازی شناسه‌ی ناموجود خطا می‌دهد', () async {
      await expectLater(
        repository.activateResponsibility('missing'),
        throwsA(isA<ResponsibilityNotFoundException>()),
      );
    });
  });

  group('ویرایش', () {
    test('فقط فیلدهای داده‌شده تغییر می‌کنند و بقیه می‌مانند', () async {
      await repository.insertResponsibility(
        id: 'resp-edit',
        name: 'سلامت',
        color: const Color(0xFF22C55E),
        iconKey: 'health',
        description: 'ورزش و تغذیه',
        sortOrder: 1,
      );

      await repository.updateResponsibility(
        id: 'resp-edit',
        name: 'سلامت و ورزش',
      );

      final updated = await repository.getResponsibilityById('resp-edit');
      expect(updated!.name, 'سلامت و ورزش');
      expect(updated.color, const Color(0xFF22C55E));
      expect(updated.iconKey, 'health');
      expect(updated.description, 'ورزش و تغذیه');
      expect(updated.sortOrder, 1);
    });

    test('رنگ و ترتیب هم قابل تغییر است', () async {
      await repository.insertResponsibility(
        id: 'resp-color',
        name: 'یادگیری',
        color: const Color(0xFF5BA8FF),
        sortOrder: 0,
      );

      await repository.updateResponsibility(
        id: 'resp-color',
        color: const Color(0xFFF59E0B),
        sortOrder: 5,
      );

      final updated = await repository.getResponsibilityById('resp-color');
      expect(updated!.color, const Color(0xFFF59E0B));
      expect(updated.sortOrder, 5);
    });

    test('نام خالی در ویرایش رد می‌شود و رکورد دست‌نخورده می‌ماند', () async {
      await repository.insertResponsibility(
        id: 'resp-guard',
        name: 'خانواده',
        color: const Color(0xFF5BA8FF),
      );

      await expectLater(
        repository.updateResponsibility(id: 'resp-guard', name: ''),
        throwsA(isA<ResponsibilityValidationException>()),
      );

      final unchanged = await repository.getResponsibilityById('resp-guard');
      expect(unchanged!.name, 'خانواده');
    });
  });

  group('بایگانی و حذف نرم', () {
    test('مسئولیت بایگانی‌شده از لیست فعال حذف می‌شود ولی از دیتابیس نمی‌رود',
        () async {
      await repository.insertResponsibility(
        id: 'resp-archive',
        name: 'پروژه‌ی قدیمی',
        color: const Color(0xFFA78BFA),
      );

      await repository.archiveResponsibility('resp-archive');

      expect(await repository.getActiveResponsibilities(), isEmpty);
      final archived = await repository.getResponsibilityById('resp-archive');
      expect(archived, isNotNull);
      expect(archived!.isActive, isFalse);
      expect(archived.archivedAt, isNotNull);
      expect(await repository.getAllResponsibilities(), hasLength(1));
    });

    test('فعال‌سازی دوباره مسئولیت را به لیست فعال برمی‌گرداند', () async {
      await repository.insertResponsibility(
        id: 'resp-revive',
        name: 'مطالعه',
        color: const Color(0xFF38BDF8),
      );
      await repository.archiveResponsibility('resp-revive');
      await repository.activateResponsibility('resp-revive');

      final active = await repository.getActiveResponsibilities();
      expect(active, hasLength(1));
      expect(active.single.id, 'resp-revive');
      expect(active.single.archivedAt, isNull);
    });

    test('حذف فیزیکی ردیف را کاملاً پاک می‌کند', () async {
      await repository.insertResponsibility(
        id: 'resp-delete',
        name: 'موقت',
        color: const Color(0xFF64748B),
      );

      await repository.permanentlyDeleteResponsibility('resp-delete');

      expect(await repository.getResponsibilityById('resp-delete'), isNull);
      expect(await repository.getAllResponsibilities(), isEmpty);
    });
  });

  group('ترتیب نمایش', () {
    test('لیست فعال بر اساس sortOrder صعودی مرتب است', () async {
      await repository.insertResponsibility(
        id: 'resp-c',
        name: 'سوم',
        color: const Color(0xFF5BA8FF),
        sortOrder: 30,
      );
      await repository.insertResponsibility(
        id: 'resp-a',
        name: 'اول',
        color: const Color(0xFF5BA8FF),
        sortOrder: 10,
      );
      await repository.insertResponsibility(
        id: 'resp-b',
        name: 'دوم',
        color: const Color(0xFF5BA8FF),
        sortOrder: 20,
      );

      final active = await repository.getActiveResponsibilities();
      expect(active.map((r) => r.name).toList(), <String>['اول', 'دوم', 'سوم']);
    });
  });

  group('تبدیل رنگ', () {
    test('HEX شش‌رقمی با آلفای کامل خوانده می‌شود', () {
      expect(hexToColor('#5BA8FF'), const Color(0xFF5BA8FF));
      expect(hexToColor('5BA8FF'), const Color(0xFF5BA8FF));
    });

    test('HEX هشت‌رقمی همان‌طور که هست خوانده می‌شود', () {
      expect(hexToColor('#805BA8FF'), const Color(0x805BA8FF));
    });

    test('رفت‌وبرگشت Color → HEX → Color یکسان است', () {
      const original = Color(0xFF5BA8FF);
      expect(hexToColor(original.toHex()), original);
    });
  });

  group('از بین رفتن داده بعد از بستن دیتابیس حافظه‌ای', () {
    test('دیتابیس جدید خالی است (تست‌ها به هم نشت نمی‌کنند)', () async {
      await repository.insertResponsibility(
        id: 'resp-iso',
        name: 'ایزوله',
        color: const Color(0xFF5BA8FF),
      );
      await db.close();

      db = AppDatabase(NativeDatabase.memory());
      repository = DriftResponsibilityRepository(db);

      expect(await repository.getAllResponsibilities(), isEmpty);
    });
  });
}
