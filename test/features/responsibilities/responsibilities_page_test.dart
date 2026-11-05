import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myflow/app/theme/app_theme.dart';
import 'package:myflow/database/app_database.dart';
import 'package:myflow/database/database_providers.dart';
import 'package:myflow/features/responsibilities/presentation/responsibilities_page.dart';
import 'package:myflow/features/responsibilities/presentation/responsibility_editor_sheet.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildPage() {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWith((Ref ref) => db),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        locale: const Locale('fa'),
        supportedLocales: const <Locale>[Locale('fa')],
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const ResponsibilitiesPage(),
      ),
    );
  }

  Finder nameField() => find
      .descendant(
        of: find.byKey(responsibilityEditorFormKey),
        matching: find.byType(TextFormField),
      )
      .first;

  testWidgets('چهار مسئولیت اولیه از دیتابیس نمایش داده می‌شوند', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    for (final String name in <String>[
      'دانشجو',
      'معاونت علمی',
      'انجمن',
      'شخصی',
    ]) {
      expect(find.text(name), findsOneWidget, reason: 'مسئولیت $name');
    }
    expect(find.textContaining('فعال (۴)'), findsOneWidget);
    expect(find.textContaining('بایگانی‌شده'), findsNothing);
  });

  testWidgets('ساخت مسئولیت جدید در فهرست ظاهر می‌شود', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    await tester.tap(find.text('مسئولیت جدید'));
    await tester.pumpAndSettle();

    await tester.enterText(nameField(), 'کار داوطلبانه');
    await tester.tap(find.text('ساخت مسئولیت'));
    await tester.pumpAndSettle();

    expect(find.text('کار داوطلبانه'), findsOneWidget);
    expect(find.textContaining('فعال (۵)'), findsOneWidget);
  });

  testWidgets('نام خالی در فرم، پیام خطا می‌دهد و چیزی نمی‌سازد', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    await tester.tap(find.text('مسئولیت جدید'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ساخت مسئولیت'));
    await tester.pumpAndSettle();

    expect(find.text('نام مسئولیت نمی‌تواند خالی باشد.'), findsOneWidget);
    expect(find.textContaining('فعال (۴)'), findsOneWidget);
  });

  testWidgets('ویرایش نام مسئولیت در فهرست منعکس می‌شود', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    await tester.tap(find.text('دانشجو'));
    await tester.pumpAndSettle();
    expect(find.text('ویرایش مسئولیت'), findsOneWidget);

    await tester.enterText(nameField(), 'دانشجوی ارشد');
    await tester.tap(find.text('ذخیره تغییرات'));
    await tester.pumpAndSettle();

    expect(find.text('دانشجوی ارشد'), findsOneWidget);
    expect(find.text('دانشجو'), findsNothing);
  });

  testWidgets('بایگانی مسئولیت آن را به بخش بایگانی منتقل می‌کند', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    await tester.tap(find.text('دانشجو'));
    await tester.pumpAndSettle();

    // دکمه‌ی بایگانی در پایین فرم است و در ارتفاع کم تست باید اسکرول شود.
    await tester.ensureVisible(find.text('بایگانی مسئولیت'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('بایگانی مسئولیت'));
    await tester.pumpAndSettle();

    // تأیید در دیالوگ مخرب
    await tester.tap(find.text('بایگانی'));
    await tester.pumpAndSettle();

    expect(find.textContaining('فعال (۳)'), findsOneWidget);
    expect(find.textContaining('بایگانی‌شده (۱)'), findsOneWidget);
    // مسئولیت حذف نشده، فقط جابه‌جا شده است.
    expect(find.text('دانشجو'), findsOneWidget);
  });
}
