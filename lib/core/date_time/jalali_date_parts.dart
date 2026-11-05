import 'package:flutter/foundation.dart';

/// یک تاریخ شمسی بدون ساعت.
///
/// این کلاس عمداً به هیچ پکیج تقویمی وابسته نیست تا لایه‌ی دامنه مستقل بماند
/// (بخش ۲۰.۱۳ سند: فقط JalaliDateService مجاز است پکیج تاریخ را import کند).
@immutable
class JalaliDateParts implements Comparable<JalaliDateParts> {
  const JalaliDateParts({
    required this.year,
    required this.month,
    required this.day,
  });

  final int year;
  final int month;
  final int day;

  @override
  int compareTo(JalaliDateParts other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is JalaliDateParts &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => '$year/$month/$day';
}
