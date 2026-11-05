import 'package:drift/drift.dart';

import '../../shared/enums/app_enums.dart';

/// قاعده‌ی تکرار — جدول `recurrence_rules` (بخش ۱۰.۷ سند).
///
/// منبع حقیقت الگوی تکرار، زمان محلی و منطقه‌ی زمانی است؛ تبدیل به UTC فقط
/// هنگام ساخت هر نمونه انجام می‌شود (بخش ۲۰.۵).
@DataClassName('RecurrenceRuleRow')
class RecurrenceRules extends Table {
  @override
  String get tableName => 'recurrence_rules';

  TextColumn get id => text()();

  TextColumn get frequency => text().map(const RecurrenceFrequencyConverter())();

  IntColumn get intervalValue =>
      integer().named('interval_value').withDefault(const Constant(1))();

  TextColumn get weekdaysJson => text().named('weekdays_json').nullable()();

  IntColumn get monthDay => integer().named('month_day').nullable()();

  IntColumn get monthOfYear => integer().named('month_of_year').nullable()();

  /// تاریخ شروع محلی اولین نمونه، میلادیِ `YYYY-MM-DD`.
  TextColumn get startLocalDate => text().named('start_local_date')();

  /// ساعت محلی `HH:mm:ss`.
  TextColumn get localTime => text().named('local_time')();

  TextColumn get timezoneId => text().named('timezone_id')();

  TextColumn get untilLocalDate => text().named('until_local_date').nullable()();

  DateTimeColumn get startAtUtc => dateTime().named('start_at_utc')();

  IntColumn get countLimit => integer().named('count_limit').nullable()();

  DateTimeColumn get createdAt => dateTime().named('created_at_utc')();

  @override
  Set<Column> get primaryKey => <Column>{id};

  @override
  List<String> get customConstraints => <String>[
    'CHECK (interval_value >= 1)',
    'CHECK (month_day IS NULL OR (month_day >= 1 AND month_day <= 31))',
    'CHECK (month_of_year IS NULL OR (month_of_year >= 1 AND month_of_year <= 12))',
    "CHECK (frequency != 'yearly' OR month_of_year IS NOT NULL)",
    'CHECK (count_limit IS NULL OR count_limit >= 0)',
  ];
}
