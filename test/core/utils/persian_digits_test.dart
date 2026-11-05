import 'package:flutter_test/flutter_test.dart';
import 'package:myflow/core/utils/persian_digits.dart';

void main() {
  group('PersianDigits', () {
    test('ارقام لاتین را به فارسی تبدیل می‌کند', () {
      expect(PersianDigits.convert('1404/08/10'), '۱۴۰۴/۰۸/۱۰');
    });

    test('حروف و فاصله‌ها دست‌نخورده می‌مانند', () {
      expect(PersianDigits.convert('آبان 1404'), 'آبان ۱۴۰۴');
    });

    test('عدد را با ارقام فارسی برمی‌گرداند', () {
      expect(PersianDigits.fromInt(7), '۷');
      expect(PersianDigits.fromInt(1404), '۱۴۰۴');
    });

    test('دو رقمی با صفر ابتدایی', () {
      expect(PersianDigits.padded2(5), '۰۵');
      expect(PersianDigits.padded2(23), '۲۳');
    });

    test('ارقام فارسی را به لاتین برمی‌گرداند', () {
      expect(PersianDigits.toLatin('۱۰:۱۵'), '10:15');
      expect(PersianDigits.toLatin('۱۴۰۵/۰۸/۱۴'), '1405/08/14');
    });

    test('ارقام عربی را هم به لاتین برمی‌گرداند', () {
      expect(PersianDigits.toLatin('٠٩:٣٠'), '09:30');
    });

    test('ورودی لاتین و حروف در toLatin دست‌نخورده می‌ماند', () {
      expect(PersianDigits.toLatin('10:15'), '10:15');
      expect(PersianDigits.toLatin('ساعت ۱۰'), 'ساعت 10');
    });
  });
}
