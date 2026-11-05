import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// اسکلت مشترک صفحه‌ها: عنوان، زیرعنوان اختیاری، اقدام‌ها و padding یکسان.
///
/// یکسان بودن این اسکلت تضمین می‌کند موقعیت کاربر در برنامه روشن بماند
/// (معیار تجربه‌ی کاربری سند).
class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions,
    this.floatingActionButton,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.xs,
      AppSpacing.md,
      AppSpacing.md,
    ),
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final bool hasSubtitle = subtitle != null;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: hasSubtitle ? 68 : kToolbarHeight,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(title),
            if (hasSubtitle)
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
        actions: actions,
      ),
      body: SafeArea(
        child: Padding(padding: padding, child: child),
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
