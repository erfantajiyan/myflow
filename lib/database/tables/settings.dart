import 'package:drift/drift.dart';
export '../../shared/enums/app_enums.dart';

/// تنظیمات — جدول `settings` (بخش ۱۰.۱۱ سند).
@DataClassName('SettingRow')
class Settings extends Table {
  @override
  String get tableName => 'settings';

  TextColumn get key => text()();

  TextColumn get value => text()();

  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column> get primaryKey => <Column>{key};
}
