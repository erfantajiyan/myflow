import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date_time/jalali_date_parts.dart';
import '../../../core/date_time/jalali_date_service.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_page_scaffold.dart';

/// تقویم شمسی — بخش ۷.۲ سند.
///
/// در این فاز فقط مقصد ناوبری و سربرگ ماه شمسی ساخته شده است؛ شبکه‌ی ماه،
/// نشانگر رنگی رویدادها و خلاصه‌ی روز در فاز ۶ اضافه می‌شوند.
class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final JalaliDateService dates = ref.watch(jalaliDateServiceProvider);
    final JalaliDateParts today = dates.partsOf(ref.watch(nowProvider)());

    return AppPageScaffold(
      title: 'تقویم',
      subtitle: dates.formatMonthYear(today.year, today.month),
      child: Column(
        children: <Widget>[
          AppCard(
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.calendar_month_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'هفته از شنبه شروع می‌شود و ماه‌ها شمسی نمایش داده می‌شوند.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const Expanded(
            child: AppEmptyState(
              icon: Icons.calendar_month_outlined,
              title: 'شبکه‌ی ماه شمسی به‌زودی',
              message:
                  'در فاز تقویم، شبکه‌ی ماه با نشانگر رویدادها، حرکت بین ماه‌ها '
                  'و خلاصه‌ی روز انتخاب‌شده اینجا ساخته می‌شود.',
            ),
          ),
        ],
      ),
    );
  }
}
