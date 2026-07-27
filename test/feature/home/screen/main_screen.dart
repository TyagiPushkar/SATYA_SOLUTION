import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import './home_screen.dart';
import '../widget/app_drawer.dart';
import '../../profile/screen/profile_screen.dart';
import '../../task/screen/task_screen.dart';
import '../../attendance/screen/monthly_records_screen.dart';
import '../../auth/provider/auth_provider.dart';
import '../../task/provider/task_provider.dart';

class MainScreenTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setTab(int index) {
    state = index;
  }
}

final mainScreenTabProvider = NotifierProvider<MainScreenTabNotifier, int>(() {
  return MainScreenTabNotifier();
});

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  static final List<Widget> _screens = [
    HomeContent(),
    TaskScreen(),
    const MonthlyRecordsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(mainScreenTabProvider);
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;

    final isEmployee =
        user != null &&
        (user.roleSlug.toLowerCase() == 'employee' ||
            user.roleName.toLowerCase() == 'employee' ||
            user.roleName.toLowerCase().contains('employee') ||
            (user.type is Map &&
                (user.type as Map)['name']?.toString().toLowerCase() ==
                    'employee') ||
            (user.type is Map &&
                (user.type as Map)['slug']?.toString().toLowerCase() ==
                    'employee'));

    return Scaffold(
      drawer: const AppDrawer(),
      body: IndexedStack(index: currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          boxShadow: [
            BoxShadow(
              color: AppColors.grey.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) {
            if (index == 1) {
              if (!isEmployee) {
                ref.read(taskTitleProvider.notifier).setTitle('All Employees');
              } else {
                ref.read(taskTitleProvider.notifier).setTitle('All Task');
              }
            }
            ref.read(mainScreenTabProvider.notifier).setTab(index);
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.grey,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          iconSize: 32,
          elevation: 0,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: isEmployee
                  ? const Icon(Icons.task_outlined)
                  : const Icon(Icons.people_alt),
              activeIcon: isEmployee
                  ? const Icon(Icons.task)
                  : const Icon(Icons.people_alt),
              label: isEmployee ? 'Task' : 'Employees',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              activeIcon: Icon(Icons.calendar_month),
              label: 'Records',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
