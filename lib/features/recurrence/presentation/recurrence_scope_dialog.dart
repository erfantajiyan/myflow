import 'package:flutter/material.dart';

import '../domain/recurrence_rule.dart';

/// انتخاب دامنه‌ی ویرایش/حذف یک رویداد تکراری (بخش ۱۱.۹ سند).
///
/// خروجی `null` یعنی کاربر انصراف داده است.
Future<RecurrenceEditScope?> showRecurrenceScopeDialog({
  required BuildContext context,
  required String title,
  bool allowFollowing = true,
}) {
  final List<RecurrenceEditScope> scopes = <RecurrenceEditScope>[
    RecurrenceEditScope.thisOnly,
    if (allowFollowing) RecurrenceEditScope.thisAndFollowing,
    RecurrenceEditScope.allSeries,
  ];
  return showDialog<RecurrenceEditScope>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              'این رویداد بخشی از یک سری تکراری است. تغییر روی کدام بخش '
              'اعمال شود؟',
            ),
            const SizedBox(height: 8),
            for (final RecurrenceEditScope scope in scopes)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(scope.label),
                onTap: () => Navigator.of(dialogContext).pop(scope),
              ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('انصراف'),
          ),
        ],
      );
    },
  );
}
