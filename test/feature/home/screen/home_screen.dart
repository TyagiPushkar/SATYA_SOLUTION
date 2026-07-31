import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_text.dart';
import './main_screen.dart';
import '../../task/provider/task_provider.dart';

import '../../auth/provider/auth_provider.dart';
import '../../attendance/provider/punch_in_provider.dart';
import '../../attendance/provider/sync_provider.dart';
import '../../../core/providers/permission_provider.dart';
import '../../../core/models/permission_model.dart';

class HomeContent extends ConsumerWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8), // Light bluish background
      drawer: Drawer(
        child: Consumer(
          builder: (context, ref, child) {
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

            final userName = (user?.name != null && user!.name!.isNotEmpty)
                ? user.name!
                : (isEmployee ? 'Ratan Verma' : 'Super Admin');

            final roleName =
                (user?.roleName != null && user!.roleName.isNotEmpty)
                ? user.roleName
                : (isEmployee ? 'Employee' : 'Admin');

            return Column(
              children: [
                DrawerHeader(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: const BoxDecoration(color: AppColors.primary),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white,
                          backgroundImage:
                              (user?.image != null && user!.image!.isNotEmpty)
                              ? NetworkImage(user.image!)
                              : null,
                          child: (user?.image == null || user!.image!.isEmpty)
                              ? const Icon(
                                  Icons.person,
                                  size: 36,
                                  color: AppColors.primary,
                                )
                              : null,
                        ),
                        const SizedBox(height: 10),
                        AppText(
                          userName,
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        const SizedBox(height: 2),
                        AppText(
                          roleName,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children:
                        //isEmployee
                        //?
                        _buildEmployeeDrawerItems(context, ref),
                    // : _buildAdminDrawerItems(context, ref),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeaderAndPunchSection(context, ref),
                  const SizedBox(height: 16),
                  _buildTaskCard('Task - Today'),
                  const SizedBox(height: 16),
                  _buildTaskCard('Task- Month-to-date'),
                  const SizedBox(height: 16),
                  _buildChartCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderAndPunchSection(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;
    final punchState = ref.watch(punchInProvider);

    final now = DateTime.now();
    final hour = now.hour;
    String greeting;
    IconData greetingIcon;
    Color iconColor;

    if (hour >= 4 && hour < 12) {
      greeting = 'Good morning';
      greetingIcon = Icons.wb_sunny_rounded;
      iconColor = Colors.orangeAccent;
    } else if (hour >= 12 && hour < 17) {
      greeting = 'Good afternoon';
      greetingIcon = Icons.wb_sunny_rounded;
      iconColor = Colors.amber;
    } else {
      greeting = 'Good evening';
      greetingIcon = Icons.nights_stay_rounded;
      iconColor = Colors.indigo;
    }

    final displayName = (user?.name != null && user!.name!.isNotEmpty)
        ? user.name!
        : 'Ratan';
    final fullGreeting = '$greeting, $displayName';

    final String punchTimeText = (punchState.isPunchedIn == true)
        ? (punchState.punchInTime != null
              ? 'Punched In at ${_formatTime(punchState.punchInTime!)}'
              : 'Punched In')
        : (punchState.punchOutTime != null
              ? 'Punched Out at ${_formatTime(punchState.punchOutTime!)}'
              : 'Not Punched In Today');

    const double notchWidth = 56.0;
    const double topHeight = 65.0;

    return SizedBox(
      width: double.infinity,
      child: Stack(
        children: [
          // Custom Notched Card Shape (Rendered first)
          CustomPaint(
            painter: NotchedCardPainter(
              notchWidth: notchWidth,
              topHeight: topHeight,
              radius: 14.0,
              borderColor: AppColors.borderGrey,
              fillColor: AppColors.white,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top-Right Section: Greeting Text
                Container(
                  height: topHeight,
                  padding: EdgeInsets.only(left: notchWidth + 8, right: 16),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: AppText(
                          fullGreeting,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Icon(greetingIcon, color: iconColor, size: 22),
                    ],
                  ),
                ),
                // Bottom Section: Punch In Button with Primary Color background
                InkWell(
                  onTap: () async {
                    final empId = user?.id ?? 7;
                    final resultMsg = await ref
                        .read(punchInProvider.notifier)
                        .togglePunchIn(empId: empId);

                    if (resultMsg != null && context.mounted) {
                      final isError = resultMsg.startsWith('ERROR:');
                      final displayMsg = isError
                          ? resultMsg.replaceFirst('ERROR:', '').trim()
                          : resultMsg;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(
                                isError
                                    ? Icons.error_outline
                                    : Icons.check_circle_outline,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  displayMsg,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: isError
                              ? Colors.red.shade700
                              : Colors.green.shade700,
                          duration: const Duration(seconds: 4),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    }
                  },
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(14),
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(5),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: (punchState.isPunchedIn == true)
                          ? Colors.green.shade600
                          : AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        // Left Circle Icon (Fingerprint)
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          child: Icon(
                            (punchState.isPunchedIn == true)
                                ? Icons.fingerprint_rounded
                                : Icons.fingerprint,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Middle Info: Punch in / data -
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(
                                (punchState.isPunchedIn == true)
                                    ? 'Punch out'
                                    : 'Punch in',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 2),
                              AppText(
                                punchTimeText,
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ],
                          ),
                        ),
                        // Right Arrow Icon Circle ( -> )
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.2),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Drawer Icon (≡) in Top-Left Notch Area (Rendered on top to capture tap events)
          Positioned(
            left: 0,
            top: 6,
            width: notchWidth,
            height: topHeight,
            child: Center(
              child: Builder(
                builder: (context) => Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.menu, color: Colors.white, size: 22),
                    onPressed: () {
                      Scaffold.of(context).openDrawer();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour == 0
        ? 12
        : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  Widget _buildTaskCard(String title) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: AppText(title, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          // Body
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: _buildTaskStatBox('Completed', '0 out of 0')),
                SizedBox(width: 12),
                Expanded(child: _buildTaskStatBox('In Progress', '0 out of 0')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskStatBox(String title, String subtitle) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                title,
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  AppText(
                    subtitle.split(' ')[0],
                    fontSize: 13,
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                  AppText(
                    ' ${subtitle.substring(subtitle.indexOf(' ') + 1)}',
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ],
              ),
            ],
          ),
          // Circular Progress Indicator 0%
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  value: 0,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  strokeWidth: 3,
                ),
              ),
              AppText(
                '0%',
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: AppText(
              'Collection - Month to Date',
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          // Body (Graph Placeholder)
          Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              height: 200,
              child: Row(
                children: [
                  // Y-axis labels
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AppText('4', fontSize: 10, color: Colors.grey),
                      AppText('3', fontSize: 10, color: Colors.grey),
                      AppText('2', fontSize: 10, color: Colors.grey),
                      AppText('1', fontSize: 10, color: Colors.grey),
                      AppText('0', fontSize: 10, color: Colors.grey),
                    ],
                  ),
                  SizedBox(width: 8),
                  // Graph Area
                  Expanded(
                    child: Stack(
                      children: [
                        // Grid lines
                        Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(
                            5,
                            (index) =>
                                Divider(color: Colors.grey.shade200, height: 1),
                          ),
                        ),
                        // X-axis labels
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _RotatedText('Week 1'),
                              _RotatedText('Week 2'),
                              _RotatedText('Week 3'),
                              _RotatedText('Week 4'),
                              _RotatedText('Week 5'),
                            ],
                          ),
                        ),
                        // Right edge blue line from screenshot
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 20, // leave space for x-axis
                          child: Container(
                            width: 4,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildEmployeeDrawerItems(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncProvider);
    final permAsync = ref.watch(permissionProvider);

    if (permAsync.isLoading) {
      return const [
        Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    final perms = permAsync.value;
    if (perms == null) {
      return const [
        Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: Text('Error loading permissions')),
        ),
      ];
    }

    final items = <Widget>[];

    // Home
    if (perms.dashboard.hasAnyAccess) {
      items.add(
        ListTile(
          leading: const Icon(Icons.home_outlined, color: AppColors.primary),
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
                title: AppText('Monthly Records', fontWeight: FontWeight.w500),
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
          leading: const Icon(Icons.task_alt, color: AppColors.primary),
          title: AppText('My Task', fontWeight: FontWeight.bold),
          iconColor: AppColors.primary,
          collapsedIconColor: Colors.black54,
          children: [
            if (perms.task.taskAll.hasAnyAccess)
              ListTile(
                contentPadding: const EdgeInsets.only(left: 72),
                title: AppText('All Task', fontWeight: FontWeight.w500),
                onTap: () {
                  ref.read(taskTitleProvider.notifier).setTitle('All Task');
                  Navigator.pop(context);
                  ref.read(mainScreenTabProvider.notifier).setTab(1);
                },
              ),
            if (perms.task.teamTask.hasAnyAccess)
              ListTile(
                contentPadding: const EdgeInsets.only(left: 72),
                title: AppText('Team Task', fontWeight: FontWeight.w500),
                onTap: () {
                  ref.read(taskTitleProvider.notifier).setTitle('Team Task');
                  Navigator.pop(context);
                  ref.read(mainScreenTabProvider.notifier).setTab(1);
                },
              ),
            if (perms.task.taskCustomer.hasAnyAccess)
              ListTile(
                contentPadding: const EdgeInsets.only(left: 72),
                title: AppText('Customer Task', fontWeight: FontWeight.w500),
                onTap: () {
                  ref
                      .read(taskTitleProvider.notifier)
                      .setTitle('Customer Task');
                  Navigator.pop(context);
                  ref.read(mainScreenTabProvider.notifier).setTab(1);
                },
              ),
            if (perms.task.deletedTasks.hasAnyAccess)
              ListTile(
                contentPadding: const EdgeInsets.only(left: 72),
                title: AppText('Deleted Tasks', fontWeight: FontWeight.w500),
                onTap: () {
                  ref
                      .read(taskTitleProvider.notifier)
                      .setTitle('Deleted Tasks');
                  Navigator.pop(context);
                  ref.read(mainScreenTabProvider.notifier).setTab(1);
                },
              ),
            if (perms.task.onboardingTask.hasAnyAccess)
              ListTile(
                contentPadding: const EdgeInsets.only(left: 72),
                title: AppText('Onboarding Task', fontWeight: FontWeight.w500),
                onTap: () {
                  ref
                      .read(taskTitleProvider.notifier)
                      .setTitle('Onboarding Task');
                  Navigator.pop(context);
                  ref.read(mainScreenTabProvider.notifier).setTab(1);
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
                title: AppText('My Team', fontWeight: FontWeight.w500),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/my-team');
                },
              ),
            if (perms.employee.allEmployee.hasAnyAccess)
              ListTile(
                contentPadding: const EdgeInsets.only(left: 72),
                title: AppText('All Employee', fontWeight: FontWeight.w500),
                onTap: () {
                  ref
                      .read(taskTitleProvider.notifier)
                      .setTitle('All Employees');
                  Navigator.pop(context);
                  ref.read(mainScreenTabProvider.notifier).setTab(1);
                },
              ),
          ],
        ),
      );
      items.add(const Divider(height: 1));
    }

    // New Fields
    if (perms.role.hasAnyAccess) {
      items.add(
        ListTile(
          leading: const Icon(Icons.security, color: AppColors.primary),
          title: AppText('Role', fontWeight: FontWeight.bold),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pop(context),
        ),
      );
      items.add(const Divider(height: 1));
    }
    if (perms.admin.hasAnyAccess) {
      items.add(
        ListTile(
          leading: const Icon(
            Icons.admin_panel_settings,
            color: AppColors.primary,
          ),
          title: AppText('Admin', fontWeight: FontWeight.bold),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pop(context),
        ),
      );
      items.add(const Divider(height: 1));
    }
    if (perms.leave.hasAnyAccess) {
      items.add(
        ListTile(
          leading: const Icon(Icons.time_to_leave, color: AppColors.primary),
          title: AppText('Leave', fontWeight: FontWeight.bold),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pop(context),
        ),
      );
      items.add(const Divider(height: 1));
    }
    if (perms.branch.hasAnyAccess) {
      items.add(
        ListTile(
          leading: const Icon(Icons.domain, color: AppColors.primary),
          title: AppText('Branch', fontWeight: FontWeight.bold),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pop(context),
        ),
      );
      items.add(const Divider(height: 1));
    }
    if (perms.holiday.hasAnyAccess) {
      items.add(
        ListTile(
          leading: const Icon(Icons.beach_access, color: AppColors.primary),
          title: AppText('Holiday', fontWeight: FontWeight.bold),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pop(context),
        ),
      );
      items.add(const Divider(height: 1));
    }
    if (perms.reports.hasAnyAccess) {
      items.add(
        ListTile(
          leading: const Icon(Icons.bar_chart, color: AppColors.primary),
          title: AppText('Reports', fontWeight: FontWeight.bold),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pop(context),
        ),
      );
      items.add(const Divider(height: 1));
    }
    if (perms.department.hasAnyAccess) {
      items.add(
        ListTile(
          leading: const Icon(Icons.business, color: AppColors.primary),
          title: AppText('Department', fontWeight: FontWeight.bold),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pop(context),
        ),
      );
      items.add(const Divider(height: 1));
    }
    if (perms.designation.hasAnyAccess) {
      items.add(
        ListTile(
          leading: const Icon(Icons.badge, color: AppColors.primary),
          title: AppText('Designation', fontWeight: FontWeight.bold),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pop(context),
        ),
      );
      items.add(const Divider(height: 1));
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
      Center(child: AppText('v1.0.0', color: Colors.grey, fontSize: 12)),
    );
    items.add(const SizedBox(height: 16));

    return items;
  }
}

class _RotatedText extends StatelessWidget {
  final String text;
  const _RotatedText(this.text);

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.5,
      child: Padding(
        padding: EdgeInsets.only(top: 16.0),
        child: AppText(text, fontSize: 10, color: Colors.grey),
      ),
    );
  }
}

class NotchedCardClipper extends CustomClipper<Path> {
  final double notchWidth;
  final double topHeight;
  final double radius;

  NotchedCardClipper({
    required this.notchWidth,
    required this.topHeight,
    required this.radius,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    final nw = notchWidth;
    final th = topHeight;
    final r = radius;

    path.moveTo(nw + r, 0);
    path.lineTo(w - r, 0);
    path.quadraticBezierTo(w, 0, w, r);
    path.lineTo(w, h - r);
    path.quadraticBezierTo(w, h, w - r, h);
    path.lineTo(r, h);
    path.quadraticBezierTo(0, h, 0, h - r);
    path.lineTo(0, th + r);
    path.quadraticBezierTo(0, th, r, th);
    path.lineTo(nw - r, th);
    path.quadraticBezierTo(nw, th, nw, th - r);
    path.lineTo(nw, r);
    path.quadraticBezierTo(nw, 0, nw + r, 0);

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class NotchedCardPainter extends CustomPainter {
  final double notchWidth;
  final double topHeight;
  final double radius;
  final Color borderColor;
  final Color fillColor;

  NotchedCardPainter({
    required this.notchWidth,
    required this.topHeight,
    required this.radius,
    required this.borderColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final clipper = NotchedCardClipper(
      notchWidth: notchWidth,
      topHeight: topHeight,
      radius: radius,
    );
    final path = clipper.getClip(size);

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
