import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/groups/presentation/dashboard_screen.dart';
import '../../features/groups/presentation/create_group_screen.dart';
import '../../features/groups/presentation/group_detail_screen.dart';
import '../../features/analytics/presentation/group_analytics_screen.dart';
import '../../features/analytics/presentation/select_group_screen.dart';
import '../../features/analytics/presentation/my_analytics_screen.dart';
import '../../features/analytics/presentation/todays_rituals_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/auth',
  routes: [
    GoRoute(
      path: '/auth',
      builder: (context, state) => const AuthScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/create-group',
      builder: (context, state) => const CreateGroupScreen(),
    ),
    GoRoute(
      path: '/group/:id',
      builder: (context, state) => GroupDetailScreen(
        groupId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/group/:id/analytics',
      builder: (context, state) => GroupAnalyticsScreen(
        groupId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/select-group-analytics',
      builder: (context, state) => const SelectGroupAnalyticsScreen(),
    ),
    GoRoute(
      path: '/my-analytics',
      builder: (context, state) => const MyAnalyticsScreen(),
    ),
    GoRoute(
      path: '/todays-rituals',
      builder: (context, state) => const TodaysRitualsScreen(),
    ),
  ],
);
