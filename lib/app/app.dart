import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme/app_theme.dart';

/// ریشه‌ی برنامه: تم تیره، زبان فارسی و چیدمان راست‌به‌چپ.
///
/// جهت RTL از لوکال `fa` می‌آید (فلتر GlobalWidgetsLocalizations)، بنابراین
/// همه‌ی صفحات و اجزای Material به‌صورت یکدست راست‌به‌چپ می‌شوند.
class MyFlowApp extends ConsumerWidget {
  const MyFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'MyFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: ref.watch(appRouterProvider),
      locale: const Locale('fa'),
      supportedLocales: const <Locale>[Locale('fa')],
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
