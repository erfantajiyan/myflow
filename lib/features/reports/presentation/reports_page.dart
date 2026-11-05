import 'package:flutter/material.dart';

import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_page_scaffold.dart';

/// گزارش‌ها — بخش ۷.۶ سند.
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppPageScaffold(
      title: 'گزارش‌ها',
      subtitle: 'زمان برنامه‌ریزی‌شده و وضعیت وظایف',
      child: AppEmptyState(
        icon: Icons.insights_outlined,
        title: 'گزارشی برای نمایش نیست',
        message:
            'گزارش زمان هر مسئولیت، وظایف تکمیل‌شده و عقب‌افتاده و پیشرفت '
            'پروژه‌ها پس از اتصال داده‌ی واقعی ساخته می‌شود.',
      ),
    );
  }
}
