import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

/// انواع دکمه در Design System.
enum AppButtonVariant {
  /// اقدام اصلی صفحه (پر).
  primary,

  /// اقدام ثانویه (دور خط‌دار).
  secondary,

  /// اقدام کم‌اهمیت (فقط متن).
  ghost,

  /// اقدام مخرب، مثل حذف.
  danger,
}

/// دکمه‌ی مشترک MyFlow با حالت بارگذاری و اندازه‌ی لمسی استاندارد.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;

  /// وقتی true است، محتوای دکمه به جای متن، نشانگر بارگذاری نشان می‌دهد.
  final bool isLoading;

  /// پر کردن عرض والد (برای دکمه‌ی تمام‌عرض فرم‌ها).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null || isLoading;
    final Widget content = isLoading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.onAccent),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 18),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(label),
            ],
          );

    final Widget button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: isDisabled ? null : onPressed,
        child: content,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: isDisabled ? null : onPressed,
        child: content,
      ),
      AppButtonVariant.ghost => TextButton(
        onPressed: isDisabled ? null : onPressed,
        child: content,
      ),
      AppButtonVariant.danger => FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.error,
          foregroundColor: AppColors.onError,
        ),
        onPressed: isDisabled ? null : onPressed,
        child: content,
      ),
    };

    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}
