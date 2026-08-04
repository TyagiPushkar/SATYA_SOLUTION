import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_text.dart';
import '../../../core/widgets/app_sizebox.dart';
import '../../../core/widgets/custom_app_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../provider/task_provider.dart';
import '../provider/customers_list_provider.dart';
import '../../auth/provider/employee_list_provider.dart';
import '../../auth/model/employee_model.dart';
import '../../auth/provider/employee_form_fields_provider.dart';
import '../../../core/widgets/app_card_skeleton.dart';
import '../../home/screen/main_screen.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/providers/permission_provider.dart';
import '../../../core/models/permission_model.dart';

class TaskScreen extends ConsumerStatefulWidget {
  final bool showBackButton;
  const TaskScreen({super.key, this.showBackButton = false});

  @override
  ConsumerState<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends ConsumerState<TaskScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _expandedTaskSlugs = {};
  final Set<String> _expandedCustomerIds = {};
  List<dynamic> _getFilteredTasks(List<dynamic> rawTasks) {
    final selectedStatusFilter = ref.watch(taskFilterProvider);
    if (selectedStatusFilter == 'All') return rawTasks;

    return rawTasks.where((task) {
      final status = _safeString(
        task is Map ? task['status'] : '',
        fallback: 'Pending',
      ).toLowerCase();

      if (selectedStatusFilter == 'Pending') {
        return status.contains('pending') || status.contains('open');
      } else if (selectedStatusFilter == 'In Progress') {
        return status.contains('progress') || status.contains('inprogress');
      } else if (selectedStatusFilter == 'Completed') {
        return status.contains('complete') ||
            status.contains('closed') ||
            status.contains('done');
      }
      return true;
    }).toList();
  }

