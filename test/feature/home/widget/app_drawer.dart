import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_text.dart';
import '../../auth/provider/auth_provider.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;

    final userName = user?.name ?? 'User';
    final userEmail = user?.email ?? '';
    final userRole = user?.roleName ?? 'Employee';

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: AppColors.primary),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            accountName: Text(
              userName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            accountEmail: Text(
              userRole.isNotEmpty ? '$userEmail ($userRole)' : userEmail,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined, color: AppColors.primary),
            title: const AppText(
              'Home',
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.access_time_outlined,
              color: AppColors.primary,
            ),
            title: const AppText(
              'Attendance History',
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.task_outlined, color: AppColors.primary),
            title: const AppText(
              'Tasks & Visits',
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person_outline, color: AppColors.primary),
            title: const AppText(
              'Profile',
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const AppText(
              'Logout',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.red,
            ),
            onTap: () async {
              Navigator.pop(context);
              await ref.read(loginProvider.notifier).logout();
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
