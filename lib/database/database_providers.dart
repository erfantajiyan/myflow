import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'connection.dart';

/// نمونه‌ی واحد دیتابیس برنامه.
///
/// UI هرگز مستقیماً به این provider دست نمی‌زند؛ فقط repositoryها از آن
/// استفاده می‌کنند، تا قاعده‌ی «UI به SQLite وصل نمی‌شود» (بخش ۳.۱ تراکر)
/// شکسته نشود.
///
/// در تست‌ها با `overrideWith` به یک دیتابیس حافظه‌ای
/// (`AppDatabase(NativeDatabase.memory())`) جایگزین می‌شود تا هیچ فایلی روی
/// دیسک ساخته نشود.
final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>((
  Ref ref,
) {
  final AppDatabase database = AppDatabase(openAppDatabaseConnection());
  ref.onDispose(database.close);
  return database;
});
