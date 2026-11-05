import 'package:flutter/material.dart';
import 'package:drift/drift.dart';

import 'app_database.dart';

// ignore_for_file: deprecated_member_use

/// خطای پایه‌ی لایه‌ی repository مسئولیت‌ها.
///
/// همه‌ی خطاهای این لایه از این نوع‌اند تا در Provider و UI قابل تشخیص و
/// قابل تست باشند (بخش «خطاهای قابل تست» سند).
sealed class ResponsibilityRepositoryException implements Exception {
  const ResponsibilityRepositoryException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// داده‌ی ورودی نامعتبر است (نام خالی، رنگ نامعتبر و …).
final class ResponsibilityValidationException
    extends ResponsibilityRepositoryException {
  const ResponsibilityValidationException(super.message);
}

/// مسئولیتِ درخواستی وجود ندارد.
final class ResponsibilityNotFoundException
    extends ResponsibilityRepositoryException {
  const ResponsibilityNotFoundException(this.id)
      : super('مسئولیت با شناسه‌ی «$id» پیدا نشد.');

  final String id;
}

/// قرارداد repository مسئولیت‌ها.
///
/// هر repository باید به داده دسترسی داشته باشد بدون اینکه UI
/// مستقیم دیتابیس را بداند.
abstract class ResponsibilityRepository {
  /// لیست مسئولیت‌های فعال.
  Future<List<Responsibility>> getActiveResponsibilities();

  /// لیست تمام مسئولیت‌ها (فعال و بایگانی‌شده).
  Future<List<Responsibility>> getAllResponsibilities();

  /// مسئولیت بر اساس شناسه‌ی UUID.
  Future<Responsibility?> getResponsibilityById(String id);

  /// افزودن مسئولیت با رنگ، آیکون و ترتیب.
  Future<Responsibility> insertResponsibility({
    required String id,
    required String name,
    required Color color,
    String? iconKey,
    String? description,
    int sortOrder = 0,
  });

  /// ویرایش parameters مسئولیت.
  Future<void> updateResponsibility({
    required String id,
    String? name,
    Color? color,
    String? iconKey,
    String? description,
    int? sortOrder,
  });

  /// بایگانی مسئولیت (حذف نرم) — برای فعالیت‌های جدید قابل انتخاب نیست.
  /// مسئولیت‌های بایگانی‌شده در لیست فعالیت‌های جدید قابل انتخاب نیستند.
  Future<void> archiveResponsibility(String id);

  /// فعال‌سازی مسئولیت را که بایگانی‌شده است.
  Future<void> activateResponsibility(String id);

  /// حذف فیزیکی (فقط در مسیر پاک‌سازی پیشرفته پس از بکاپ مجاز).
  Future<void> permanentlyDeleteResponsibility(String id);
}

/// مدل دامنه‌ی مسئولیت.
///
/// این مدل فقط دیتای منطقی است و مستقل از لایه‌ی دیتابیس می‌باشد.
/// در UI مستقیماً به این مدل دسترسی ندارد و از طریق
/// Repository به داده می‌رسد.
class Responsibility {
  final String id;
  final String name;
  final Color color;
  final String? iconKey;
  final String? description;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  const Responsibility({
    required this.id,
    required this.name,
    required this.color,
    this.iconKey,
    this.description,
    required this.isActive,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  Responsibility copyWith({
    String? id,
    String? name,
    Color? color,
    String? iconKey,
    String? description,
    bool? isActive,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? archivedAt,
  }) {
    return Responsibility(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      iconKey: iconKey ?? this.iconKey,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }
}

/// برگرداننده‌ی رنگ HEX (مثلاً `#3B82F6` یا `3B82F6`) به [Color].
///
/// قالب ۶ رقمی RGB با آلفای کامل تفسیر می‌شود و قالب ۸ رقمی RGBA/ARGB
/// همان‌طور که هست استفاده می‌شود.
Color hexToColor(String hex) {
  final normalized = hex.trim().replaceFirst('#', '');
  if (normalized.length == 6 || normalized.length == 8) {
    final parsed = int.parse(normalized, radix: 16);
    if (normalized.length == 6) {
      return Color(parsed | 0xFF000000);
    }
    return Color(parsed);
  }
  throw ResponsibilityValidationException(
    'کد رنگ باید ۶ یا ۸ رقم هگز باشد، ولی «$hex» بود.',
  );
}

/// نگاشت [ResponsibilityRow] → [Responsibility].
Responsibility fromRow(ResponsibilityRow row) {
  return Responsibility(
    id: row.id,
    name: row.name,
    color: hexToColor(row.colorHex),
    iconKey: row.iconKey,
    description: row.description,
    isActive: row.isActive,
    sortOrder: row.sortOrder,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    archivedAt: row.archivedAt,
  );
}

/// اعتبارسنجی نام مسئولیت مطابق محدودیت جدول (`length 1..80`).
String _validateName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    throw const ResponsibilityValidationException(
      'نام مسئولیت نمی‌تواند خالی باشد.',
    );
  }
  if (trimmed.length > 80) {
    throw const ResponsibilityValidationException(
      'نام مسئولیت نباید بیشتر از ۸۰ کاراکتر باشد.',
    );
  }
  return trimmed;
}

/// پیاده‌سازی [ResponsibilityRepository] با Drift.
///
/// تست‌ها این کلاس را با `NativeDatabase.memory()` می‌سازند.
class DriftResponsibilityRepository implements ResponsibilityRepository {
  final AppDatabase _db;

