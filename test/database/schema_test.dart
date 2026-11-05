import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myflow/database/app_database.dart';

/// تست ساختار schema — دروازه‌ی کیفیت M2 در تراکر:
/// جدول‌ها ساخته می‌شوند، FK فعال است و ایندکس یکتایی نمونه‌های تکرار وجود دارد.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('ساخت جداول', () {
    test('همه‌ی هشت جدول سند ساخته می‌شوند', () async {
      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master "
            "WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
          )
          .get();
      final names = rows.map((row) => row.read<String>('name')).toSet();

      expect(
        names,
        containsAll(<String>[
          'responsibilities',
          'projects',
          'recurrence_rules',
          'events',
          'tasks',
          'reminders',
          'settings',
          'app_metadata',
        ]),
      );
    });

    test('ردیف نسخه‌ی schema در app_metadata نوشته می‌شود', () async {
      final row = await db
          .customSelect(
            "SELECT value FROM app_metadata WHERE key = 'database_version'",
          )
          .getSingleOrNull();

      expect(row, isNotNull);
      expect(row!.read<String>('value'), '1');
    });
  });

  group('قیدهای سطح دیتابیس', () {
    test('PRAGMA foreign_keys پس از باز شدن فعال است', () async {
      final row =
          await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(row.data.values.first, 1);
    });

    test('ایندکس یکتایی نمونه‌های تکرار ساخته شده است', () async {
      final row = await db
          .customSelect(
            "SELECT name FROM sqlite_master "
            "WHERE type = 'index' AND name = 'idx_events_recurrence_instance_unique'",
          )
          .getSingleOrNull();

      expect(row, isNotNull);
    });

    test('قید NOT NULL روی نام مسئولیت اعمال می‌شود', () async {
      await expectLater(
        db.customInsert(
          "INSERT INTO responsibilities "
          "(id, name, color_hex, is_active, sort_order, created_at, updated_at) "
          "VALUES ('x', NULL, '#FF5BA8FF', 1, 0, 0, 0)",
        ),
        throwsA(anything),
      );
    });
  });

  group('کلید خارجی', () {
    Future<void> insertResponsibility(String id) => db.customInsert(
          "INSERT INTO responsibilities "
          "(id, name, color_hex, is_active, sort_order, created_at, updated_at) "
          "VALUES ('$id', 'کار', '#FF5BA8FF', 1, 0, 0, 0)",
        );

    Future<void> insertEvent({
      required String id,
      required String responsibilityId,
      required int start,
      required int end,
    }) =>
        db.customInsert(
          "INSERT INTO events "
          "(id, responsibility_id, title, start_at_utc, end_at_utc, "
          "timezone_id, created_at, updated_at) "
          "VALUES ('$id', '$responsibilityId', 'جلسه', $start, $end, "
          "'Asia/Tehran', 0, 0)",
        );

    test('رویداد با مسئولیت ناموجود رد می‌شود', () async {
      await expectLater(
        insertEvent(
          id: 'e1',
          responsibilityId: 'missing',
          start: 100,
          end: 200,
        ),
        throwsA(anything),
      );
    });

    test('حذف مسئولیتِ دارای رویداد مسدود است (RESTRICT)', () async {
      await insertResponsibility('r1');
      await insertEvent(
        id: 'e1',
        responsibilityId: 'r1',
        start: 100,
        end: 200,
      );

      await expectLater(
        db.customStatement("DELETE FROM responsibilities WHERE id = 'r1'"),
        throwsA(anything),
      );
    });
  });

  group('قید CHECK', () {
    test('پایان رویداد باید بعد از شروع آن باشد', () async {
      await db.customInsert(
        "INSERT INTO responsibilities "
        "(id, name, color_hex, is_active, sort_order, created_at, updated_at) "
        "VALUES ('r1', 'کار', '#FF5BA8FF', 1, 0, 0, 0)",
      );

      await expectLater(
        db.customInsert(
          "INSERT INTO events "
          "(id, responsibility_id, title, start_at_utc, end_at_utc, "
          "timezone_id, created_at, updated_at) "
          "VALUES ('e2', 'r1', 'بد', 300, 100, 'Asia/Tehran', 0, 0)",
        ),
        throwsA(anything),
      );
    });

    test('وظیفه‌ی completed بدون completed_at_utc رد می‌شود', () async {
      await db.customInsert(
        "INSERT INTO responsibilities "
        "(id, name, color_hex, is_active, sort_order, created_at, updated_at) "
        "VALUES ('r1', 'کار', '#FF5BA8FF', 1, 0, 0, 0)",
      );

      await expectLater(
        db.customInsert(
          "INSERT INTO tasks "
          "(id, responsibility_id, title, status, sort_order, created_at, updated_at) "
          "VALUES ('t1', 'r1', 'کار', 'completed', 0, 0, 0)",
        ),
        throwsA(anything),
      );
    });
  });

  group('تراکنش و rollback', () {
    test('خطا در میانه‌ی تراکنش هیچ تغییری باقی نمی‌گذارد', () async {
      await expectLater(
        db.transaction(() async {
          await db.customInsert(
            "INSERT INTO responsibilities "
            "(id, name, color_hex, is_active, sort_order, created_at, updated_at) "
            "VALUES ('r-tx', 'موقت', '#FF5BA8FF', 1, 0, 0, 0)",
          );
          throw StateError('شکست عمدی برای تست rollback');
        }),
        throwsA(isA<StateError>()),
      );

      final row = await db
          .customSelect('SELECT COUNT(*) AS c FROM responsibilities')
          .getSingle();
      expect(row.read<int>('c'), 0);
    });
  });
}
