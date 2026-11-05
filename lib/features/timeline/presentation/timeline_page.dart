import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date_time/jalali_date_service.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_page_scaffold.dart';

/// تایم‌لاین ۲۴ ساعته — بخش ۷.۳ سند (مهم‌ترین صفحه‌ی محصول).
///
/// در این فاز فقط مسیر و اسکلت صفحه آماده است؛ محور ۰۰ تا ۲۴، بلوک رویدادها،
/// خط زمان فعلی و بازه‌های خالی در فاز ۷ ساخته می‌شوند.
class TimelinePage extends ConsumerWidget {
  const TimelinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final JalaliDateService dates = ref.watch(jalaliDateServiceProvider);
    final DateTime now = ref.watch(nowProvider)();

    return AppPageScaffold(
      title: 'تایم‌لاین',
      subtitle: '${dates.weekDayName(now)} • ${dates.formatLong(now)}',
      actions: <Widget>[
        IconButton(
          tooltip: 'بستن',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
      child: const AppEmptyState(
        icon: Icons.view_day_outlined,
        title: 'تایم‌لاین روز',
        message:
            'محور عمودی ۰۰:۰۰ تا ۲۴:۰۰ با بلوک رویدادها، خط زمان فعلی و '
            'بازه‌های آزاد در فاز تایم‌لاین ساخته می‌شود.',
        action: SizedBox.shrink(),
      ),
    );
  }
}
