import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_text.dart';
import '../widget/app_drawer.dart';
import '../../auth/provider/auth_provider.dart';
import '../../attendance/provider/punch_in_provider.dart';
import '../../../core/providers/permission_provider.dart';
import '../provider/home_provider.dart';
import '../model/home_dashboard_model.dart';
import '../../task/provider/task_provider.dart';
import './main_screen.dart';
import '../provider/employee_tasks_provider.dart';

class HomeContent extends ConsumerWidget {
  const HomeContent({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8), // Light bluish background
      drawer: const AppDrawer(),
      onDrawerChanged: (isOpen) {
        if (isOpen) {
          ref.invalidate(permissionProvider);
        }
      },
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await Future.wait([
                    ref.read(homeProvider.notifier).getHomeData(),
                    ref
                        .read(employeeTasksProvider.notifier)
                        .fetchEmployeeTasks(),
                  ]);
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildHeaderAndPunchSection(context, ref),
                    const SizedBox(height: 16),
                    _buildTaskCard('Amount Collection - Today', context, ref),
                    const SizedBox(height: 16),
                    _buildTaskCard('Task - Today', context, ref),
                  ],
                ),
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
              ? 'Punched In at ${_formatDateTime(punchState.punchInTime!)}'
              : 'Punched In')
        : (punchState.punchOutTime != null
              ? 'Punched Out at ${_formatDateTime(punchState.punchOutTime!)}'
              : 'Not Punched In Today');
    const double notchWidth = 56.0;
    const double topHeight = 65.0;
    return SizedBox(
      width: double.infinity,
      child: Stack(
        children: [
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
                InkWell(
                  onTap: punchState.isLoading
                      ? null
                      : () async {
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
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText(
                                punchState.isLoading
                                    ? 'Please wait...'
                                    : (punchState.isPunchedIn == true)
                                    ? 'Punch out'
                                    : 'Punch in',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 2),
                              AppText(
                                punchState.isLoading
                                    ? 'Processing...'
                                    : punchTimeText,
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          child: punchState.isLoading
                              ? const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Icon(
                                  (punchState.isPunchedIn == true)
                                      ? Icons.fingerprint_rounded
                                      : Icons.fingerprint,
                                  color: Colors.white,
                                  size: 26,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
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

  static String _formatDateTime(DateTime dateTime) {
    final timeStr = _formatTime(dateTime);
    final day = dateTime.day.toString().padLeft(2, '0');
    String monthStr;
    switch (dateTime.month) {
      case 1:
        monthStr = 'Jan';
        break;
      case 2:
        monthStr = 'Feb';
        break;
      case 3:
        monthStr = 'Mar';
        break;
      case 4:
        monthStr = 'Apr';
        break;
      case 5:
        monthStr = 'May';
        break;
      case 6:
        monthStr = 'Jun';
        break;
      case 7:
        monthStr = 'Jul';
        break;
      case 8:
        monthStr = 'Aug';
        break;
      case 9:
        monthStr = 'Sep';
        break;
      case 10:
        monthStr = 'Oct';
        break;
      case 11:
        monthStr = 'Nov';
        break;
      case 12:
        monthStr = 'Dec';
        break;
      default:
        monthStr = '';
    }

    final year = dateTime.year.toString();
    return '$timeStr, $day $monthStr $year';
  }

  static String _formatAmountValue(num amount) {
    if (amount == 0) return '₹ 0';
    final isInt = amount is int || amount == amount.roundToDouble();
    final formatted = isInt
        ? amount.toInt().toString()
        : amount.toStringAsFixed(2);
    return '₹ $formatted';
  }

  Widget _buildTaskCard(String title, BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeProvider);
    final taskMetrics = homeState.data?.taskMetrics;
    final amountMetrics = homeState.data?.amountMetrics;
    if (homeState.isLoading && taskMetrics == null && amountMetrics == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (homeState.error != null &&
        taskMetrics == null &&
        amountMetrics == null) {
      return Center(child: Text(homeState.error ?? 'Error loading data'));
    }
    final total = taskMetrics?.total ?? 0;
    final completed = taskMetrics?.completed ?? 0;
    final inProgress = taskMetrics?.inProgress ?? 0;
    final pending = taskMetrics?.pending ?? 0;
    final completedPercent = taskMetrics?.completedPercentage ?? 0;
    final inProgressPercent = taskMetrics?.inProgressPercentage ?? 0;
    final pendingPercent = taskMetrics?.pendingPercentage ?? 0;

    final isAmountCard = title.toLowerCase().contains('amount collection');

    final labelAll = isAmountCard ? 'Total Amount' : 'All Task';
    final labelCompleted = isAmountCard ? 'Collect Amount' : 'Completed';
    final labelInProgress = 'In Progress';
    final labelPending = isAmountCard ? 'Pending Amount' : 'Pending';

    final totalAmt = amountMetrics?.total ?? taskMetrics?.totalAmount ?? 0;
    final completedAmt =
        amountMetrics?.completed ?? taskMetrics?.completedAmount ?? 0;
    final inProgressAmt =
        amountMetrics?.inProgress ?? taskMetrics?.inProgressAmount ?? 0;
    final pendingAmt =
        amountMetrics?.pending ?? taskMetrics?.pendingAmount ?? 0;

    final subAll = isAmountCard
        ? _formatAmountValue(totalAmt)
        : '$total out of $total';
    final subCompleted = isAmountCard
        ? _formatAmountValue(completedAmt)
        : '$completed out of $total';
    final subInProgress = isAmountCard
        ? _formatAmountValue(inProgressAmt)
        : '$inProgress out of $total';
    final subPending = isAmountCard
        ? _formatAmountValue(pendingAmt)
        : '$pending out of $total';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: AppText(title, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildTaskStatBox(
                    labelAll,
                    subAll,
                    100,
                    isAmountCard
                        ? null
                        : () {
                            ref
                                .read(taskFilterProvider.notifier)
                                .setFilter('All');
                            ref.read(mainScreenTabProvider.notifier).setTab(1);
                          },
                    showPercentage: !isAmountCard,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTaskStatBox(
                    labelCompleted,
                    subCompleted,
                    completedPercent,
                    isAmountCard
                        ? null
                        : () {
                            ref
                                .read(taskFilterProvider.notifier)
                                .setFilter('Completed');
                            ref.read(mainScreenTabProvider.notifier).setTab(1);
                          },
                    showPercentage: !isAmountCard,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildTaskStatBox(
                    labelInProgress,
                    subInProgress,
                    inProgressPercent,
                    isAmountCard
                        ? null
                        : () {
                            ref
                                .read(taskFilterProvider.notifier)
                                .setFilter('In Progress');
                            ref.read(mainScreenTabProvider.notifier).setTab(1);
                          },
                    showPercentage: !isAmountCard,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTaskStatBox(
                    labelPending,
                    subPending,
                    pendingPercent,
                    isAmountCard
                        ? null
                        : () {
                            ref
                                .read(taskFilterProvider.notifier)
                                .setFilter('Pending');
                            ref.read(mainScreenTabProvider.notifier).setTab(1);
                          },
                    showPercentage: !isAmountCard,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskStatBox(
    String title,
    String subtitle,
    int percentage,
    VoidCallback? onTap, {
    bool showPercentage = true,
  }) {
    final hasOutOf = subtitle.contains(' out of ');
    final cardContent = Container(
      padding: const EdgeInsets.all(12),
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
              const SizedBox(height: 4),
              if (hasOutOf)
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
                )
              else
                AppText(
                  subtitle,
                  fontSize: 13,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
            ],
          ),
          if (showPercentage)
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                    strokeWidth: 3,
                  ),
                ),
                AppText(
                  '$percentage%',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ],
            ),
        ],
      ),
    );

    if (onTap == null) {
      return cardContent;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: cardContent,
    );
  }

  String _safeStr(dynamic val, {String fallback = ''}) {
    if (val == null) return fallback;
    if (val is String) return val.isEmpty ? fallback : val;
    if (val is Map) {
      if (val['name'] != null) return val['name'].toString();
      if (val['title'] != null) return val['title'].toString();
    }
    return val.toString();
  }

  Color _getTaskStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'done':
      case 'closed':
        return const Color(0xFF00BFA5);
      case 'pending':
      case 'open':
        return const Color(0xFFFF9800);
      case 'in progress':
      case 'inprogress':
        return const Color(0xFF2196F3);
      default:
        return const Color(0xFF0D47A1);
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red.shade600;
      case 'medium':
        return Colors.orange.shade700;
      case 'low':
        return Colors.green.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  String _formatTaskDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'NA';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final months = [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month]} - $hour:$minute $amPm';
    } catch (_) {
      return dateStr;
    }
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
