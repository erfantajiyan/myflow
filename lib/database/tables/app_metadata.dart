import 'package:drift/drift.dart';

/// فراداده‌ی برنامه — جدول `app_metadata` (بخش ۱۰.۱۲ سند).
///
/// به‌صورت key/value نگهداری می‌شود تا نسخه‌ی schema، نسخه‌ی اپ، زمان آخرین
/// بکاپ و اولین اجرا بدون تغییر جدول قابل ثبت باشند.
@DataClassName('AppMetadataRow')
class AppMetadata extends Table {
  @override
  String get tableName => 'app_metadata';

  TextColumn get key => text()();

  TextColumn get value => text()();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column> get primaryKey => <Column>{key};
}
