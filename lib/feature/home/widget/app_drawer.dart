import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_text.dart';
import '../../../core/providers/permission_provider.dart';
import '../../auth/provider/auth_provider.dart';
import '../../attendance/provider/sync_provider.dart';
import '../../task/provider/task_provider.dart';
import '../screen/main_screen.dart';

class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.invalidate(permissionProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;
    final syncState = ref.watch(syncProvider);
    final permAsync = ref.watch(permissionProvider);

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
          Expanded(
            child: permAsync.when(
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) =>
                  Center(child: Text('Error loading permissions: $err')),
              data: (perms) {
                final items = <Widget>[];

                // Home
                if (perms.dashboard.hasAnyAccess) {
                  items.add(
                    ListTile(
                      leading: const Icon(
                        Icons.home_outlined,
                        color: AppColors.primary,
                      ),
                      title: AppText('Home', fontWeight: FontWeight.bold),
                      onTap: () {
                        Navigator.pop(context);
                        ref.read(mainScreenTabProvider.notifier).setTab(0);
                      },
                    ),
                  );
                  items.add(const Divider(height: 1));
                }

                // Attendance
                if (perms.attendance.attendanceDetails.hasAnyAccess ||
                    perms.attendance.monthlyAttendance.hasAnyAccess) {
                  items.add(
                    ExpansionTile(
                      leading: const Icon(
                        Icons.calendar_today_outlined,
                        color: AppColors.primary,
                      ),
                      title: AppText('Attendance', fontWeight: FontWeight.bold),
                      iconColor: AppColors.primary,
                      collapsedIconColor: Colors.black54,
                      children: [
                        if (perms.attendance.attendanceDetails.hasAnyAccess)
                          ListTile(
                            contentPadding: const EdgeInsets.only(left: 72),
                            title: AppText(
                              'Attendance Details',
                              fontWeight: FontWeight.w500,
                            ),
                            onTap: () => Navigator.pop(context),
                          ),
                        if (perms.attendance.monthlyAttendance.hasAnyAccess)
                          ListTile(
                            contentPadding: const EdgeInsets.only(left: 72),
                            title: AppText(
                              'Monthly Records',
                              fontWeight: FontWeight.w500,
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              context.push('/monthly-records');
                            },
                          ),
                      ],
                    ),
                  );
                  items.add(const Divider(height: 1));
                }

                // My Task
                if (perms.task.taskAll.hasAnyAccess ||
                    perms.task.teamTask.hasAnyAccess ||
                    perms.task.taskCustomer.hasAnyAccess ||
                    perms.task.deletedTasks.hasAnyAccess ||
                    perms.task.onboardingTask.hasAnyAccess) {
                  items.add(
                    ExpansionTile(
                      leading: const Icon(
                        Icons.task_alt,
                        color: AppColors.primary,
                      ),
                      title: AppText('My Task', fontWeight: FontWeight.bold),
                      iconColor: AppColors.primary,
                      collapsedIconColor: Colors.black54,
                      children: [
                        if (perms.task.taskAll.hasAnyAccess)
                          ListTile(
                            contentPadding: const EdgeInsets.only(left: 72),
                            title: AppText(
                              'All Task',
                              fontWeight: FontWeight.w500,
                            ),
                            onTap: () {
                              ref
                                  .read(taskTitleProvider.notifier)
                                  .setTitle('All Task');
                              Navigator.pop(context);
                              ref
                                  .read(mainScreenTabProvider.notifier)
                                  .setTab(1);
                            },
                          ),
                        if (perms.task.teamTask.hasAnyAccess)
                          ListTile(
                            contentPadding: const EdgeInsets.only(left: 72),
                            title: AppText(
                              'Team Task',
                              fontWeight: FontWeight.w500,
                            ),
                            onTap: () {
                              ref
                                  .read(taskTitleProvider.notifier)
                                  .setTitle('Team Task');
                              Navigator.pop(context);
                              ref
                                  .read(mainScreenTabProvider.notifier)
                                  .setTab(1);
                            },
                          ),
                        if (perms.task.taskCustomer.hasAnyAccess)
                          ListTile(
                            contentPadding: const EdgeInsets.only(left: 72),
                            title: AppText(
                              'Customer Task',
                              fontWeight: FontWeight.w500,
                            ),
                            onTap: () {
                              ref
                                  .read(taskTitleProvider.notifier)
                                  .setTitle('Customer Task');
                              Navigator.pop(context);
                              ref
                                  .read(mainScreenTabProvider.notifier)
                                  .setTab(1);
                            },
                          ),
                        if (perms.task.deletedTasks.hasAnyAccess)
                          ListTile(
                            contentPadding: const EdgeInsets.only(left: 72),
                            title: AppText(
                              'Deleted Tasks',
                              fontWeight: FontWeight.w500,
                            ),
                            onTap: () {
                              ref
                                  .read(taskTitleProvider.notifier)
                                  .setTitle('Deleted Tasks');
                              Navigator.pop(context);
                              ref
                                  .read(mainScreenTabProvider.notifier)
                                  .setTab(1);
                            },
                          ),
                        if (perms.task.onboardingTask.hasAnyAccess)
                          ListTile(
                            contentPadding: const EdgeInsets.only(left: 72),
                            title: AppText(
                              'Onboarding Task',
                              fontWeight: FontWeight.w500,
                            ),
                            onTap: () {
                              ref
                                  .read(taskTitleProvider.notifier)
                                  .setTitle('Onboarding Task');
                              Navigator.pop(context);
                              ref
                                  .read(mainScreenTabProvider.notifier)
                                  .setTab(1);
                            },
                          ),
                      ],
                    ),
                  );
                  items.add(const Divider(height: 1));
                }

                // Employee
                if (perms.employee.myTeam.hasAnyAccess ||
                    perms.employee.allEmployee.hasAnyAccess) {
                  items.add(
                    ExpansionTile(
                      leading: const Icon(
                        Icons.people_alt_outlined,
                        color: AppColors.primary,
                      ),
                      title: AppText('Employee', fontWeight: FontWeight.bold),
                      iconColor: AppColors.primary,
                      collapsedIconColor: Colors.black54,
                      children: [
                        if (perms.employee.myTeam.hasAnyAccess)
                          ListTile(
                            contentPadding: const EdgeInsets.only(left: 72),
                            title: AppText(
                              'My Team',
                              fontWeight: FontWeight.w500,
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              context.push('/my-team');
                            },
                          ),
                        if (perms.employee.allEmployee.hasAnyAccess)
                          ListTile(
                            contentPadding: const EdgeInsets.only(left: 72),
                            title: AppText(
                              'All Employee',
                              fontWeight: FontWeight.w500,
                            ),
                            onTap: () {
                              ref
                                  .read(taskTitleProvider.notifier)
                                  .setTitle('All Employees');
                              Navigator.pop(context);
                              ref
                                  .read(mainScreenTabProvider.notifier)
                                  .setTab(1);
                            },
                          ),
                      ],
                    ),
                  );
                  items.add(const Divider(height: 1));
                }

                // Customers
                if (perms.customer.hasAnyAccess) {
                  items.add(
                    ListTile(
                      leading: const Icon(
                        Icons.people_outline,
                        color: AppColors.primary,
                      ),
                      title: AppText('Customers', fontWeight: FontWeight.bold),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        ref
                            .read(taskTitleProvider.notifier)
                            .setTitle('Customers');
                        Navigator.pop(context);
                        ref
                            .read(mainScreenTabProvider.notifier)
                            .setTab(1);
                      },
                    ),
                  );
                  items.add(const Divider(height: 1));
                }

                // Admin
                if (perms.admin.hasAnyAccess || userRole.toLowerCase().contains('admin')) {
                  final adminChildren = <Widget>[];
                  final showAllAdmin = userRole.toLowerCase().contains('admin');

                  if (showAllAdmin || perms.admin.role.hasAnyAccess) {
                    adminChildren.add(
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 72),
                        title: AppText('Role', fontWeight: FontWeight.w500),
                        onTap: () => Navigator.pop(context),
                      ),
                    );
                  }
                  if (showAllAdmin ||
                      perms.admin.leave.hasAnyAccess ||
                      perms.admin.leavesettingsLeave.hasAnyAccess) {
                    adminChildren.add(
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 72),
                        title: AppText('Leave', fontWeight: FontWeight.w500),
                        onTap: () => Navigator.pop(context),
                      ),
                    );
                  }
                  if (showAllAdmin || perms.admin.branch.hasAnyAccess) {
                    adminChildren.add(
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 72),
                        title: AppText('Branch', fontWeight: FontWeight.w500),
                        onTap: () => Navigator.pop(context),
                      ),
                    );
                  }
                  if (showAllAdmin ||
                      perms.admin.holidays.hasAnyAccess ||
                      perms.admin.leavesettingsHolidays.hasAnyAccess) {
                    adminChildren.add(
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 72),
                        title: AppText('Holiday', fontWeight: FontWeight.w500),
                        onTap: () => Navigator.pop(context),
                      ),
                    );
                  }
                  if (showAllAdmin || perms.admin.reports.hasAnyAccess) {
                    adminChildren.add(
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 72),
                        title: AppText('Reports', fontWeight: FontWeight.w500),
                        onTap: () => Navigator.pop(context),
                      ),
                    );
                  }
                  if (showAllAdmin || perms.admin.department.hasAnyAccess) {
                    adminChildren.add(
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 72),
                        title: AppText('Department', fontWeight: FontWeight.w500),
                        onTap: () => Navigator.pop(context),
                      ),
                    );
                  }
                  if (showAllAdmin || perms.admin.designation.hasAnyAccess) {
                    adminChildren.add(
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 72),
                        title: AppText('Designation', fontWeight: FontWeight.w500),
                        onTap: () => Navigator.pop(context),
                      ),
                    );
                  }
                  if (showAllAdmin || perms.admin.state.hasAnyAccess) {
                    adminChildren.add(
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 72),
                        title: AppText('State', fontWeight: FontWeight.w500),
                        onTap: () => Navigator.pop(context),
                      ),
                    );
                  }
                  if (showAllAdmin || perms.admin.region.hasAnyAccess) {
                    adminChildren.add(
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 72),
                        title: AppText('Region', fontWeight: FontWeight.w500),
                        onTap: () => Navigator.pop(context),
                      ),
                    );
                  }
                  if (showAllAdmin || perms.admin.tasktype.hasAnyAccess) {
                    adminChildren.add(
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 72),
                        title: AppText('Task Type', fontWeight: FontWeight.w500),
                        onTap: () => Navigator.pop(context),
                      ),
                    );
                  }
                  if (showAllAdmin ||
                      perms.admin.leaveType.hasAnyAccess ||
                      perms.admin.leavesettingsLeaveType.hasAnyAccess) {
                    adminChildren.add(
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 72),
                        title: AppText('Leave Type', fontWeight: FontWeight.w500),
                        onTap: () => Navigator.pop(context),
                      ),
                    );
                  }
                  if (showAllAdmin ||
                      perms.admin.nonworking.hasAnyAccess ||
                      perms.admin.leavesettingsNonworking.hasAnyAccess) {
                    adminChildren.add(
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 72),
                        title: AppText('Non Working', fontWeight: FontWeight.w500),
                        onTap: () => Navigator.pop(context),
                      ),
                    );
                  }
                  if (showAllAdmin ||
                      perms.admin.leaveprofile.hasAnyAccess ||
                      perms.admin.leavesettingsLeaveprofile.hasAnyAccess) {
                    adminChildren.add(
                      ListTile(
                        contentPadding: const EdgeInsets.only(left: 72),
                        title: AppText('Leave Profile', fontWeight: FontWeight.w500),
                        onTap: () => Navigator.pop(context),
                      ),
                    );
                  }

                  // Fallback: If perms.admin.hasAnyAccess is true but no specific sub-permission matched in JSON, display standard admin sub-items
                  if (adminChildren.isEmpty && perms.admin.hasAnyAccess) {
                    final defaultSubItems = [
                      'Role',
                      'Leave',
                      'Branch',
                      'Holiday',
                      'Reports',
                      'Department',
                      'Designation',
                    ];
                    for (final itemTitle in defaultSubItems) {
                      adminChildren.add(
                        ListTile(
                          contentPadding: const EdgeInsets.only(left: 72),
                          title: AppText(itemTitle, fontWeight: FontWeight.w500),
                          onTap: () => Navigator.pop(context),
                        ),
                      );
                    }
                  }

                  if (adminChildren.isNotEmpty) {
                    items.add(
                      ExpansionTile(
                        leading: const Icon(
                          Icons.admin_panel_settings,
                          color: AppColors.primary,
                        ),
                        title: AppText('Admin', fontWeight: FontWeight.bold),
                        iconColor: AppColors.primary,
                        collapsedIconColor: Colors.black54,
                        children: adminChildren,
                      ),
                    );
                    items.add(const Divider(height: 1));
                  }
                }

                // Feeds
                if (perms.feeds.hasAnyAccess) {
                  items.add(
                    ListTile(
                      leading: const Icon(
                        Icons.dynamic_feed_outlined,
                        color: AppColors.primary,
                      ),
                      title: AppText('Feeds', fontWeight: FontWeight.bold),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pop(context),
                    ),
                  );
                  items.add(const Divider(height: 1));
                }

                // Settings
                if (perms.settings.hasAnyAccess) {
                  items.add(
                    ListTile(
                      leading: const Icon(
                        Icons.settings_outlined,
                        color: AppColors.primary,
                      ),
                      title: AppText('Settings', fontWeight: FontWeight.bold),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pop(context),
                    ),
                  );
                  items.add(const Divider(height: 1));
                }

                // Sync
                items.add(
                  ListTile(
                    leading: Icon(
                      Icons.sync_rounded,
                      color: syncState.hasUnsynced
                          ? Colors.amber.shade900
                          : AppColors.primary,
                    ),
                    title: AppText('Sync', fontWeight: FontWeight.bold),
                    trailing: syncState.hasUnsynced
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade800,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${syncState.pendingCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/unsynced-records');
                    },
                  ),
                );
                items.add(const Divider(height: 1));

                // Logout
                items.add(
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: AppText(
                      'Logout',
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      await ref.read(loginProvider.notifier).logout();
                      if (context.mounted) {
                        context.go('/login');
                      }
                    },
                  ),
                );
                items.add(const SizedBox(height: 16));
                items.add(
                  Center(
                    child: AppText('v1.0.0', color: Colors.grey, fontSize: 12),
                  ),
                );
                items.add(const SizedBox(height: 16));

                return ListView(padding: EdgeInsets.zero, children: items);
              },
            ),
          ),
        ],
      ),
    );
  }
}
