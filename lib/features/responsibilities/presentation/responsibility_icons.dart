import 'package:flutter/material.dart';

/// آیکون‌های قابل انتخاب برای مسئولیت.
///
/// `iconKey` در دیتابیس ذخیره می‌شود (نه کد آیکون)، تا تغییر مجموعه‌ی
/// آیکون‌ها هیچ‌وقت داده‌ی ذخیره‌شده را خراب نکند؛ کلید ناشناس هم به یک
/// آیکون پیش‌فرض تبدیل می‌شود.
const Map<String, IconData> responsibilityIcons = <String, IconData>{
  'school': Icons.school_outlined,
  'science': Icons.science_outlined,
  'groups': Icons.groups_outlined,
  'person': Icons.person_outline_rounded,
  'work': Icons.work_outline_rounded,
  'home': Icons.home_outlined,
  'favorite': Icons.favorite_outline_rounded,
  'star': Icons.star_outline_rounded,
};

/// آیکون پیش‌فرض وقتی کلید ذخیره‌شده در فهرست بالا نباشد.
const IconData fallbackResponsibilityIcon = Icons.badge_outlined;

IconData responsibilityIcon(String? key) {
  if (key == null) {
    return fallbackResponsibilityIcon;
  }
  return responsibilityIcons[key] ?? fallbackResponsibilityIcon;
}
