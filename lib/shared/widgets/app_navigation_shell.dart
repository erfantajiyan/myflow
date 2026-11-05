import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// پوسته‌ی ناوبری با پنج مقصد MVP (بخش ۴ سند):
/// خانه، تقویم، وظایف، پروژه‌ها، گزارش‌ها.
///
/// هر مقصد یک شاخه‌ی مستقل در `StatefulShellRoute` است تا وضعیت اسکرول و
/// مسیر هر تب حفظ شود.
class AppNavigationShell extends StatelessWidget {
  const AppNavigationShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const List<NavigationDestination> destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'خانه',
    ),
    NavigationDestination(
      icon: Icon(Icons.calendar_month_outlined),
      selectedIcon: Icon(Icons.calendar_month_rounded),
      label: 'تقویم',
    ),
    NavigationDestination(
      icon: Icon(Icons.check_circle_outline_rounded),
      selectedIcon: Icon(Icons.check_circle_rounded),
      label: 'وظایف',
    ),
    NavigationDestination(
      icon: Icon(Icons.folder_outlined),
      selectedIcon: Icon(Icons.folder_rounded),
      label: 'پروژه‌ها',
    ),
    NavigationDestination(
      icon: Icon(Icons.insights_outlined),
      selectedIcon: Icon(Icons.insights_rounded),
      label: 'گزارش‌ها',
    ),
  ];

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      // لمس دوباره‌ی تب فعال، به ریشه‌ی همان تب برمی‌گردد.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: destinations,
      ),
    );
  }
}
