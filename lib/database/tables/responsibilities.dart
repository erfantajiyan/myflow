import 'package:drift/drift.dart';

/// مسئولیت‌ها — جدول `responsibilities` (بخش ۱۰.۳ سند).
@DataClassName('ResponsibilityRow')
class Responsibilities extends Table {
  @override
  String get tableName => 'responsibilities';

  TextColumn get id => text()();

  TextColumn get name => text().withLength(min: 1, max: 80)();

  TextColumn get colorHex =>
      text().named('color_hex').withLength(min: 7, max: 9)();

  TextColumn get iconKey => text().named('icon_key').nullable()();

  TextColumn get description => text().nullable()();

  BoolColumn get isActive =>
      boolean().named('is_active').withDefault(const Constant(true))();

  IntColumn get sortOrder =>
      integer().named('sort_order').withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().named('created_at')();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  DateTimeColumn get archivedAt => dateTime().named('archived_at').nullable()();

  @override
  Set<Column> get primaryKey => <Column>{id};
}
