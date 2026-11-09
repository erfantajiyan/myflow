import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/date_time/date_only.dart';
import '../features/calendar/presentation/calendar_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/events/presentation/event_details_page.dart';
import '../features/events/presentation/events_page.dart';
import '../features/projects/presentation/projects_page.dart';
import '../features/reports/presentation/reports_page.dart';
import '../features/responsibilities/presentation/responsibilities_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/tasks/presentation/tasks_page.dart';
import '../features/timeline/presentation/timeline_page.dart';
import '../shared/widgets/app_navigation_shell.dart';

/// مسیریابی برنامه (بخش ۱۲.۳ سند).
///
/// پنج مقصد MVP هر کدام یک شاخه‌ی مستقل دارند تا وضعیت هر تب جدا بماند.
/// صفحه‌های تایم‌لاین، مسئولیت‌ها و تنظیمات خارج از نوار پایین و روی کل
/// ناوبری باز می‌شوند.
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final GoRouter router = buildAppRouter();
  ref.onDispose(router.dispose);
  return router;
});

GoRouter buildAppRouter() {
  // کلید ناوبری برای هر نمونه از روتر جداگانه ساخته می‌شود تا تست‌ها و
  // بازسازی روتر با تداخل GlobalKey روبه‌رو نشوند.
  final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/dashboard',
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder:
            (
              BuildContext context,
              GoRouterState state,
              StatefulNavigationShell navigationShell,
            ) => AppNavigationShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/dashboard',
                name: 'dashboard',
                builder: (BuildContext context, GoRouterState state) =>
                    const DashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/calendar',
                name: 'calendar',
                builder: (BuildContext context, GoRouterState state) =>
                    const CalendarPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/tasks',
                name: 'tasks',
                builder: (BuildContext context, GoRouterState state) =>
                    const TasksPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/projects',
                name: 'projects',
                builder: (BuildContext context, GoRouterState state) =>
                    const ProjectsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/reports',
                name: 'reports',
                builder: (BuildContext context, GoRouterState state) =>
                    const ReportsPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/timeline',
        name: 'timeline',
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) => TimelinePage(
          initialDate: parseDateOnly(state.uri.queryParameters['date']),
        ),
      ),
      GoRoute(
        path: '/responsibilities',
        name: 'responsibilities',
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const ResponsibilitiesPage(),
      ),
      GoRoute(
        path: '/events',
        name: 'events',
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const EventsPage(),
      ),
      GoRoute(
        path: '/events/:id',
        name: 'eventDetails',
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            EventDetailsPage(eventId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const SettingsPage(),
      ),
    ],
  );
}
