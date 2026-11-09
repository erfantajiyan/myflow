import 'package:flutter_riverpod/flutter_riverpod.dart';

/// شمارنده‌ی «نسخه‌ی داده».
///
/// صفحه‌هایی که از داده‌ی مشترک می‌خوانند (داشبورد، تقویم، تایم‌لاین) هر
/// تغییری در رویداد یا وظیفه را از طریق Repository می‌بینند، ولی provider
/// خودشان به‌تنهایی خبر ندارد. کنترلرها بعد از هر نوشتن این شمارنده را
/// یک واحد بالا می‌برند و صفحه‌های خواندنی با watch کردنش تازه می‌شوند.
final NotifierProvider<DataRevisionController, int> dataRevisionProvider =
    NotifierProvider<DataRevisionController, int>(
      DataRevisionController.new,
    );

class DataRevisionController extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}
