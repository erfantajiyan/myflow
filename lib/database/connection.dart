import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

/// نام دیتابیس محلی MyFlow.
const String appDatabaseName = 'myflow';

/// باز کردن اتصال دیتابیس روی پلتفرم فعلی.
///
/// - روی موبایل/دسکتاپ فایل `myflow.sqlite` در پوشه‌ی پشتیبانی برنامه ساخته می‌شود.
/// - روی وب از WebAssembly استفاده می‌شود؛ برای همین `sqlite3.wasm` و
///   `drift_worker.dart.js` داخل پوشه‌ی `web/` قرار گرفته‌اند.
///
/// این تابع در تست‌ها استفاده نمی‌شود؛ تست‌ها `NativeDatabase.memory()` را
/// مستقیم به [AppDatabase] می‌دهند.
DatabaseConnection openAppDatabaseConnection() {
  return driftDatabase(
    name: appDatabaseName,
    native: DriftNativeOptions(
      databaseDirectory: getApplicationSupportDirectory,
    ),
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.dart.js'),
    ),
  );
}
