import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/custom_app_bar.dart';
import '../provider/task_provider.dart';

class TaskDetailsScreen extends ConsumerStatefulWidget {
  final dynamic taskExtra;
  const TaskDetailsScreen({super.key, this.taskExtra});

  @override
  ConsumerState<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends ConsumerState<TaskDetailsScreen> {
  final TextEditingController _npaCollectionController =
      TextEditingController();
  bool _isCustomerDetailsExpanded = false;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final slug = _getSlug();
      ref.read(taskDetailsProvider.notifier).fetchTaskDetails(slug);
    });
  }

  @override
  void dispose() {
    _npaCollectionController.dispose();
    super.dispose();
  }

  String _getSlug() {
    if (widget.taskExtra is String && (widget.taskExtra as String).isNotEmpty) {
      return widget.taskExtra as String;
    }
    if (widget.taskExtra is Map && widget.taskExtra['slug'] != null) {
      return widget.taskExtra['slug'].toString();
    }
    return 'dsdsadsadsadsdsad-up5el';
  }

  String _safeStr(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final str = value.toString().trim();
    return str.isEmpty ? fallback : str;
  }

  String _formatDate(dynamic raw, String fallback) {
    if (raw == null) return fallback;
    final str = raw.toString();
    if (str.isEmpty) return fallback;
    try {
      final dt = DateTime.parse(str).toLocal();
      final year = dt.year.toString().padLeft(4, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final day = dt.day.toString().padLeft(2, '0');
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$year-$month-$day $hour:$minute';
    } catch (_) {
      return str;
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskDetailsState = ref.watch(taskDetailsProvider);
    final taskData = taskDetailsState.taskData ?? <String, dynamic>{};

    final customer = taskData['customerId'] is Map
        ? Map<String, dynamic>.from(taskData['customerId'])
        : <String, dynamic>{};
    final taskType = taskData['taskType'] is Map
        ? Map<String, dynamic>.from(taskData['taskType'])
        : <String, dynamic>{};
    final createdBy = taskData['createdBy'] is Map
        ? Map<String, dynamic>.from(taskData['createdBy'])
        : <String, dynamic>{};
    final assignee = taskData['assigneeToEmployeeId'] is Map
        ? Map<String, dynamic>.from(taskData['assigneeToEmployeeId'])
        : <String, dynamic>{};

    final title = _safeStr(taskData['description'], fallback: 'xsadasdsd');
    final taskTypeName = _safeStr(taskType['name'], fallback: 'collection2');

    String customerDisplayName = 'GUDIYA SHARMA - 09...';
    if (customer['name'] != null && customer['name'].toString().isNotEmpty) {
      final custId = customer['customer_id'] ?? customer['phone'] ?? '';
      customerDisplayName = '${customer['name']} - $custId';
    }

    final rawStatus = _safeStr(taskData['status'], fallback: 'Pending');
    final status = rawStatus.isNotEmpty
        ? '${rawStatus[0].toUpperCase()}${rawStatus.substring(1)}'
        : 'Pending';

    if (_npaCollectionController.text.isEmpty &&
        taskData['payment_type'] != null) {
      _npaCollectionController.text = taskData['payment_type'].toString();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: CustomAppBar(
        title: "Task Details",
        backgroundColor: AppColors.primary,
        textColor: AppColors.white,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          if (taskDetailsState.isLoading)
            const LinearProgressIndicator(
              color: AppColors.primary,
              minHeight: 3,
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Heading Section with Blue Accent Indicator & Start Task Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 22,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0066D4),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Task Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2B2B2B),
                            ),
                          ),
                        ],
                      ),
                      if (status.toLowerCase() == 'pending')
                        ElevatedButton.icon(
                          onPressed: () {
                            context.push(
                              '/complete-task',
                              extra: widget.taskExtra,
                            );
                          },
                          icon: const Icon(
                            Icons.add,
                            size: 18,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Start Task',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0066D4),
                            foregroundColor: Colors.white,
                            elevation: 1,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDetailRow('Title*', title),
                                _buildDetailRow('Task Type*', taskTypeName),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDetailRow(
                                        'Customer',
                                        customerDisplayName,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0066D4),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.assignment_ind,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: status.toLowerCase() == 'completed'
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFFE53935),
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(12),
                                ),
                              ),
                              child: Text(
                                status,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isCustomerDetailsExpanded =
                            !_isCustomerDetailsExpanded;
                      });
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 22,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0066D4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Customer Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2B2B2B),
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          _isCustomerDetailsExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: const Color(0xFF0066D4),
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _isCustomerDetailsExpanded =
                                !_isCustomerDetailsExpanded;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDetailRow(
                                'Mobile',
                                _safeStr(
                                  customer['phone'],
                                  fallback: '9876543210',
                                ),
                              ),
                              _buildDetailRow(
                                'State Name',
                                _safeStr(
                                  customer['state'],
                                  fallback: 'Uttar Pradesh',
                                ),
                              ),
                              _buildDetailRow(
                                'Sub-State Name',
                                _safeStr(
                                  customer['sub_state'],
                                  fallback: 'West UP',
                                ),
                              ),
                              if (_isCustomerDetailsExpanded) ...[
                                _buildDetailRow(
                                  'Branch Code',
                                  _safeStr(
                                    customer['branch_code'],
                                    fallback: 'BR001',
                                  ),
                                ),
                                _buildDetailRow(
                                  'Branch',
                                  _safeStr(
                                    customer['branch'],
                                    fallback: 'Main Branch',
                                  ),
                                ),
                                _buildDetailRow(
                                  'Center Name',
                                  _safeStr(
                                    customer['center'],
                                    fallback: 'Center A',
                                  ),
                                ),
                                _buildDetailRow(
                                  'Center Code',
                                  _safeStr(
                                    customer['center_code'],
                                    fallback: 'C001',
                                  ),
                                ),
                                _buildDetailRow(
                                  'Loan Type',
                                  _safeStr(
                                    customer['loanType'],
                                    fallback: 'Personal Loan',
                                  ),
                                ),
                                _buildDetailRow(
                                  'Loan NO.',
                                  _safeStr(
                                    customer['loanNo'],
                                    fallback: 'LN12345678',
                                  ),
                                ),
                                _buildDetailRow(
                                  'Old Loan No. With Loan Series',
                                  _safeStr(
                                    customer['oldLoanNo'],
                                    fallback: 'OLD-LN-001',
                                  ),
                                ),
                                _buildDetailRow(
                                  'Cycle',
                                  _safeStr(customer['cycle'], fallback: '1'),
                                ),
                                _buildDetailRow(
                                  'LoanAmount',
                                  customer['loanAmount'] != null
                                      ? '₹ ${customer['loanAmount']}'
                                      : '₹ 50,000',
                                ),
                                _buildDetailRow(
                                  'O/S Int',
                                  customer['os_interest'] != null
                                      ? '₹ ${customer['os_interest']}'
                                      : '₹ 1,200',
                                ),
                                _buildDetailRow(
                                  'O/S Prin',
                                  customer['os_principal'] != null
                                      ? '₹ ${customer['os_principal']}'
                                      : '₹ 35,000',
                                ),
                                _buildDetailRow(
                                  'PAR',
                                  _safeStr(customer['par'], fallback: '0'),
                                ),
                                _buildDetailRow(
                                  'ODPrin',
                                  customer['od_principal'] != null
                                      ? '₹ ${customer['od_principal']}'
                                      : '₹ 0',
                                ),
                                _buildDetailRow(
                                  'ODInt',
                                  customer['od_interest'] != null
                                      ? '₹ ${customer['od_interest']}'
                                      : '₹ 0',
                                ),
                                _buildDetailRow(
                                  'TotalDueAmt',
                                  customer['totalDueAmount'] != null
                                      ? '₹ ${customer['totalDueAmount']}'
                                      : '₹ 2,500',
                                ),
                                _buildDetailRow(
                                  'TotalPrinColl',
                                  customer['total_principal_collectible'] !=
                                          null
                                      ? '₹ ${customer['total_principal_collectible']}'
                                      : '₹ 15,000',
                                ),
                                _buildDetailRow(
                                  'TotalIntColl',
                                  customer['total_interest_collectible'] != null
                                      ? '₹ ${customer['total_interest_collectible']}'
                                      : '₹ 3,000',
                                ),
                                _buildDetailRow(
                                  'IrrRate',
                                  customer['irrRate'] != null
                                      ? '${customer['irrRate']}%'
                                      : '18%',
                                ),
                                _buildDetailRow(
                                  'NoOfInstallment',
                                  _safeStr(
                                    customer['noOfInstallment'],
                                    fallback: '24',
                                  ),
                                ),
                                _buildDetailRow(
                                  'DPD',
                                  _safeStr(customer['dpd'], fallback: '0'),
                                ),
                                _buildDetailRow(
                                  'PaidInstNo',
                                  _safeStr(
                                    customer['paidInstNo'],
                                    fallback: '8',
                                  ),
                                ),
                                _buildDetailRow(
                                  'LoanStatus',
                                  _safeStr(
                                    customer['loanStatus'],
                                    fallback: 'Active',
                                  ),
                                ),
                                _buildDetailRow(
                                  'SpouseName',
                                  _safeStr(
                                    customer['spouseName'],
                                    fallback: 'Ramesh Sharma',
                                  ),
                                ),
                                _buildDetailRow(
                                  'InstallmentAmount',
                                  customer['installmentAmount'] != null
                                      ? '₹ ${customer['installmentAmount']}'
                                      : '₹ 2,500',
                                ),
                                _buildDetailRow(
                                  'Pincode',
                                  _safeStr(
                                    customer['pincode'],
                                    fallback: '201301',
                                  ),
                                ),
                                _buildDetailRow(
                                  'Address',
                                  _safeStr(
                                    customer['location'],
                                    fallback: 'H.No 123, Sector 15, Noida',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (status.toLowerCase() == 'completed') ...[
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: _buildTaskTimeline(),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 22,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0066D4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'NPA collection',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2B2B2B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (status.toLowerCase() == 'completed') ...[
                    _buildNpaCompletedCard(taskData: taskData),
                  ] else ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Payment type(Collection ... ',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF333333),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.grey.shade700,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: TextField(
                            controller: _npaCollectionController,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              prefixIcon: Padding(
                                padding: const EdgeInsets.only(
                                  left: 12,
                                  right: 6,
                                ),
                                child: Text(
                                  '₹',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 0,
                                minHeight: 0,
                              ),
                              hintText: 'Enter a default collecti...',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  _buildTaskMetaDataCard(
                    priority: _safeStr(
                      taskData['priority'],
                      fallback: 'Medium',
                    ),
                    creatorName: _safeStr(
                      createdBy['name'],
                      fallback: 'MINA KUMARI',
                    ),
                    assigneeName: _safeStr(
                      assignee['name'],
                      fallback: 'MINA KUMARI',
                    ),
                    startDate: _formatDate(
                      taskData['startDateTime'],
                      '2026-08-31 14:56',
                    ),
                    endDate: _formatDate(
                      taskData['endDateTime'],
                      '2026-09-01 14:56',
                    ),
                    createdBy: createdBy,
                    assignee: assignee,
                  ),
                  const SizedBox(height: 20),
                  _buildCustomerFollowUpTabsCard(customer: customer),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF666666),
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const Text(
            ': ',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF222222),
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF111111),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTimeline() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0066D4), width: 2),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Color(0xFF0066D4),
                  size: 18,
                ),
              ),
              Container(width: 2, height: 48, color: const Color(0xFF0066D4)),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0066D4), width: 2),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Color(0xFF0066D4),
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Started',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF222222),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'MKD School, Dhampur, Bijnor, Uttar Pradesh, 246761, India',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF0066D4),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '2026-07-28 18:24',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF0066D4),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Completed',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF222222),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'MKD School, Dhampur, Bijnor, Uttar Pradesh, 246761, India',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF0066D4),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: const [
                    Text(
                      '2026-07-28 18:28',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF0066D4),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 24),
                    Text(
                      '0 Km',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF0066D4),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNpaCompletedCard({Map<String, dynamic> taskData = const {}}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(
                "Client’s House Image.",
                _safeStr(taskData['houseImage'], fallback: "house_photo.jpg"),
              ),
              _buildDetailRow(
                "Client Relation 1*",
                _safeStr(taskData['relation'], fallback: "Father"),
              ),
              _buildDetailRow("Client Relation 2", "Mother"),
              _buildDetailRow(
                "Client Mobile No. 1*",
                _safeStr(taskData['clientPhone'], fallback: "9876543210"),
              ),
              _buildDetailRow("Client Mobile No. 2", "9123456789"),
              const SizedBox(height: 10),
              const Divider(color: Color(0xFFEEEEEE), height: 1),
              const SizedBox(height: 12),
              const Text(
                'Payment type*',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0066D4),
                ),
              ),
              const SizedBox(height: 6),
              _buildDetailRow(
                "Collection Amount",
                taskData['paymentAmount'] != null
                    ? "₹ ${taskData['paymentAmount']}"
                    : "₹ 5,000",
              ),
              _buildDetailRow(
                "Collect Payment*",
                _safeStr(taskData['collectPayment'], fallback: "Full"),
              ),
              _buildDetailRow(
                "Reason*",
                _safeStr(taskData['reason'], fallback: "Regular Collection"),
              ),
              _buildDetailRow(
                "Client Segment*",
                _safeStr(taskData['clientSegment'], fallback: "Standard"),
              ),
              _buildDetailRow(
                "PTP Date*",
                _safeStr(taskData['ptpdate'], fallback: "2026-07-28"),
              ),
              _buildDetailRow(
                "Geo*",
                _safeStr(
                  taskData['location'],
                  fallback: "28.6139° N, 77.2090° E",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskMetaDataCard({
    required String priority,
    required String creatorName,
    required String assigneeName,
    required String startDate,
    required String endDate,
    Map<String, dynamic>? createdBy,
    Map<String, dynamic>? assignee,
  }) {
    final formattedPriority = priority.isNotEmpty
        ? '${priority[0].toUpperCase()}${priority.substring(1)}'
        : 'Medium';
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Priority Row
              Row(
                children: [
                  const Text(
                    'Priority - ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2B2B2B),
                    ),
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: formattedPriority.toLowerCase() == 'high'
                          ? Colors.red
                          : (formattedPriority.toLowerCase() == 'low'
                                ? Colors.grey
                                : const Color(0xFF4CAF50)),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    formattedPriority,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2B2B2B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () =>
                    context.push('/employee-live-tracking', extra: createdBy),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Creator - ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2B2B2B),
                      ),
                    ),
                    Text(
                      creatorName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0066D4),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.open_in_new,
                      size: 16,
                      color: Color(0xFF0066D4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () =>
                    context.push('/employee-live-tracking', extra: assignee),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Assign to - ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2B2B2B),
                      ),
                    ),
                    Text(
                      assigneeName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0066D4),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.open_in_new,
                      size: 16,
                      color: Color(0xFF0066D4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Divider(color: Colors.grey.shade200, height: 1),
              const SizedBox(height: 14),
              const Text(
                'Timeline',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2B2B2B),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF0066D4),
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '1',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0066D4),
                          ),
                        ),
                      ),
                      Container(
                        width: 2,
                        height: 34,
                        color: const Color(0xFF0066D4),
                      ),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF0066D4),
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '2',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0066D4),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SizedBox(height: 4),
                      Text(
                        'Started',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2B2B2B),
                        ),
                      ),
                      SizedBox(height: 40),
                      Text(
                        'Completed',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2B2B2B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              const Text(
                'Date Range',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2B2B2B),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const SizedBox(
                    width: 60,
                    child: Text(
                      'Start',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF444444),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F5F7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        startDate,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF333333),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const SizedBox(
                    width: 60,
                    child: Text(
                      'End',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF444444),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F5F7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        endDate,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF333333),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerFollowUpTabsCard({
    required Map<String, dynamic> customer,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Header
            const Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 12,
              ),
              child: Text(
                'Task',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2B2B2B),
                ),
              ),
            ),

            // Tab Bar Header Container
            Container(
              color: const Color(0xFFF4F6F9),
              child: Row(
                children: [
                  // Customer Tab
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedTabIndex = 0;
                        });
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Text(
                              'Customer',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _selectedTabIndex == 0
                                    ? const Color(0xFF0066D4)
                                    : const Color(0xFF4A5568),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Container(
                            height: 3,
                            color: _selectedTabIndex == 0
                                ? const Color(0xFF0066D4)
                                : Colors.transparent,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Follow Up Tab
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedTabIndex = 1;
                        });
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12.0),
                            child: Text(
                              'Follow Up',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _selectedTabIndex == 1
                                    ? const Color(0xFF0066D4)
                                    : const Color(0xFF4A5568),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Container(
                            height: 3,
                            color: _selectedTabIndex == 1
                                ? const Color(0xFF0066D4)
                                : Colors.transparent,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Tab Content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _selectedTabIndex == 0
                  ? _buildCustomerTabContent(customer)
                  : _buildFollowUpTabContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerTabContent(Map<String, dynamic> customer) {
    final locationHeader = _safeStr(
      customer['district'] ?? customer['location'],
      fallback: 'MUZAFFARPUR',
    ).toUpperCase();
    final totalIntColl = _safeStr(
      customer['total_interest_collectible'],
      fallback: '0',
    );
    final loanAmount = _safeStr(customer['loanAmount'], fallback: '7500');
    final preClosureAmt = _safeStr(
      customer['preClosureAmt'] ?? customer['totalDueAmount'],
      fallback: '9679',
    );
    final centerCode = _safeStr(customer['center_code'], fallback: '35002235');
    final par = customer['par'] != null ? 'PAR ${customer['par']}' : 'PAR 366';
    final noOfInstallment = _safeStr(
      customer['noOfInstallment'],
      fallback: '19',
    );
    final osPrin = _safeStr(customer['os_principal'], fallback: '7500');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          locationHeader,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
            color: Color(0xFF555555),
          ),
        ),
        const SizedBox(height: 14),
        _buildStackedKeyValue('TotalIntColl', totalIntColl),
        _buildStackedKeyValue('LoanAmount', loanAmount),
        _buildStackedKeyValue('PreClosure Amt', preClosureAmt),
        _buildStackedKeyValue('Center Code', centerCode),
        _buildStackedKeyValue('PAR', par),
        _buildStackedKeyValue('NoOfInstallment', noOfInstallment),
        _buildStackedKeyValue('O/S Prin', osPrin),
      ],
    );
  }

  Widget _buildFollowUpTabContent() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      width: double.infinity,
      child: Column(
        children: [
          Icon(Icons.history_outlined, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            'No Follow Up Details Available',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStackedKeyValue(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF222222),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.normal,
              color: Color(0xFF555555),
            ),
          ),
        ],
      ),
    );
  }
}
