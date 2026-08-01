import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_text.dart';
import '../widget/app_drawer.dart';
import '../../auth/provider/auth_provider.dart';
import '../../attendance/provider/punch_in_provider.dart';
import '../../../core/providers/permission_provider.dart';

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
                        // Container(
                        //   width: 44,
                        //   height: 44,
                        //   decoration: BoxDecoration(
                        //     shape: BoxShape.circle,
                        //     color: Colors.white.withValues(alpha: 0.2),
                        //   ),
                        //   child: Icon(
                        //     (punchState.isPunchedIn == true)
                        //         ? Icons.fingerprint_rounded
                        //         : Icons.fingerprint,
                        //     color: Colors.white,
                        //     size: 26,
                        //   ),
                        // ),
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
                        // Right Arrow Icon Circle ( -> )
                        // Container(
                        //   width: 36,
                        //   height: 36,
                        //   decoration: BoxDecoration(
                        //     shape: BoxShape.circle,
                        //     color: Colors.white.withValues(alpha: 0.2),
                        //     border: Border.all(color: Colors.white, width: 1.5),
                        //   ),
                        //   // child: const Icon(
                        //   //   Icons.arrow_forward,
                        //   //   color: Colors.white,
                        //   //   size: 18,
                        //   // ),
                        // ),
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