  DriftResponsibilityRepository(this._db);

  @override
  Future<List<Responsibility>> getActiveResponsibilities() async {
    final rows = await (_db.select(_db.responsibilities)
          ..where((t) => t.isActive.equals(true))
          ..where((t) => t.archivedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    return rows.map(fromRow).toList();
  }

  @override
  Future<List<Responsibility>> getAllResponsibilities() async {
    final rows = await (_db.select(_db.responsibilities)
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    return rows.map(fromRow).toList();
  }

  @override
  Future<Responsibility?> getResponsibilityById(String id) async {
    final row = await (_db.select(_db.responsibilities)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : fromRow(row);
  }

  @override
  Future<Responsibility> insertResponsibility({
    required String id,
    required String name,
    required Color color,
    String? iconKey,
    String? description,
    int sortOrder = 0,
  }) async {
    final now = DateTime.now();
    await _db.into(_db.responsibilities).insert(
          ResponsibilitiesCompanion.insert(
            id: id,
            name: _validateName(name),
            colorHex: color.toHex(),
            iconKey: Value(iconKey),
            description: Value(description),
            sortOrder: Value(sortOrder),
            createdAt: now,
            updatedAt: now,
          ),
        );
    final inserted = await getResponsibilityById(id);
    if (inserted == null) {
      throw ResponsibilityNotFoundException(id);
    }
    return inserted;
  }

  @override
  Future<void> updateResponsibility({
    required String id,
    String? name,
    Color? color,
    String? iconKey,
    String? description,
    int? sortOrder,
  }) async {
    final existing = await getResponsibilityById(id);
    if (existing == null) {
      throw ResponsibilityNotFoundException(id);
    }
    final companion = ResponsibilitiesCompanion(
      name: name != null ? Value(_validateName(name)) : const Value.absent(),
      colorHex:
          color != null ? Value(color.toHex()) : const Value.absent(),
      iconKey: iconKey != null ? Value(iconKey) : const Value.absent(),
      description:
          description != null ? Value(description) : const Value.absent(),
      sortOrder: sortOrder != null ? Value(sortOrder) : const Value.absent(),
      updatedAt: Value(DateTime.now()),
    );
    await (_db.update(_db.responsibilities)..where((t) => t.id.equals(id)))
        .write(companion);
  }

  @override
  Future<void> archiveResponsibility(String id) async {
    final existing = await getResponsibilityById(id);
    if (existing == null) {
      throw ResponsibilityNotFoundException(id);
    }
    final now = DateTime.now();
    await (_db.update(_db.responsibilities)..where((t) => t.id.equals(id)))
        .write(
      ResponsibilitiesCompanion(
        isActive: const Value(false),
        archivedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<void> activateResponsibility(String id) async {
    final existing = await getResponsibilityById(id);
    if (existing == null) {
      throw ResponsibilityNotFoundException(id);
    }
    await (_db.update(_db.responsibilities)..where((t) => t.id.equals(id)))
        .write(
      ResponsibilitiesCompanion(
        isActive: const Value(true),
        // باید صریحاً NULL شود؛ «absent» یعنی «تغییر نده» و ردیف همچنان
        // در فیلتر `archived_at IS NULL` لیست فعال جا می‌ماند.
        archivedAt: const Value<DateTime?>(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> permanentlyDeleteResponsibility(String id) async {
    await (_db.delete(_db.responsibilities)..where((t) => t.id.equals(id)))
        .go();
  }
}

extension ColorToHex on Color {
  /// تبدیل رنگ به HEX ۸ رقمی با پیشوند `#` (قالب `#AARRGGBB`).
  String toHex() {
    final int argb = value;
    final String hex =
        (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
    final String alpha =
        ((argb >> 24) & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase();
    return '#$alpha$hex';
  }
}