  Widget _buildStatusFilterTabs(List<dynamic> allTasks) {
    final selectedStatusFilter = ref.watch(taskFilterProvider);
    final tabs = ['All', 'Pending', 'In Progress', 'Completed'];

    int getCount(String statusFilter) {
      if (statusFilter == 'All') return allTasks.length;
      return allTasks.where((task) {
        final status = _safeString(
          task is Map ? task['status'] : '',
          fallback: 'Pending',
        ).toLowerCase();
        if (statusFilter == 'Pending') {
          return status.contains('pending') || status.contains('open');
        } else if (statusFilter == 'In Progress') {
          return status.contains('progress') || status.contains('inprogress');
        } else if (statusFilter == 'Completed') {
          return status.contains('complete') ||
              status.contains('closed') ||
              status.contains('done');
        }
        return false;
      }).length;
    }

    return Container(
      color: AppColors.primary,
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: tabs.map((tab) {
            final isSelected = selectedStatusFilter == tab;
            final count = getCount(tab);

            Color activeBgColor = Colors.white;
            Color activeTextColor = AppColors.primary;
            if (tab == 'Pending' && isSelected) {
              activeBgColor = const Color(0xFFFF9800);
              activeTextColor = Colors.white;
            } else if (tab == 'In Progress' && isSelected) {
              activeBgColor = const Color(0xFF2196F3);
              activeTextColor = Colors.white;
            } else if (tab == 'Completed' && isSelected) {
              activeBgColor = const Color(0xFF00BFA5);
              activeTextColor = Colors.white;
            }

            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: InkWell(
                onTap: () {
                  ref.read(taskFilterProvider.notifier).setFilter(tab);
                },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? activeBgColor
                        : Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                        ? null
                        : Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 1,
                          ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppText(
                        tab,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w600,
                        fontSize: 13,
                        color: isSelected ? activeTextColor : Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (activeBgColor == Colors.white
                                    ? AppColors.primary.withValues(alpha: 0.15)
                                    : Colors.white.withValues(alpha: 0.25))
                              : Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: AppText(
                          '$count',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? activeTextColor : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() {
      ref.read(taskScreenProvider.notifier).fetchTasks(refresh: true);
      ref.read(customerScreenProvider.notifier).fetchCustomers(refresh: true);
      ref.read(employeeListProvider.notifier).fetchEmployees(refresh: true);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final title = ref.read(taskTitleProvider);
      if (title == 'Customer Tasks') {
        ref
            .read(customerScreenProvider.notifier)
            .fetchCustomers(refresh: false);
      } else if (title == 'All Employees') {
        ref.read(employeeListProvider.notifier).fetchEmployees(refresh: false);
      } else {
        ref.read(taskScreenProvider.notifier).fetchTasks(refresh: false);
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'NA';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final months = [
        '',
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '${months[dt.month]} ${dt.day} - $hour:$minute $amPm';
    } catch (_) {
      return dateStr;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'open':
      case 'active':
        return const Color(0xFF00BFA5);
      case 'pending':
      case 'in progress':
      case 'inprogress':
        return const Color(0xFFFF9800);
      default:
        return const Color(0xFF0D47A1);
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 155,
            child: AppText(
              label,
              color: Colors.grey.shade600,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const AppText(': ', fontSize: 13, fontWeight: FontWeight.bold),
          Expanded(
            child: AppText(
              value,
              color: Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  bool _canAddForCurrentTab(UserPermission? perms, String title) {
    if (perms == null) return false;
    final cleanTitle = title.trim().toLowerCase();

    if (cleanTitle == 'all task' ||
        cleanTitle == 'all tasks' ||
        cleanTitle == 'my task' ||
        cleanTitle == 'tasks') {
      return perms.task.taskAll.add;
    } else if (cleanTitle == 'team task' || cleanTitle == 'team tasks') {
      return perms.task.teamTask.add;
    } else if (cleanTitle == 'customer task' ||
        cleanTitle == 'customer tasks') {
      return perms.task.taskCustomer.add;
    } else if (cleanTitle == 'deleted tasks' || cleanTitle == 'deleted task') {
      return perms.task.deletedTasks.add;
    } else if (cleanTitle == 'onboarding task' ||
        cleanTitle == 'onboarding tasks') {
      return perms.task.onboardingTask.add;
    } else if (cleanTitle == 'all employees' || cleanTitle == 'all employee') {
      return perms.employee.allEmployee.add;
    } else if (cleanTitle == 'my team') {
      return perms.employee.myTeam.add;
    }
    return perms.task.taskAll.add;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(mainScreenTabProvider, (previous, next) {
      if (next == 1) {
        final currentTitle = ref.read(taskTitleProvider);
        if (currentTitle == 'Customer Tasks' ||
            currentTitle == 'Customer Task') {
          ref
              .read(customerScreenProvider.notifier)
              .fetchCustomers(refresh: true);
        } else if (currentTitle == 'All Employees' ||
            currentTitle == 'All Employee') {
          ref.read(employeeListProvider.notifier).fetchEmployees(refresh: true);
        } else {
          ref.read(taskScreenProvider.notifier).fetchTasks(refresh: true);
        }
      }
    });

    final taskState = ref.watch(taskScreenProvider);
    final customerState = ref.watch(customerScreenProvider);
    final employeeState = ref.watch(employeeListProvider);
    final title = ref.watch(taskTitleProvider);
    final permAsync = ref.watch(permissionProvider);
    final perms = permAsync.value;

    final isCustomerMode =
        title == 'Customer Tasks' || title == 'Customer Task';
    final isEmployeeMode = title == 'All Employees' || title == 'All Employee';

    final canAdd = _canAddForCurrentTab(perms, title);

    final filteredTasks = _getFilteredTasks(taskState.tasks);

    final isLoading = isEmployeeMode
        ? employeeState.isLoading
        : (isCustomerMode ? customerState.isLoading : taskState.isLoading);
    final isLoadMore = isEmployeeMode
        ? employeeState.isLoadMore
        : (isCustomerMode ? customerState.isLoadMore : taskState.isLoadMore);
    final int itemCount = isEmployeeMode
        ? employeeState.employees.length
        : (isCustomerMode
              ? customerState.customers.length
              : filteredTasks.length);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: title,
        backgroundColor: AppColors.primary,
        textColor: AppColors.white,
        actions: [
          if (canAdd) ...[
            if (isEmployeeMode)
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) =>
                        const DynamicCreateEmployeeBottomSheet(),
                  );
                },
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.add_circle_outline,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      const AppSizeBox.w(4),
                      AppText(
                        'Create Employee',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              )
            else if (isCustomerMode)
              GestureDetector(
                onTap: () async {
                  final result = await context.push('/add-customer');
                  if (result != null) {
                    ref
                        .read(customerScreenProvider.notifier)
                        .fetchCustomers(refresh: true);
                  }
                },
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.add_circle_outline,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      const AppSizeBox.w(4),
                      AppText(
                        'Add Customer',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: () async {
                  final result = await context.push('/create-task');
                  if (result == true || result != null) {
                    ref
                        .read(taskScreenProvider.notifier)
                        .fetchTasks(refresh: true);
                  }
                },
                child: Container(
                  height: 40,
                  width: 130,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.add_circle_outline,
                        color: AppColors.primary,
                      ),
                      const AppSizeBox.w(4),
                      AppText(
                        'New Task',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            const AppSizeBox.w(8),
          ],
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.primary,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  if (isEmployeeMode) {
                    ref.read(employeeListProvider.notifier).setSearch(val);
                  } else if (isCustomerMode) {
                    ref.read(customerScreenProvider.notifier).setSearch(val);
                  } else {
                    ref.read(taskScreenProvider.notifier).setSearch(val);
                  }
                },
                decoration: InputDecoration(
                  hintText: isEmployeeMode
                      ? 'Search employees...'
                      : (isCustomerMode
                            ? 'Search customers...'
                            : 'Search tasks...'),
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            if (isEmployeeMode) {
                              ref
                                  .read(employeeListProvider.notifier)
                                  .setSearch('');
                            } else if (isCustomerMode) {
                              ref
                                  .read(customerScreenProvider.notifier)
                                  .setSearch('');
                            } else {
                              ref
                                  .read(taskScreenProvider.notifier)
                                  .setSearch('');
                            }
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          if (!isEmployeeMode && !isCustomerMode)
            _buildStatusFilterTabs(taskState.tasks),
          const AppSizeBox.h(16),
          Expanded(
            child: isLoading
                ? const AppCardSkeleton()
                : RefreshIndicator(
                    onRefresh: () async {
                      if (isEmployeeMode) {
                        await ref
                            .read(employeeListProvider.notifier)
                            .fetchEmployees(refresh: true);
                      } else if (isCustomerMode) {
                        await ref
                            .read(customerScreenProvider.notifier)
                            .fetchCustomers(refresh: true);
                      } else {
                        await ref
                            .read(taskScreenProvider.notifier)
                            .fetchTasks(refresh: true);
                      }
                    },
                    child: itemCount == 0
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.5,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        isEmployeeMode
                                            ? Icons.badge_outlined
                                            : (isCustomerMode
                                                  ? Icons.people_outline
                                                  : Icons.task_outlined),
                                        size: 64,
                                        color: Colors.grey.shade400,
                                      ),
                                      const AppSizeBox.h(16),
                                      AppText(
                                        isEmployeeMode
                                            ? 'No employees found'
                                            : (isCustomerMode
                                                  ? 'No customers found'
                                                  : 'No tasks found'),
                                        fontSize: 16,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: itemCount + 1,
                            itemBuilder: (context, index) {
                              if (index == itemCount) {
                                if (isLoadMore) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 16.0,
                                    ),
                                    child: AppCardSkeleton.single(),
                                  );
                                }
                                return const AppSizeBox.h(32);
                              }
                              if (isEmployeeMode) {
                                return _buildEmployeeCard(
                                  employeeState.employees[index],
                                );
                              } else if (isCustomerMode) {
                                return _buildCustomerCard(
                                  customerState.customers[index],
                                );
                              } else {
                                return _buildTaskCard(filteredTasks[index]);
                              }
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String text) {
    if (text.trim().isEmpty) return text;
    return text.replaceAllMapped(
      RegExp(r'\b[a-z]'),
      (match) => match.group(0)!.toUpperCase(),
    );
  }

  Widget _buildEmployeeCard(EmployeeModel employee) {
    final nameText = _capitalize(employee.name ?? 'No Name');
    final roleName = employee.roleName;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 8,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20.0, 16.0, 16.0, 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.primary.withValues(
                              alpha: 0.1,
                            ),
                            child: const Icon(
                              Icons.person,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const AppSizeBox.w(12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppText(
                                  nameText,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (employee.email != null &&
                                    employee.email!.isNotEmpty)
                                  AppText(
                                    employee.email!,
                                    color: AppColors.grey,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const AppSizeBox.w(8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: AppText(
                        'Role: $roleName',
                        color: AppColors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const AppSizeBox.h(12),
                const Divider(),
                const AppSizeBox.h(8),
                _buildDetailRow('Phone / Mobile', employee.mobile ?? 'NA'),
                _buildDetailRow('Department', employee.department ?? 'NA'),
                _buildDetailRow('Team', employee.team ?? 'NA'),
                _buildDetailRow('Designation', employee.designations ?? 'NA'),
                _buildDetailRow('Work Location', employee.workLocation ?? 'HQ'),
                _buildDetailRow(
                  'Emp Type / Shift',
                  '${employee.empType ?? 'Full-time'} / ${employee.workShift ?? 'Day'}',
                ),
                _buildDetailRow('Status', employee.status ?? 'active'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(CustomerModel customer) {
    final isExpanded = _expandedCustomerIds.contains(customer.id);
    final statusColor = _getStatusColor(customer.loanStatus);

    final nameText = _capitalize(
      customer.name.isNotEmpty ? customer.name : 'No Name',
    );
    final branchText = _capitalize(customer.branch);
    final centerText = _capitalize(customer.center);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 8,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedCustomerIds.remove(customer.id);
                  } else {
                    _expandedCustomerIds.add(customer.id);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 16.0, 16.0, 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(
                                nameText,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (customer.customerId.isNotEmpty)
                                AppText(
                                  'ID: ${customer.customerId}',
                                  color: AppColors.grey,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                            ],
                          ),
                        ),
                        const AppSizeBox.w(8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: AppText(
                            customer.loanStatus.isNotEmpty
                                ? customer.loanStatus
                                : 'Customer',
                            color: AppColors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const AppSizeBox.h(12),
                    _buildDetailRow(
                      'Phone',
                      customer.phone.isNotEmpty ? customer.phone : 'NA',
                    ),
                    _buildDetailRow(
                      'Email',
                      customer.email.isNotEmpty ? customer.email : 'NA',
                    ),
                    if (customer.ownerName.isNotEmpty)
                      _buildDetailRow('Owner', customer.ownerName),
                    if (customer.loanNo.isNotEmpty)
                      _buildDetailRow('Loan No', customer.loanNo),
                    if (customer.totalDueAmount.isNotEmpty)
                      _buildDetailRow(
                        'Total Due Amt',
                        '₹${customer.totalDueAmount}',
                      ),
                    if (customer.installmentAmount.isNotEmpty)
                      _buildDetailRow(
                        'Installment Amt',
                        '₹${customer.installmentAmount}',
                      ),
                    if (branchText.isNotEmpty || centerText.isNotEmpty)
                      _buildDetailRow(
                        'Branch / Center',
                        '$branchText / $centerText',
                      ),
                    if (isExpanded) ...[
                      const AppSizeBox.h(8),
                      _buildDetailRow(
                        'Loan Type',
                        customer.loanType.isNotEmpty ? customer.loanType : 'NA',
                      ),
                      _buildDetailRow(
                        'Loan Disb. Date',
                        _formatDate(customer.loanDisbDate),
                      ),
                      _buildDetailRow(
                        'Loan Amount',
                        customer.loanAmount.isNotEmpty
                            ? '₹${customer.loanAmount}'
                            : 'NA',
                      ),
                      _buildDetailRow(
                        'Cycle',
                        customer.cycle.isNotEmpty ? customer.cycle : 'NA',
                      ),
                      if (customer.location.isNotEmpty)
                        _buildDetailRow('Location', customer.location),
                      if (customer.spouseName.isNotEmpty)
                        _buildDetailRow('Spouse Name', customer.spouseName),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _safeString(dynamic val, {String fallback = ''}) {
    if (val == null) return fallback;
    if (val is String) return val.isEmpty ? fallback : val;
    if (val is Map) {
      if (val['name'] != null) return val['name'].toString();
      if (val['title'] != null) return val['title'].toString();
      if (val['label'] != null) return val['label'].toString();
    }
    return val.toString();
  }

  Widget _buildTaskCard(dynamic rawTask) {
    final Map<String, dynamic> task = rawTask is Map
        ? Map<String, dynamic>.from(rawTask)
        : {};

    // Title / Task ID / Description
    String title = _safeString(task['title']);
    if (title.isEmpty) {
      title = _safeString(task['task_id']);
    }
    if (title.isEmpty) {
      title = _safeString(task['description'], fallback: 'Untitled Task');
    }
    final description = _safeString(task['description'], fallback: 'NA');

    // Name
    String nameText = 'NA';
    if (task['name'] is Map) {
      nameText = _safeString((task['name'] as Map)['name'], fallback: 'NA');
    } else if (task['name'] != null && _safeString(task['name']).isNotEmpty) {
      nameText = _safeString(task['name'], fallback: 'NA');
    } else if (task['assigneeToEmployeeId'] is Map) {
      nameText = _safeString(
        (task['assigneeToEmployeeId'] as Map)['name'],
        fallback: 'NA',
      );
    } else if (task['assignedTo'] is Map) {
      nameText = _safeString(
        (task['assignedTo'] as Map)['name'],
        fallback: 'NA',
      );
    } else if (task['assignedTo'] != null &&
        _safeString(task['assignedTo']).isNotEmpty) {
      nameText = _safeString(task['assignedTo'], fallback: 'NA');
    } else if (task['employee'] is Map) {
      nameText = _safeString((task['employee'] as Map)['name'], fallback: 'NA');
    } else if (task['employee'] != null &&
        _safeString(task['employee']).isNotEmpty) {
      nameText = _safeString(task['employee'], fallback: 'NA');
    } else if (task['user'] is Map) {
      nameText = _safeString((task['user'] as Map)['name'], fallback: 'NA');
    } else if (task['user'] != null && _safeString(task['user']).isNotEmpty) {
      nameText = _safeString(task['user'], fallback: 'NA');
    }

    final priority = _safeString(task['priority'], fallback: 'Normal');
    final status = _safeString(task['status'], fallback: 'Pending');
    final slug = _safeString(task['slug'], fallback: title);

    // Type
    String type = 'General';
    if (task['taskType'] is Map) {
      type = _safeString(
        (task['taskType'] as Map)['name'],
        fallback: 'General',
      );
    } else if (task['taskType'] != null) {
      type = _safeString(task['taskType'], fallback: 'General');
    }

    // Follow Up
    String followUp = _safeString(task['time']);
    if (task['additionalFields'] is List &&
        (task['additionalFields'] as List).isNotEmpty) {
      final list = task['additionalFields'] as List;
      final notes = list
          .map((e) => e is Map ? "${e['name']}: ${e['value']}" : e.toString())
          .join(", ");
      if (followUp.isNotEmpty) {
        followUp += " ($notes)";
      } else {
        followUp = notes;
      }
    }
    if (followUp.isEmpty) followUp = 'NA';

    // Created By
    String createdBy = 'NA';
    if (task['createdBy'] is Map) {
      createdBy = _safeString(
        (task['createdBy'] as Map)['name'],
        fallback: 'NA',
      );
    } else if (task['createdBy'] != null) {
      createdBy = _safeString(task['createdBy'], fallback: 'NA');
    }

    // Start & Expire / End
    final rawStart = _safeString(task['startDateTime']).isNotEmpty
        ? task['startDateTime']
        : task['startDate'];
    final rawExpire = _safeString(task['endDateTime']).isNotEmpty
        ? task['endDateTime']
        : task['dueDate'];
    final startDateTime = _formatDate(_safeString(rawStart));
    final expireDateTime = _formatDate(_safeString(rawExpire));

    // Completed
    final rawCompleted = _safeString(task['completedAt']).isNotEmpty
        ? task['completedAt']
        : (status.toLowerCase() == 'completed' ? task['updatedAt'] : null);
    final completedAt = _formatDate(_safeString(rawCompleted));

    // Address / Customer
    String address = 'NA';
    if (task['customerId'] is Map) {
      final cust = task['customerId'] as Map;
      final cName = _safeString(cust['name']);
      final cPhone = _safeString(cust['phone']);
      final cAddr = _safeString(cust['address']);
      address = cName;
      if (cPhone.isNotEmpty) address += ' ($cPhone)';
      if (cAddr.isNotEmpty) address += ' - $cAddr';
    } else if (task['address'] != null) {
      address = _safeString(task['address'], fallback: 'NA');
    }

    // Total Time Taken
    final totalTimeTaken = _safeString(task['totalTimeTaken'], fallback: 'NA');

    // Repeat
    String repeatText = 'No';
    if (task['repeat'] == true) {
      final freq = _safeString(task['frequency']);
      final interval = task['interval']?.toString() ?? '';
      repeatText = 'Yes ($freq every $interval)';
    }

    // Create Time
    final createTime = _formatDate(_safeString(task['createdAt']));

    final isExpanded = _expandedTaskSlugs.contains(slug);
    final statusColor = _getStatusColor(status);

    return Container(
      margin: EdgeInsets.only(top: 8),
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
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedTaskSlugs.remove(slug);
                        } else {
                          _expandedTaskSlugs.add(slug);
                        }
                      });
                      context.push('/task-details', extra: rawTask);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: AppText(
                            title,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.primary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const AppSizeBox.w(6),
                        const BlinkingTouchIcon(
                          color: Color(0xFF00BFA5),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                const AppSizeBox.w(8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: AppText(
                        status,
                        color: AppColors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const AppSizeBox.h(4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: AppText(
                        'Priority: ${_capitalize(priority)}',
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Body
          Stack(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedTaskSlugs.remove(slug);
                      } else {
                        _expandedTaskSlugs.add(slug);
                      }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20.0, 16.0, 16.0, 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Name', nameText),
                        _buildDetailRow('Description', description),
                        _buildDetailRow('Type', type),
                        _buildDetailRow('Follow Up', followUp),
                        _buildDetailRow('Created by', createdBy),
                        if (isExpanded) ...[
                          const AppSizeBox.h(4),
                          _buildDetailRow('Start', startDateTime),
                          _buildDetailRow('Expire', expireDateTime),
                          _buildDetailRow('Completed', completedAt),
                          _buildDetailRow('Address', address),
                          _buildDetailRow('Total Time Taken', totalTimeTaken),
                          _buildDetailRow('Repeat', repeatText),
                          _buildDetailRow('Create time', createTime),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DynamicCreateEmployeeBottomSheet extends ConsumerStatefulWidget {
  const DynamicCreateEmployeeBottomSheet({super.key});

  @override
  ConsumerState<DynamicCreateEmployeeBottomSheet> createState() =>
      _DynamicCreateEmployeeBottomSheetState();
}

class _DynamicCreateEmployeeBottomSheetState
    extends ConsumerState<DynamicCreateEmployeeBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _formData = {};
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final fieldsAsync = ref.watch(employeeFormFieldsProvider);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: fieldsAsync.when(
        data: (fields) => _buildFormContent(fields),
        loading: () => SizedBox(
          height: 250,
          child:
          
           Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: List.generate(
                  3,
                  (index) => Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ),
       
       
        ),
        error: (err, stack) => SizedBox(
          height: 200,
          child: Center(child: Text('Failed to load form fields: $err')),
        ),
      ),
    );
  }

  Widget _buildFormContent(List<EmployeeFormField> fields) {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const AppSizeBox.h(16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppText(
                  'Create Employee',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const AppSizeBox.h(12),
            ...fields.map((field) => _buildFormField(field)),
            const AppSizeBox.h(20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isSubmitting
                    ? null
                    : () async {
                        if (_formKey.currentState!.validate()) {
                          _formKey.currentState!.save();
                          setState(() => _isSubmitting = true);

                          final success = await ref
                              .read(employeeListProvider.notifier)
                              .addEmployee(_formData);

                          if (mounted) {
                            setState(() => _isSubmitting = false);
                            Navigator.pop(context);
                            if (success == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Employee Created Successfully!',
                                  ),
                                ),
                              );
                            }
                          }
                        }
                      },
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : AppText(
                        'Create Employee',
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField(EmployeeFormField field) {
    if (field.type == 'select') {
      final initialVal = field.options.isNotEmpty
          ? field.options.first.value
          : null;
      if (!_formData.containsKey(field.name) && initialVal != null) {
        _formData[field.name] = initialVal;
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: DropdownButtonFormField<String>(
          initialValue: _formData[field.name] as String?,
          decoration: InputDecoration(
            labelText: '${field.label}${field.required ? ' *' : ''}',
            border: const OutlineInputBorder(),
          ),
          items: field.options.map((opt) {
            return DropdownMenuItem<String>(
              value: opt.value,
              child: Text(opt.label),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              _formData[field.name] = val;
            });
          },
          validator: (val) {
            if (field.required && (val == null || val.isEmpty)) {
              return 'Please select ${field.label}';
            }
            return null;
          },
        ),
      );
    }

    TextInputType keyboardType = TextInputType.text;
    if (field.type == 'email') {
      keyboardType = TextInputType.emailAddress;
    } else if (field.type == 'number' || field.type == 'tel') {
      keyboardType = TextInputType.phone;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: '${field.label}${field.required ? ' *' : ''}',
          hintText: field.placeholder.isNotEmpty ? field.placeholder : null,
          border: const OutlineInputBorder(),
        ),
        onSaved: (val) {
          _formData[field.name] = val?.trim();
        },
        validator: (val) {
          if (field.required && (val == null || val.trim().isEmpty)) {
            return 'Please enter ${field.label}';
          }
          return null;
        },
      ),
    );
  }
}

class BlinkingTouchIcon extends ConsumerStatefulWidget {
  final Color color;
  final double size;

  const BlinkingTouchIcon({
    super.key,
    this.color = const Color(0xFF00BFA5),
    this.size = 20,
  });

  @override
  ConsumerState<BlinkingTouchIcon> createState() => _BlinkingTouchIconState();
}

class _BlinkingTouchIconState extends ConsumerState<BlinkingTouchIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);
    _opacityAnimation = Tween<double>(
      begin: 0.25,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: Icon(
        Icons.touch_app_outlined,
        size: widget.size,
        color: widget.color,
      ),
    );
  }
}
