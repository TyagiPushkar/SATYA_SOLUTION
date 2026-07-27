import 'package:go_router/go_router.dart';
import '../../feature/auth/screen/login_screen.dart';
import '../../feature/auth/screen/splash_screen.dart';
import '../../feature/home/screen/main_screen.dart';
import '../../feature/task/screen/create_task_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../feature/task/screen/add_customer_screen.dart';
import '../../feature/attendance/screen/monthly_records_screen.dart';
import '../../feature/auth/screen/create_employee_screen.dart';
import '../../feature/task/screen/task_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => MainScreen(),
      ),
      GoRoute(
        path: '/create-task',
        builder: (context, state) => CreateTaskScreen(),
      ),
      GoRoute(
        path: '/add-customer',
        builder: (context, state) => AddCustomerScreen(),
      ),
      GoRoute(
        path: '/monthly-records',
        builder: (context, state) => const MonthlyRecordsScreen(),
      ),
      GoRoute(
        path: '/create-employee',
        builder: (context, state) => const CreateEmployeeScreen(),
      ),
      GoRoute(
        path: '/task-page',
        builder: (context, state) => const TaskScreen(showBackButton: true),
      ),
    ],
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  return AppRouter.router;


  
});
